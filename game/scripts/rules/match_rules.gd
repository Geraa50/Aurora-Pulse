class_name MatchRules
extends RefCounted
## Правила матчинга. Чистая логика без зависимостей от сцен.
##
## Все плитки описываются Dictionary: { id, type, grid_x, grid_y, layer, on_board }.
## `on_board = true` — плитка лежит на поле и может перекрывать нижние плитки.
## `on_board = false` — плитка временно в слоте выбора, в проверке свободы
## она НЕ участвует. Это даёт ожидаемое UX: кликнул крайнюю → центральная стала свободной.


## Тройка валидна, если ровно 3 плитки и у всех одинаковый `type`.
static func is_valid_triple(selected: Array) -> bool:
	if selected.size() != 3:
		return false
	var type_id: Variant = selected[0].get("type", null)
	if type_id == null:
		return false
	for t in selected:
		if t.get("type") != type_id:
			return false
	return true


## Свободна ли плитка на доске (учитывая только плитки с on_board = true).
##
## Координаты — в half-step сетке: каждая плитка занимает 2 half-cells × 2
## half-cells. Плитка выше перекрывает нижнюю, если их bounding box-ы
## пересекаются (т.е. |dx| < 2 и |dy| < 2 в half-step индексах).
##
## Free = нет плитки выше, чьи 2×2 half-cells перекрывают наши.
## Поэтому самый верхний слой всегда доступен, а нижние открываются по мере
## снятия перекрывающих плиток.
static func is_tile_free(tile: Dictionary, all_tiles: Array) -> bool:
	return covering_tile_count(tile, all_tiles) == 0


## Сколько плиток верхних слоёв перекрывают эту плитку.
## Значение используется и для логики, и для более понятного blocked-визуала.
static func covering_tile_count(tile: Dictionary, all_tiles: Array) -> int:
	var tid: int = int(tile.get("id", -1))
	var tx: int = int(tile.get("grid_x", 0))
	var ty: int = int(tile.get("grid_y", 0))
	var tl: int = int(tile.get("layer", 0))
	var count: int = 0
	for other in all_tiles:
		if int(other.get("id", -1)) == tid:
			continue
		if not bool(other.get("on_board", true)):
			continue
		if int(other.get("layer", 0)) <= tl:
			continue
		var ox: int = int(other.get("grid_x", 0))
		var oy: int = int(other.get("grid_y", 0))
		if abs(ox - tx) < 2 and abs(oy - ty) < 2:
			count += 1
	return count


## Есть ли хоть одна валидная sequentially-collectible тройка среди
## оставшихся on-board плиток. Используется для детекта тупика.
static func has_any_triple(all_tiles: Array) -> bool:
	# Группируем по type, в каждой группе берём только on_board.
	var by_type: Dictionary = {}
	for t in all_tiles:
		if not bool(t.get("on_board", true)):
			continue
		var k: String = String(t.get("type", ""))
		if k.is_empty():
			continue
		if not by_type.has(k):
			by_type[k] = []
		by_type[k].append(t)

	for k in by_type.keys():
		var group: Array = by_type[k]
		if group.size() < 3:
			continue
		# Достаточно: в группе ≥ 3 плиток, и хотя бы одна из них free прямо сейчас.
		# Игрок сможет последовательно убрать ещё две: после клика по free она
		# уходит в слот и открывает плитки нижних слоёв.
		var any_free: bool = false
		for t in group:
			if is_tile_free(t, all_tiles):
				any_free = true
				break
		if any_free:
			return true
	return false
