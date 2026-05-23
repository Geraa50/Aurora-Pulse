extends Node
## Глобальная сессия: текущий уровень и переходы сцен.
## Игра бесконечная — `level` инкрементируется после каждого пройденного уровня.

signal level_changed(new_level: int)

var level: int = 1


## Начать новый забег: сбросить уровень.
func start_new_run() -> void:
	start_run_at_level(1)


func start_run_at_level(start_level: int) -> void:
	level = max(1, start_level)
	level_changed.emit(level)


func reset_progress() -> void:
	level = 1
	level_changed.emit(level)


## Перейти на следующий уровень (без смены сцены — Board перестраивается).
func next_level() -> void:
	level += 1
	level_changed.emit(level)


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
