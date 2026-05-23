class_name Board
extends Control
## Доска маджонга. Многослойная раскладка через LevelGenerator, абсолютное
## позиционирование плиток в локальных координатах. Внизу — 3 слота выбора.
##
## Контракт со слотами / клик-логикой:
## 1) Клик по ON_BOARD плитке: если is_tile_free → press_bounce + перемещение
##    в первый свободный слот (state = IN_SLOT). Иначе — shake.
## 2) Клик по IN_SLOT плитке: возврат домой (отмена выбора).
## 3) Когда все 3 слота заполнены — авто-проверка тройки:
##    match → play_clear на 3 плитках, прогресс;
##    no match → play_return_home, ничего не теряем.
## 4) После любого изменения on-board состава — пересчёт blocked-visual у всех плиток.
##
## Сигналы наверх:
##   tiles_cleared(count)
##   triple_failed
##   progress_changed(value, max_value)
##   level_completed
##   deadlock

signal tiles_cleared(count: int)
signal triple_failed
signal progress_changed(value: int, max_value: int)
signal level_completed
signal deadlock

const TileScene: PackedScene = preload("res://scenes/tile.tscn")

# Геометрия (см. docs/STYLE.md §4).
# Half-step grid: плитка занимает 2 half-cell × 2 half-cell. Верхние слои
# смещены на 1 half-cell относительно нижних — классическая пирамида маджонга.
const TILE_SIZE: Vector2 = Vector2(160, 200)
const HALF_CELL: Vector2 = Vector2(84, 104)  # такая, чтобы 2 half-cells = tile + 8 px margin
const LAYER_LIFT: Vector2 = Vector2(-6, -10)
const SLOT_COUNT: int = 3
const DUPLICATE_CLICK_MS: int = 140
# Отступ от краёв PlayArea, чтобы пирамида не упиралась в стенки.
const BOARD_MARGIN: float = 24.0
# Минимальный масштаб плиток — ниже становится нечитаемо.
const MIN_TILE_SCALE: float = 0.45

@export var current_level: int = 1

@onready var _play_area: Control = $PlayArea
@onready var _tiles_root: Control = $PlayArea/Tiles
@onready var _slot_panels: Array[Panel] = [
	$SlotsRow/Slot0,
	$SlotsRow/Slot1,
	$SlotsRow/Slot2,
]

# Логические данные плиток (для match_rules и быстрых пересчётов).
# tile_id → { id, type, grid_x, grid_y, layer, on_board, node }.
var _records: Dictionary = {}
var _slot_occupants: Array = [null, null, null]  # Tile или null
var _initial_count: int = 0
var _remaining_count: int = 0
var _resolving: bool = false
var _building: bool = false
var _last_click_tile_id: int = -1
var _last_click_msec: int = -1000
# Монотонный токен текущего билда. Каждый новый build_level увеличивает счётчик;
# асинхронные продолжения предыдущего билда сравнивают токен и тихо выходят.
var _build_token: int = 0
# Текущий масштаб пирамиды (автоподгонка под PlayArea). Используется при
# вычислении home-позиций тайлов и при возврате тайла из слота на доску.
var _board_scale: float = 1.0


func _ready() -> void:
	_style_slots()
	# Уровень строит game_screen.gd через build_level(GameState.level), как только
	# подключил сигналы. Здесь второй build_level(1) только создавал гонку
	# (две async-инстанции _layout_tiles), из-за которой при старте сразу
	# с 10 уровня доска иногда раскладывалась неправильно.


## Перестроить доску под указанный уровень.
func build_level(level: int) -> void:
	_build_token += 1
	var my_token: int = _build_token
	_building = true
	current_level = level
	_clear_all()

	var tiles_data: Array = LevelGenerator.generate(level)
	_initial_count = tiles_data.size()
	_remaining_count = _initial_count

	for data in tiles_data:
		var tile: Tile = TileScene.instantiate()
		_tiles_root.add_child(tile)
		tile.setup(data)
		tile.clicked.connect(_on_tile_clicked)

		var record: Dictionary = data.duplicate()
		record["on_board"] = true
		record["node"] = tile
		_records[int(tile.tile_id)] = record

	# Гарантируем, что PanelContainer и дети получили валидные размеры
	# (на первом фрейме после instantiate Control.size может быть Vector2.ZERO).
	await get_tree().process_frame
	if my_token != _build_token:
		return

	_layout_tiles()
	_refresh_blocked_visuals()
	progress_changed.emit(0, _initial_count)
	_building = false


# --- Layout --------------------------------------------------------------

## Раскладывает плитки в PlayArea с автоматическим масштабом: пирамида
## всегда умещается между BOARD_MARGIN-ами, даже когда тайлов много
## (уровни 7+ имеют L0+L1+L2 и в raw-координатах bbox ≈ 1000×1032 — может
## не помещаться на 3:4 планшетах и узких 9:21 устройствах).
func _layout_tiles() -> void:
	if _records.is_empty():
		return

	# 1. Bounding box в "сырых" координатах (до масштабирования).
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for rec in _records.values():
		var raw: Vector2 = _raw_position(rec["grid_x"], rec["grid_y"], rec["layer"])
		min_x = min(min_x, raw.x)
		min_y = min(min_y, raw.y)
		max_x = max(max_x, raw.x + TILE_SIZE.x)
		max_y = max(max_y, raw.y + TILE_SIZE.y)

	var bbox: Vector2 = Vector2(max_x - min_x, max_y - min_y)
	var area_size: Vector2 = _play_area.size

	# 2. Вычисляем масштаб, чтобы bbox влез в (area_size - 2*BOARD_MARGIN).
	#    Никогда не увеличиваем (s ≤ 1), иначе на маленьких уровнях плитки
	#    стали бы гигантскими и UI визуально "ломался".
	var avail_x: float = max(area_size.x - BOARD_MARGIN * 2.0, 1.0)
	var avail_y: float = max(area_size.y - BOARD_MARGIN * 2.0, 1.0)
	var s: float = min(1.0, min(avail_x / bbox.x, avail_y / bbox.y))
	s = max(s, MIN_TILE_SCALE)
	_board_scale = s

	# 3. Расставляем плитки. Каждая плитка имеет pivot = TILE_SIZE/2, scale = (s,s).
	#    После масштабирования визуальный top-left плитки = position + pivot*(1-s),
	#    визуальный размер = TILE_SIZE*s. Расстояние между центрами =
	#    (raw_b - raw_a) * s. Поэтому ставим position = raw*s + shift, где
	#    shift подбирается так, чтобы визуальный bbox оказался в центре PlayArea.
	var pivot: Vector2 = TILE_SIZE * 0.5
	var shift_x: float = area_size.x * 0.5 - pivot.x * (1.0 - s) - (min_x + max_x) * 0.5 * s
	var shift_y: float = area_size.y * 0.5 - pivot.y * (1.0 - s) - (min_y + max_y) * 0.5 * s
	var shift: Vector2 = Vector2(shift_x, shift_y)

	for rec in _records.values():
		var tile: Tile = rec["node"]
		var raw: Vector2 = _raw_position(rec["grid_x"], rec["grid_y"], rec["layer"])
		tile.scale = Vector2(s, s)
		tile.home_scale = Vector2(s, s)
		tile.position = raw * s + shift
		tile.home_position = tile.position
		tile.z_index = tile.layer_z_index()


func _raw_position(gx: int, gy: int, layer: int) -> Vector2:
	# gx, gy — индексы в half-step сетке. Плитка занимает 2 half-cells.
	return Vector2(float(gx) * HALF_CELL.x, float(gy) * HALF_CELL.y) + LAYER_LIFT * float(layer)


func _style_slots() -> void:
	for panel in _slot_panels:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.border_color = Color(0.604, 0.639, 0.780, 0.65)  # #9AA3C7
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.corner_radius_top_left = 28
		sb.corner_radius_top_right = 28
		sb.corner_radius_bottom_left = 28
		sb.corner_radius_bottom_right = 28
		panel.add_theme_stylebox_override("panel", sb)


# --- Click handling ------------------------------------------------------

func _on_tile_clicked(tile: Tile) -> void:
	if _resolving or _building:
		return

	var now: int = Time.get_ticks_msec()
	if tile.tile_id == _last_click_tile_id and now - _last_click_msec <= DUPLICATE_CLICK_MS:
		return
	_last_click_tile_id = tile.tile_id
	_last_click_msec = now

	if tile.state == Tile.State.IN_SLOT:
		_return_tile_home(tile)
		return

	if tile.state != Tile.State.ON_BOARD:
		return

	# Защита от гонок: тайл стал заблокированным между _refresh_blocked_visuals
	# и обработкой клика. В обычном потоке заблокированные тайлы НЕ получают
	# событий (mouse_filter = IGNORE, см. _refresh_blocked_visuals), поэтому
	# тут просто молча выходим — никаких shake/звуков по требованию UX.
	if not _is_record_free(tile.tile_id):
		return

	var slot_idx: int = _next_empty_slot()
	if slot_idx < 0:
		# Все 3 слота уже заняты — игнорируем (резолв должен был отработать).
		return

	AudioManager.play_sfx(&"tile_tap")
	_send_tile_to_slot(tile, slot_idx)

	if _all_slots_full():
		_resolving = true
		_resolve_triple()


func _send_tile_to_slot(tile: Tile, slot_idx: int) -> void:
	tile.play_press_bounce()
	_slot_occupants[slot_idx] = tile
	_set_record_on_board(tile.tile_id, false)
	_refresh_blocked_visuals()
	var target: Vector2 = _slot_center_in_tiles_root(slot_idx) - TILE_SIZE * 0.5
	tile.play_move_to(target)


func _return_tile_home(tile: Tile) -> void:
	# Найти и опустошить слот.
	for i in range(SLOT_COUNT):
		if _slot_occupants[i] == tile:
			_slot_occupants[i] = null
			break
	_set_record_on_board(tile.tile_id, true)
	tile.play_return_home()
	_refresh_blocked_visuals()


func _resolve_triple() -> void:
	var triple: Array = [
		_slot_occupants[0],
		_slot_occupants[1],
		_slot_occupants[2],
	]
	var data: Array = []
	for t in triple:
		data.append({"type": t.type_id})

	# Лёгкая пауза для восприятия "слот заполнился".
	await get_tree().create_timer(0.2).timeout

	if MatchRules.is_valid_triple(data):
		AudioManager.play_sfx(&"triple_match")
		await _clear_triple(triple)
	else:
		await _bounce_back_triple(triple)

	_slot_occupants = [null, null, null]
	_resolving = false

	if _remaining_count <= 0:
		level_completed.emit()
		return

	if not MatchRules.has_any_triple(_collect_on_board_records()):
		deadlock.emit()


func _clear_triple(triple: Array) -> void:
	# Удалить из логических records, запустить анимации параллельно.
	for t in triple:
		_records.erase(int(t.tile_id))
	_remaining_count -= triple.size()

	for t in triple:
		# Параллельные корутины, queue_free делается внутри play_clear.
		t.play_clear()

	# Длительность play_clear = 0.3 с; даём чуть больше для гарантии.
	await get_tree().create_timer(0.35).timeout

	tiles_cleared.emit(triple.size())
	var cleared: int = _initial_count - _remaining_count
	progress_changed.emit(cleared, _initial_count)


func _bounce_back_triple(triple: Array) -> void:
	for t in triple:
		_set_record_on_board(int(t.tile_id), true)
	for i in range(triple.size()):
		var t: Tile = triple[i]
		t.play_slot_reject()
		if i < triple.size() - 1:
			await get_tree().create_timer(0.04).timeout
	# Дать отказу в слотах завершиться визуально, потом вернуть тайлы на поле.
	await get_tree().create_timer(0.22).timeout
	AudioManager.play_sfx(&"triple_fail")
	triple_failed.emit()
	for i in range(triple.size()):
		var t: Tile = triple[i]
		t.play_return_home()
		if i < triple.size() - 1:
			await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.32).timeout
	_refresh_blocked_visuals()


# --- Records / state helpers --------------------------------------------

func _set_record_on_board(tile_id: int, on_board: bool) -> void:
	if _records.has(tile_id):
		_records[tile_id]["on_board"] = on_board


func _is_record_free(tile_id: int) -> bool:
	if not _records.has(tile_id):
		return false
	return MatchRules.is_tile_free(_records[tile_id], _records.values())


# Жёсткое правило: клики ловят ТОЛЬКО полностью свободные плитки.
# Любая плитка, над которой стоит хоть одна — становится прозрачной для кликов
# (`mouse_filter = IGNORE`). Это убирает класс ошибок «целюсь в верхний тайл,
# а игра кликает по тайлу на пару слоёв ниже».
func _refresh_blocked_visuals() -> void:
	var all_records: Array = _records.values()
	for rec in all_records:
		var tile: Tile = rec["node"]
		if tile.state != Tile.State.ON_BOARD:
			# В слоте плитка всегда кликабельна (её можно вернуть тапом).
			tile.set_click_passable(false)
			continue
		var cover_count: int = MatchRules.covering_tile_count(rec, all_records)
		tile.set_blocked_visual(cover_count > 0, cover_count)
		# passable=true → mouse_filter = IGNORE, плитка не получает события.
		tile.set_click_passable(cover_count > 0)


func _next_empty_slot() -> int:
	for i in range(SLOT_COUNT):
		if _slot_occupants[i] == null:
			return i
	return -1


func _all_slots_full() -> bool:
	for s in _slot_occupants:
		if s == null:
			return false
	return true


func _slot_center_in_tiles_root(slot_idx: int) -> Vector2:
	# Control не имеет to_local — переводим вручную. Работает, пока у предков
	# _tiles_root нет ненулевого scale/rotation (у обычных Control-ов их нет).
	var slot: Panel = _slot_panels[slot_idx]
	var slot_global_center: Vector2 = slot.global_position + slot.size * 0.5
	return slot_global_center - _tiles_root.global_position


func _collect_on_board_records() -> Array:
	var out: Array = []
	for rec in _records.values():
		if bool(rec.get("on_board", true)):
			out.append(rec)
	return out


func _clear_all() -> void:
	for rec in _records.values():
		var t: Tile = rec.get("node")
		if t and is_instance_valid(t):
			t.queue_free()
	_records.clear()
	_slot_occupants = [null, null, null]
	_resolving = false
