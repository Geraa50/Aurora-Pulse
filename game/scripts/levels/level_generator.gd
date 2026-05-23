class_name LevelGenerator
extends RefCounted
## Генератор многослойных раскладок маджонга. Гарантирует решаемость
## через reverse-simulation: каждая положенная тройка должна быть
## **sequentially collectible** на доске = (уже placed) ∪ {эта тройка}.
## На многослойных уровнях генератор предпочитает тройки со смешанными
## слоями, чтобы игрок регулярно собирал совпадения между разными высотами.
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

# Ограничение перебора троек на больших уровнях (см. _find_3_collectible).
const SEARCH_CANDIDATE_CAP: int = 18
const COLLECT_CACHE_MAX_ENTRIES: int = 12000


## Предрасчёт «кто кого перекрывает» для всех слотов уровня.
## coverers[tile_id] → Array[int] id плиток выше, чьи 2×2 half-cells накрывают tile.
## Используется генератором и Board._refresh_blocked_visuals.
static func build_coverer_map(slots: Array) -> Dictionary:
	var coverers: Dictionary = {}
	for s in slots:
		coverers[int(s["id"])] = []
	for s in slots:
		var sid: int = int(s["id"])
		var sx: int = int(s["grid_x"])
		var sy: int = int(s["grid_y"])
		var sl: int = int(s["layer"])
		for other in slots:
			var oid: int = int(other["id"])
			if oid == sid:
				continue
			if int(other["layer"]) <= sl:
				continue
			if abs(int(other["grid_x"]) - sx) < 2 and abs(int(other["grid_y"]) - sy) < 2:
				(coverers[sid] as Array).append(oid)
	return coverers


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

	# Pool типов: **один тип на ранг**. Это инвариант, который игроки видят:
	# одинаковая цифра на тайлах ВСЕГДА означает одинаковый тип/цвет (= match).
	# Иначе на уровне попадались, например, `bamboo_5` и `circle_5` — оба
	# показывают «5», но не складываются, что путало пользователя.
	#
	# При triple_count > 9 (большие уровни) типы зацикливаются: один тип может
	# дать 2-3 тройки (= 6-9 тайлов), но никогда не появятся ДВА разных типа с
	# одной цифрой. До 9 троек — каждая тройка уникального цвета и ранга.
	var triple_count: int = all_slots.size() / 3
	var chosen: Array = _pick_unique_rank_types(triple_count, rng)

	var ctx: Dictionary = {
		"coverers": build_coverer_map(all_slots),
		"collect_cache": {},
	}
	var placed: Array = []
	var remaining_index: Dictionary = {}
	for i in range(remaining.size()):
		remaining_index[int(remaining[i]["id"])] = i
	var type_index: int = 0
	var prefer_mixed: bool = level >= 3

	while remaining.size() >= 3:
		var picks: Array = _find_3_collectible(remaining, placed, ctx, prefer_mixed)
		if picks.is_empty():
			# Fallback на pyramid-форме практически не встречается.
			picks = remaining.slice(0, 3)

		var type_id: String = chosen[type_index % chosen.size()]
		type_index += 1
		for s in picks:
			s["type"] = type_id
			placed.append(s)
			_remove_from_remaining(remaining, remaining_index, int(s["id"]))

	return placed


## Возвращает массив типов с уникальным рангом (`{bamboo,circle,char}_<rank>` —
## выбирается случайная масть на каждый ранг). Размер массива — min(want_count, 9).
## Вызвавший должен зацикливать его, если троек больше 9.
static func _pick_unique_rank_types(want_count: int, rng: RandomNumberGenerator) -> Array:
	var by_rank: Dictionary = {}
	for t in TileTypes.all_types():
		var rank: String = TileTypes.rank_of(t)
		if not by_rank.has(rank):
			by_rank[rank] = []
		(by_rank[rank] as Array).append(t)

	var ranks: Array = by_rank.keys()
	_shuffle_array(ranks, rng)

	var unique_count: int = clamp(want_count, 3, ranks.size())
	var out: Array = []
	for i in range(unique_count):
		var suits: Array = by_rank[ranks[i]]
		_shuffle_array(suits, rng)
		out.append(suits[0])
	return out


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


## O(1) удаление из remaining + актуализация индексов (swap-with-last).
static func _remove_from_remaining(remaining: Array, index_map: Dictionary, target_id: int) -> void:
	if not index_map.has(target_id):
		return
	var idx: int = int(index_map[target_id])
	var last_idx: int = remaining.size() - 1
	if idx != last_idx:
		var swapped: Dictionary = remaining[last_idx]
		remaining[idx] = swapped
		index_map[int(swapped["id"])] = idx
	remaining.resize(last_idx)
	index_map.erase(target_id)


static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Жадный поиск тройки, sequentially collectible на (placed ∪ тройка).
## На больших уровнях: i<j<k (в 6× меньше перебор), кэш collectibility,
## сначала верхние слои (SEARCH_CANDIDATE_CAP), при неудаче — полный скан.
static func _find_3_collectible(
	remaining: Array,
	placed: Array,
	ctx: Dictionary,
	prefer_mixed_layers: bool,
) -> Array:
	var quick: Array = _try_quick_collectible_triple(remaining, placed, ctx, prefer_mixed_layers)
	if not quick.is_empty():
		return quick
	if prefer_mixed_layers:
		quick = _try_quick_collectible_triple(remaining, placed, ctx, false)
		if not quick.is_empty():
			return quick
	var use_cap: bool = remaining.size() > SEARCH_CANDIDATE_CAP
	# Только ограниченный перебор; полный O(n³) по всем remaining убран — он подвисал на ур. 10+.
	return _scan_collectible_triples(remaining, placed, ctx, false, use_cap)


## Быстрый путь: перебор только среди «верхних» кандидатов (≤10), ранний выход.
static func _try_quick_collectible_triple(
	remaining: Array,
	placed: Array,
	ctx: Dictionary,
	require_mixed: bool,
) -> Array:
	var candidates: Array = _select_search_candidates(remaining, 10)
	var cn: int = candidates.size()
	var fallback: Array = []
	for i in range(cn):
		var c1: Dictionary = candidates[i]
		for j in range(i + 1, cn):
			var c2: Dictionary = candidates[j]
			for k in range(j + 1, cn):
				var triple: Array = [c1, c2, candidates[k]]
				if not _can_collect_triple_fast(triple, placed, ctx):
					continue
				if not require_mixed:
					return triple
				var mixed_score: int = _mixed_layer_score(triple)
				if mixed_score >= 2:
					return triple
				if fallback.is_empty():
					fallback = triple
	return fallback


static func _scan_collectible_triples(
	remaining: Array,
	placed: Array,
	ctx: Dictionary,
	prefer_mixed_layers: bool,
	use_candidate_cap: bool,
) -> Array:
	var candidates: Array = remaining
	if use_candidate_cap:
		candidates = _select_search_candidates(remaining, SEARCH_CANDIDATE_CAP)

	var best_mixed: Array = []
	var best_mixed_score: int = -1
	var cn: int = candidates.size()
	for i in range(cn):
		var c1: Dictionary = candidates[i]
		for j in range(i + 1, cn):
			var c2: Dictionary = candidates[j]
			for k in range(j + 1, cn):
				var triple: Array = [c1, c2, candidates[k]]
				if not _can_collect_triple_fast(triple, placed, ctx):
					continue
				if not prefer_mixed_layers:
					return triple
				var mixed_score: int = _mixed_layer_score(triple)
				# Достаточно любой кросс-слойной тройки — не ищем идеальный score=3.
				if mixed_score >= 2:
					return triple
				if best_mixed.is_empty():
					best_mixed = triple
					best_mixed_score = mixed_score
				elif mixed_score > best_mixed_score:
					best_mixed = triple
					best_mixed_score = mixed_score
	return best_mixed


static func _select_search_candidates(remaining: Array, cap: int) -> Array:
	# Чередуем слои (L2, L1, L0, L2, …) — быстрее находим mixed-layer тройки.
	var by_layer: Dictionary = {}
	for s in remaining:
		var layer: int = int(s["layer"])
		if not by_layer.has(layer):
			by_layer[layer] = []
		(by_layer[layer] as Array).append(s)
	var layers: Array = by_layer.keys()
	layers.sort()
	layers.reverse()
	for layer in layers:
		var group: Array = by_layer[layer]
		group.sort_custom(func(a, b): return int(a["grid_y"]) > int(b["grid_y"]))
	var out: Array = []
	var round_idx: int = 0
	while out.size() < cap:
		var added_any: bool = false
		for layer in layers:
			var group: Array = by_layer[layer]
			if round_idx >= group.size():
				continue
			out.append(group[round_idx])
			added_any = true
			if out.size() >= cap:
				break
		if not added_any:
			break
		round_idx += 1
	return out


## Оценка mixed-layer тройки:
## 3 — два тайла на одном верхнем слое, третий ниже;
## 2 — любой другой набор из разных слоёв;
## 0 — все три на одном слое.
static func _mixed_layer_score(triple: Array) -> int:
	var counts: Dictionary = {}
	var min_layer: int = 999
	var max_layer: int = -999
	for t in triple:
		var layer: int = int(t["layer"])
		counts[layer] = int(counts.get(layer, 0)) + 1
		min_layer = min(min_layer, layer)
		max_layer = max(max_layer, layer)
	if min_layer == max_layer:
		return 0
	for layer in counts.keys():
		if int(counts[layer]) == 2 and int(layer) == max_layer:
			return 3
	return 2


## Можно ли собрать тройку sequentially на доске = (placed ∪ triple).
static func _can_collect_triple_fast(triple: Array, placed: Array, ctx: Dictionary) -> bool:
	var cache: Dictionary = ctx["collect_cache"]
	var key: int = _triple_cache_key(triple, placed)
	if cache.has(key):
		return bool(cache[key])

	var coverers: Dictionary = ctx["coverers"]
	var on_board: Dictionary = {}
	for p in placed:
		on_board[int(p["id"])] = true
	for t in triple:
		on_board[int(t["id"])] = true

	var queue_ids: Array = [
		int(triple[0]["id"]),
		int(triple[1]["id"]),
		int(triple[2]["id"]),
	]
	var pending: int = 3
	while pending > 0:
		var free_idx: int = -1
		for i in range(queue_ids.size()):
			if _is_free_id(int(queue_ids[i]), on_board, coverers):
				free_idx = i
				break
		if free_idx < 0:
			_cache_collect_result(cache, key, false)
			return false
		var taken_id: int = int(queue_ids[free_idx])
		queue_ids.remove_at(free_idx)
		on_board.erase(taken_id)
		pending -= 1

	_cache_collect_result(cache, key, true)
	return true


static func _is_free_id(tile_id: int, on_board: Dictionary, coverers: Dictionary) -> bool:
	if not coverers.has(tile_id):
		return true
	for coverer_id in coverers[tile_id]:
		if on_board.has(coverer_id):
			return false
	return true


static func _triple_cache_key(triple: Array, placed: Array) -> int:
	var h: int = placed.size() * 131
	for t in triple:
		h = (h * 131) ^ int(t["id"])
	for p in placed:
		h = (h * 131) ^ int(p["id"])
	return h


static func _cache_collect_result(cache: Dictionary, key: int, value: bool) -> void:
	if cache.size() >= COLLECT_CACHE_MAX_ENTRIES:
		cache.clear()
	cache[key] = value
