extends Control
## Главное меню. Две кнопки по ТЗ: Играть и Выйти.

@onready var play_button: Button = $SafeArea/VBox/PlayButton
@onready var exit_button: Button = $SafeArea/VBox/ExitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	GameState.start_new_run()
	GameState.go_to_game()


func _on_exit_pressed() -> void:
	get_tree().quit()
