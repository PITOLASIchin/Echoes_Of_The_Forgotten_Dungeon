extends CanvasLayer

@onready var pause_button: TextureButton = $PauseButton
@onready var pause_menu: Control = $PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_menu.hide()

	pause_button.pressed.connect(_on_pause_button_pressed)


func _on_pause_button_pressed() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()
		
func _on_resume_button_pressed():
	resume_game()

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func pause_game() -> void:
	get_tree().paused = true

	pause_button.hide()
	pause_menu.show()


func resume_game() -> void:
	get_tree().paused = false

	pause_menu.hide()
	pause_button.show()
