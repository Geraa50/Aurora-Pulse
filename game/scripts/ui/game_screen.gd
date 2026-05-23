extends Control
## Игровой экран. Связывает Board ↔ HUD ↔ GameState.
##
## Поток:
##  1. _ready: подписки на сигналы доски + GameState, build_level(GameState.level).
##  2. tiles_cleared → сигнал прогресса.
##  3. progress_changed → обновление ProgressBar.
##  4. level_completed → бар = 100%, оверлей со звёздами и кнопкой "Дальше".
##  5. NextButton.pressed → next_level() + build_level (бесконечный режим).

@onready var level_label: Label = $SafeArea/VBox/HeaderRow/LevelLabel
@onready var progress_bar: ProgressBar = $SafeArea/VBox/ProgressBar
@onready var board: Board = $SafeArea/VBox/BoardArea/Board
@onready var menu_button: Button = $SafeArea/VBox/MenuButton
@onready var overlay: ColorRect = $LevelCompleteOverlay
@onready var next_button: Button = $LevelCompleteOverlay/OverlayCenter/OverlayVBox/NextButton


func _ready() -> void:
	AudioManager.play_music()
	menu_button.pressed.connect(_on_menu_pressed)
	next_button.pressed.connect(_on_next_pressed)

	GameState.level_changed.connect(_on_level_changed)
	board.tiles_cleared.connect(_on_tiles_cleared)
	board.progress_changed.connect(_on_progress_changed)
	board.level_completed.connect(_on_level_completed)
	board.deadlock.connect(_on_deadlock)

	_on_level_changed(GameState.level)
	overlay.visible = false
	board.build_level(GameState.level)


func _on_tiles_cleared(_count: int) -> void:
	pass


func _on_progress_changed(value: int, max_value: int) -> void:
	progress_bar.max_value = float(max(1, max_value))
	progress_bar.value = float(value)


func _on_level_completed() -> void:
	AudioManager.play_sfx(&"level_complete", 0.0)
	progress_bar.value = progress_bar.max_value
	overlay.visible = true


func _on_deadlock() -> void:
	# Очень редкий случай. Тихо пересобираем уровень той же сложности.
	board.build_level(GameState.level)


func _on_level_changed(new_level: int) -> void:
	level_label.text = "Уровень %d" % new_level


func _on_next_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	overlay.visible = false
	GameState.next_level()
	board.build_level(GameState.level)


func _on_menu_pressed() -> void:
	AudioManager.play_sfx(&"ui_button")
	GameState.go_to_main_menu()
