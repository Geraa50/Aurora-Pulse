class_name TileTypes
extends RefCounted
## 27 типов плиток: 3 масти × 9 рангов.
##
## Визуал — сплошной уникальный цвет каждого типа + крупная цифра ранга (1–9).
## Палитра — docs/STYLE.md §2. Менять цвета ТОЛЬКО там и здесь синхронно.

const SUITS: PackedStringArray = ["bamboo", "circle", "char"]
const RANKS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

## У каждого типа свой цвет, чтобы совпадения не путались между разными тайлами.
const TYPE_COLORS: Dictionary = {
	"bamboo_1": Color(0.208, 0.769, 0.451),  # #35C473
	"bamboo_2": Color(0.118, 0.690, 0.620),  # #1EB09E
	"bamboo_3": Color(0.224, 0.812, 0.286),  # #39CF49
	"bamboo_4": Color(0.533, 0.784, 0.196),  # #88C832
	"bamboo_5": Color(0.000, 0.737, 0.396),  # #00BC65
	"bamboo_6": Color(0.267, 0.690, 0.353),  # #44B05A
	"bamboo_7": Color(0.000, 0.592, 0.533),  # #009788
	"bamboo_8": Color(0.608, 0.714, 0.173),  # #9BB62C
	"bamboo_9": Color(0.094, 0.812, 0.682),  # #18CFAD
	"circle_1": Color(0.302, 0.659, 1.000),  # #4DA8FF
	"circle_2": Color(0.259, 0.463, 1.000),  # #4276FF
	"circle_3": Color(0.373, 0.812, 1.000),  # #5FCFFF
	"circle_4": Color(0.451, 0.486, 1.000),  # #737CFF
	"circle_5": Color(0.204, 0.800, 0.902),  # #34CCE6
	"circle_6": Color(0.537, 0.361, 1.000),  # #895CFF
	"circle_7": Color(0.000, 0.576, 0.902),  # #0093E6
	"circle_8": Color(0.494, 0.667, 1.000),  # #7EAAFF
	"circle_9": Color(0.200, 0.416, 0.902),  # #336AE6
	"char_1": Color(1.000, 0.420, 0.616),  # #FF6B9D
	"char_2": Color(1.000, 0.353, 0.353),  # #FF5A5A
	"char_3": Color(1.000, 0.549, 0.235),  # #FF8C3C
	"char_4": Color(0.890, 0.318, 0.725),  # #E351B9
	"char_5": Color(1.000, 0.678, 0.267),  # #FFAD44
	"char_6": Color(0.925, 0.263, 0.486),  # #EC437C
	"char_7": Color(0.800, 0.357, 0.894),  # #CC5BE4
	"char_8": Color(1.000, 0.494, 0.392),  # #FF7E64
	"char_9": Color(0.969, 0.306, 0.655),  # #F74EA7
}

## Цвет цифры на плитке. Белый — читается на всех 3 мастях.
const RANK_TEXT_COLOR: Color = Color(0.941, 0.957, 1.000)  # #F0F4FF

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
	return TYPE_COLORS.get(type_id, Color.WHITE)


static func is_valid_type(type_id: String) -> bool:
	var parts: PackedStringArray = split(type_id)
	if parts.size() != 2:
		return false
	return SUITS.has(parts[0]) and RANKS.has(parts[1])
