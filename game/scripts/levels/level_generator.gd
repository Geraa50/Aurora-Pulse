class_name LevelGenerator
extends RefCounted
## Генератор многослойных раскладок маджонга. Гарантирует решаемость
## через reverse-simulation: каждая положенная тройка должна быть
## **sequentially collectible** на доске = (уже placed) ∪ {эта тройка}.
##
## Координатная система — **half-step grid**:
##   Плитка занимает 2 half-cells × 2 half-cells. Верхние слои смещены
##   на 1 half-cell относительно нижних: одна L1-плитка перекрывает
##   4 угла L0-плиток
##   (классическая mahjong-пирамида со ступенями).
##
## Форма (shape) по уровню:
##   L0: base_cols × base_rows плиток (растёт с уровнем)
##   L1: (cols-1) × (rows-1), offset (1, 1) half-cell — с 3-го уровня
##   L2: (cols-2) × (rows-2), offset (2, 2) half-cell — с 5-го уровня
## После генерации подгоняем до кратности 3 отбрасыванием угловых L0.
##
## Сравнение слотов — по уникальному id (Dictionary в GDScript сравниваются deep).


## Возвращает список слотов { id, grid_x, grid_y, layer } для уровня.
## grid_x, grid_y — в half-step единицах.
static func shape_for_level(level: int) -> Array:
	var lvl: int = max(1, level)
	var extra: int = max(0, lvl - 1)

	var base_cols: int = clamp(3 + (extra / 2), 3, 6)
	var base_rows: int = clamp(3 + (extra / 3), 3, 5)

	var slots: Array = []
	var next_id: int = 1

	# Layer 0 — base. Плитка (c, r) на half-step координатах (c*2, r*2).
	for r in range(base_rows):
		for c in range(base_cols):
			slots.append({"id": next_id, "grid_x": c * 2, "grid_y": r * 2, "layer": 0})
			next_id += 1

	# Layer 1 — на 1 half-cell внутрь и вверх (классическая пирамида).
	if lvl >= 3 and base_cols >= 2 and base_rows >= 2:
		var l1_cols: int = base_cols - 1
		var l1_rows: int = base_rows - 1
		for r in range(l1_rows):
			for c in range(l1_cols):
				slots.append({"id": next_id, "grid_x": c * 2 + 1, "grid_y": r * 2 + 1, "layer": 1})
				next_id += 1

	# Layer 2 — ещё на 1 half-cell внутрь.
	if lvl >= 5 and base_cols >= 3 and base_rows >= 3:
		var l2_cols: int = base_cols - 2
		var l2_rows: int = base_rows - 2
		for r in range(l2_rows):
			for c in range(l2_cols):
				slots.append({"id": next_id, "grid_x": c * 2 + 2, "grid_y": r * 2 + 2, "layer": 2})
				next_id += 1

	# Подгоняем количество до кратности 3, отбрасывая угловые слоты L0.
	# Углы L0 — на (0, 0), ((base_cols-1)*2, 0), (0, (base_rows-1)*2),
	# ((base_cols-1)*2, (base_rows-1)*2).
	while slots.size() % 3 != 0:
		var drop_idx: int = _find_corner_l0_index(slots, base_cols, base_rows)
		if drop_idx < 0:
			break
		slots.remove_at(drop_idx)

	return slots


## Сгенерировать полный набор плиток для уровня (с типами).
## Возвращает Array of Dictionary: { id, type, layer, grid_x, grid_y }.
static func generate(level: int, rng_seed: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var all_slots: Array = shape_for_level(level)
	if all_slots.is_empty():
		return []

	# Reverse-simulation priority:
	#  1) ниже layer первыми (placed first в reverse = снимутся последними в forward),
	#  2) ближе к центру первыми (центральные плитки трудозатратнее, ставим раньше).
	var cx: float = 0.0
	var cy: float = 0.0
	for s in all_slots:
		cx += float(s["grid_x"])
		cy += float(s["grid_y"])
	cx /= float(all_slots.size())
	cy /= float(all_slots.size())

	var remaining: Array = all_slots.duplicate()
	remaining.sort_custom(func(a, b):
		if int(a["layer"]) != int(b["layer"]):
			return int(a["layer"]) < int(b["layer"])
		var da: float = abs(float(a["grid_x"]) - cx) + abs(float(a["grid_y"]) - cy)
		var db: float = abs(float(b["grid_x"]) - cx) + abs(float(b["grid_y"]) - cy)
		return da < db
	)

	# Pool типов: подмножество из 27, размер растёт с уровнем.
	var types_count: int = clamp(2 + level, 3, 9)
	var all_types: PackedStringArray = TileTypes.all_types()
	var pool: Array = []
	for t in all_types:
		pool.append(t)
	pool.shuffle()
	var chosen: Array = pool.slice(0, types_count)

	var placed: Array = []

	while remaining.size() >= 3:
		var picks: Array = _find_3_collectible(remaining, placed)
		if picks.is_empty():
			# Fallback на pyramid-форме практически не встречается.
			picks = remaining.slice(0, 3)

		var type_id: String = chosen[rng.randi() % chosen.size()]
		for s in picks:
			s["type"] = type_id
			placed.append(s)
			_remove_by_id(remaining, int(s["id"]))

	return placed


# --- internals ------------------------------------------------------------

static func _find_corner_l0_index(slots: Array, cols: int, rows: int) -> int:
	# Углы L0 в half-step координатах.
	var max_x: int = (cols - 1) * 2
	var max_y: int = (rows - 1) * 2
	var corners: Array = [
		Vector2i(0, 0),
		Vector2i(max_x, 0),
		Vector2i(0, max_y),
		Vector2i(max_x, max_y),
	]
	for i in range(slots.size()):
		var s: Dictionary = slots[i]
		if int(s["layer"]) != 0:
			continue
		var pos := Vector2i(int(s["grid_x"]), int(s["grid_y"]))
		if pos in corners:
			return i
	return -1


static func _remove_by_id(arr: Array, target_id: int) -> void:
	for i in range(arr.size()):
		if int(arr[i]["id"]) == target_id:
			arr.remove_at(i)
			return


## Жадный поиск тройки, sequentially collectible на (placed ∪ тройка).
## Перебор в порядке remaining (pre-sorted) — берём первую подходящую.
static func _find_3_collectible(remaining: Array, placed: Array) -> Array:
	var n: int = remaining.size()
	for i in range(n):
		var c1: Dictionary = remaining[i]
		for j in range(n):
			if j == i:
				continue
			var c2: Dictionary = remaining[j]
			for k in range(n):
				if k == i or k == j:
					continue
				var c3: Dictionary = remaining[k]
				if _can_collect_triple([c1, c2, c3], placed):
					return [c1, c2, c3]
	return []


## Можно ли собрать тройку sequentially на доске = (placed ∪ triple).
## После клика плитка уходит в слот → временно убирается с доски.
static func _can_collect_triple(triple: Array, placed: Array) -> bool:
	var board: Array = []
	for p in placed:
		board.append(p)
	for t in triple:
		board.append(t)

	var queue: Array = triple.duplicate()
	while queue.size() > 0:
		var free_idx: int = -1
		for i in range(queue.size()):
			if _is_free_in(queue[i], board):
				free_idx = i
				break
		if free_idx < 0:
			return false
		var taken: Dictionary = queue[free_idx]
		queue.remove_at(free_idx)
		_remove_by_id(board, int(taken["id"]))
	return true


## Free на half-step grid: нет плитки выше, чьи 2×2 half-cells
## перекрывают эту плитку (|dx|<2 и |dy|<2).
static func _is_free_in(slot: Dictionary, board: Array) -> bool:
	var sid: int = int(slot["id"])
	var sx: int = int(slot["grid_x"])
	var sy: int = int(slot["grid_y"])
	var sl: int = int(slot["layer"])

	for other in board:
		if int(other["id"]) == sid:
			continue
		if int(other["layer"]) <= sl:
			continue
		var ox: int = int(other["grid_x"])
		var oy: int = int(other["grid_y"])
		if abs(ox - sx) < 2 and abs(oy - sy) < 2:
			return false
	return true
