class_name TileTypes
extends RefCounted
## 27 типов плиток: 3 масти × 9 рангов.
##
## Визуал — сплошной цвет масти + крупная цифра ранга (1–9).
## Палитра — docs/STYLE.md §2. Менять цвета ТОЛЬКО там и здесь синхронно.

const SUITS: PackedStringArray = ["bamboo", "circle", "char"]
const RANKS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

## Базовый цвет масти. Один цвет на всю масть (внутри ранг = только цифра).
const SUIT_COLORS: Dictionary = {
	"bamboo": Color(0.243, 0.812, 0.557),  # #3ECF8E emerald
	"circle": Color(0.302, 0.659, 1.000),  # #4DA8FF sky blue
	"char":   Color(1.000, 0.420, 0.616),  # #FF6B9D rose
}

## Цвет цифры на плитке. Белый — читается на всех 3 мастях.
const RANK_TEXT_COLOR: Color = Color(0.941, 0.957, 1.000)  # #F0F4FF

## Цвет «заблокированной» плитки — серее и холоднее.
const BLOCKED_TINT: Color = Color(0.450, 0.450, 0.550)


static func all_types() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for suit in SUITS:
		for rank in RANKS:
			result.append("%s_%s" % [suit, rank])
	return result


## Разобрать `bamboo_5` → ["bamboo", "5"].
static func split(type_id: String) -> PackedStringArray:
	return type_id.split("_", false)


static func suit_of(type_id: String) -> String:
	var parts: PackedStringArray = split(type_id)
	return parts[0] if parts.size() >= 1 else ""


static func rank_of(type_id: String) -> String:
	var parts: PackedStringArray = split(type_id)
	return parts[1] if parts.size() >= 2 else "?"


static func color_for(type_id: String) -> Color:
	var suit: String = suit_of(type_id)
	return SUIT_COLORS.get(suit, Color.WHITE)


static func is_valid_type(type_id: String) -> bool:
	var parts: PackedStringArray = split(type_id)
	if parts.size() != 2:
		return false
	return SUITS.has(parts[0]) and RANKS.has(parts[1])
