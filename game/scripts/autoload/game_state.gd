extends Node
## Глобальная сессия: текущий уровень, счёт, переходы сцен.
## Игра бесконечная — `level` инкрементируется после каждого пройденного уровня.

signal level_changed(new_level: int)
signal score_changed(new_score: int)

var level: int = 1
var score: int = 0


## Начать новый забег: сбросить уровень и счёт.
func start_new_run() -> void:
	level = 1
	score = 0
	level_changed.emit(level)
	score_changed.emit(score)


## Перейти на следующий уровень (без смены сцены — Board перестраивается).
func next_level() -> void:
	level += 1
	level_changed.emit(level)


## Добавить очки за матч (3 плитки = +30 базово).
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
