class_name Tile
extends Control
## Одна плитка маджонга. Сплошной цвет масти + крупная цифра ранга.
##
## Состояния (логические):
##   ON_BOARD — лежит на доске, может перекрывать нижние плитки.
##   IN_SLOT  — переехала в слот выбора, временно не блокирует.
##   DYING    — анимация исчезновения после успешной тройки, скоро queue_free.
##
## Визуальные состояния:
##   NORMAL    — обычный яркий цвет.
##   BLOCKED   — серый тинт по силе перекрытия сверху.
##   SELECTED  — увеличена + белая обводка (в слоте).
##
## Сигналы:
##   clicked(tile)      — игрок тапнул, Board решает что делать.

signal clicked(tile: Tile)

# --- Logical state -------------------------------------------------------

enum State { ON_BOARD, IN_SLOT, DYING }

@export var tile_id: int = 0
@export var type_id: String = ""
@export var grid_x: int = 0
@export var grid_y: int = 0
@export var layer: int = 0

var state: int = State.ON_BOARD
var home_position: Vector2 = Vector2.ZERO

# --- Visual constants (см. docs/STYLE.md §4) -----------------------------

const TILE_SIZE: Vector2 = Vector2(160, 200)
const CORNER_RADIUS: int = 24
const BORDER_W: int = 4
const HOVER_LIFT: float = -10.0
const SHAKE_AMP: float = 12.0
const SHAKE_TIME: float = 0.25
const SELECT_SCALE: float = 1.06

@onready var _body: Panel = $Body
@onready var _rank_label: Label = $Body/RankLabel

var _is_blocked_visual: bool = false
var _cover_count: int = 0
var _is_hovered: bool = false
var _active_tween: Tween


func _ready() -> void:
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	pivot_offset = TILE_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


## Конфигурирует плитку под данные генератора.
func setup(data: Dictionary) -> void:
	tile_id = int(data.get("id", 0))
	type_id = String(data.get("type", ""))
	grid_x = int(data.get("grid_x", 0))
	grid_y = int(data.get("grid_y", 0))
	layer = int(data.get("layer", 0))
	state = State.ON_BOARD
	_apply_visual()


## Запомнить «домашнюю» позицию (для возврата при неуспехе).
func set_home_position(p: Vector2) -> void:
	home_position = p
	position = p


## Установить визуальное состояние «заблокирована».
func set_blocked_visual(blocked: bool, cover_count: int = 0) -> void:
	var normalized_cover_count: int = clamp(cover_count, 0, 4)
	if _is_blocked_visual == blocked and _cover_count == normalized_cover_count:
		return
	_is_blocked_visual = blocked
	_cover_count = normalized_cover_count
	_apply_visual()


# --- Animations ----------------------------------------------------------

## Прокликнули по свободной плитке → лёгкий press-bounce + сигнал «забери меня в слот».
func play_press_bounce() -> void:
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.08)


## Прокликнули по заблокированной → shake + отказ.
func play_shake() -> void:
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	var t: float = SHAKE_TIME / 4.0
	_active_tween.tween_property(self, "position:x", home_position.x + SHAKE_AMP, t)
	_active_tween.tween_property(self, "position:x", home_position.x - SHAKE_AMP, t)
	_active_tween.tween_property(self, "position:x", home_position.x + SHAKE_AMP * 0.5, t)
	_active_tween.tween_property(self, "position:x", home_position.x, t)


## Анимация перелёта в позицию слота (Board вызывает после reparent).
func play_move_to(target_position: Vector2, duration: float = 0.22) -> void:
	_kill_tween()
	state = State.IN_SLOT
	z_index = 1000
	_apply_visual()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "position", target_position, duration)
	_active_tween.parallel().tween_property(self, "scale", Vector2(SELECT_SCALE, SELECT_SCALE), duration)


## Анимация возврата на доску (Board уже сделал reparent в BoardArea).
func play_return_home(duration: float = 0.3) -> void:
	_kill_tween()
	state = State.ON_BOARD
	z_index = layer_z_index()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "position", home_position, duration)
	_active_tween.parallel().tween_property(self, "scale", Vector2.ONE, duration)
	await _active_tween.finished
	_apply_visual()


## Анимация исчезновения при успешной тройке. Сама делает queue_free.
func play_clear() -> void:
	_kill_tween()
	state = State.DYING
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	_active_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	await _active_tween.finished
	queue_free()


# --- Internals -----------------------------------------------------------

func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _apply_visual() -> void:
	if not is_node_ready():
		return
	# Body styling
	var sb := StyleBoxFlat.new()
	var base: Color = TileTypes.color_for(type_id)
	if _is_blocked_visual:
		var cover_strength: float = 0.55 + float(_cover_count) * 0.1
		base = base.lerp(TileTypes.BLOCKED_TINT, clamp(cover_strength, 0.55, 0.9))
		base = base.darkened(0.08 + float(_cover_count) * 0.04)
	sb.bg_color = base
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	# Outline на hover или selected
	var outline: Color = Color(1, 1, 1, 0)
	if state == State.IN_SLOT:
		outline = Color(1, 1, 1, 0.9)
	elif _is_hovered and not _is_blocked_visual:
		outline = Color(1, 1, 1, 0.55)
	sb.border_color = outline
	sb.border_width_left = BORDER_W
	sb.border_width_top = BORDER_W
	sb.border_width_right = BORDER_W
	sb.border_width_bottom = BORDER_W
	# Тень
	if _is_blocked_visual:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 3)
	else:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 6)
	_body.add_theme_stylebox_override("panel", sb)

	# Цифра ранга
	_rank_label.text = TileTypes.rank_of(type_id)
	var rank_color: Color = TileTypes.RANK_TEXT_COLOR
	if _is_blocked_visual:
		rank_color = rank_color.lerp(Color(0.54, 0.57, 0.68), 0.45 + float(_cover_count) * 0.08)
	_rank_label.add_theme_color_override("font_color", rank_color)


func layer_z_index() -> int:
	# layer * 1000 — слой выше всегда поверх нижних слоёв.
	# grid_y * 10 — в одном слое нижние ряды поверх верхних (3D-перспектива).
	# grid_x — детерминированный порядок при равном grid_y.
	return layer * 1000 + grid_y * 10 + grid_x


# --- Input handling ------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			clicked.emit(self)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			accept_event()
			clicked.emit(self)


func _on_mouse_entered() -> void:
	if state != State.ON_BOARD or _is_blocked_visual:
		return
	_is_hovered = true
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "position:y", home_position.y + HOVER_LIFT, 0.12)
	_apply_visual()


func _on_mouse_exited() -> void:
	if state != State.ON_BOARD:
		return
	_is_hovered = false
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "position:y", home_position.y, 0.12)
	_apply_visual()
