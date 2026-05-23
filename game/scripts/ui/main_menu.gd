extends Control
## Главное меню: старт с 1 или 10 уровня, сброс прогресса и выход.

@onready var play_button: Button = $SafeArea/VBox/PlayButton
@onready var level_10_button: Button = $SafeArea/VBox/Level10Button
@onready var reset_button: Button = $SafeArea/VBox/ResetButton
@onready var exit_button: Button = $SafeArea/VBox/ExitButton
@onready var reset_confirm: ConfirmationDialog = $ResetConfirmDialog


func _ready() -> void:
	AudioManager.play_music()
	play_button.pressed.connect(_on_play_pressed)
	level_10_button.pressed.connect(_on_level_10_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	reset_confirm.confirmed.connect(_on_reset_confirmed)


func _on_play_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	GameState.start_new_run()
	GameState.go_to_game()


func _on_level_10_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	GameState.start_run_at_level(10)
	GameState.go_to_game()


func _on_reset_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	reset_confirm.popup_centered()


func _on_reset_confirmed() -> void:
	AudioManager.play_sfx(&"ui_button")
	GameState.reset_progress()


func _on_exit_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	get_tree().quit()
