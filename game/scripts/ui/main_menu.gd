extends Control
## Главное меню: старт с 1 уровня, скрытый переход на 10 (тап по «Aurora Pulse»),
## сброс прогресса и выход.

@onready var play_button: Button = $SafeArea/VBox/PlayButton
@onready var level_10_button: Button = $SafeArea/VBox/TitleRow/Level10Button
@onready var reset_button: Button = $SafeArea/VBox/ResetButton
@onready var exit_button: Button = $SafeArea/VBox/ExitButton
@onready var reset_confirm: ConfirmationDialog = $ResetConfirmDialog


func _ready() -> void:
	AudioManager.play_music()
	_style_hidden_level_10_button()
	play_button.pressed.connect(_on_play_pressed)
	level_10_button.pressed.connect(_on_level_10_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	reset_confirm.confirmed.connect(_on_reset_confirmed)


func _style_hidden_level_10_button() -> void:
	level_10_button.text = ""
	level_10_button.flat = true
	level_10_button.focus_mode = Control.FOCUS_NONE
	var transparent := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		level_10_button.add_theme_stylebox_override(style_name, transparent)


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
