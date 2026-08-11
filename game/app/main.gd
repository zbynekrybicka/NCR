extends Node

## Vstupní bod hry. Hlavní menu nabízí ukázkový level nebo editor (M17,
## §20.4 zatím jen provizorně) — plnohodnotné menu/výběr levelů přijde
## později.

var _menu: MainMenu
var _editor: EditorController
var _play_controller: LevelController
var _overlay: CanvasLayer

func _ready() -> void:
	InputActions.register_defaults()
	_show_menu()

func _show_menu() -> void:
	_menu = MainMenu.new()
	add_child(_menu)
	_menu.play_demo_pressed.connect(_on_play_demo)
	_menu.editor_pressed.connect(_on_open_editor)

func _on_play_demo() -> void:
	_menu.queue_free()
	_menu = null

	var level := DemoLevel.build()
	var problems := LevelValidator.validate(level)
	if not problems.is_empty():
		push_error("Ukázkový level je nevalidní: %s" % ", ".join(problems))

	_play_controller = LevelController.new()
	add_child(_play_controller)
	_play_controller.setup(level)
	_show_overlay("Menu", _on_leave_play_to_menu)

func _on_open_editor() -> void:
	_menu.queue_free()
	_menu = null

	_editor = EditorController.new()
	add_child(_editor)
	_editor.play_requested.connect(_on_play_from_editor)
	_editor.menu_requested.connect(_on_leave_editor_to_menu)

func _on_play_from_editor(simulation: Simulation) -> void:
	_editor.set_active(false)
	_play_controller = LevelController.new()
	add_child(_play_controller)
	_play_controller.setup_with_simulation(simulation)
	_show_overlay("Zpět do editoru", _on_back_to_editor)

func _on_back_to_editor() -> void:
	_play_controller.queue_free()
	_play_controller = null
	_hide_overlay()
	_editor.set_active(true)

func _on_leave_play_to_menu() -> void:
	_play_controller.queue_free()
	_play_controller = null
	_hide_overlay()
	_show_menu()

func _on_leave_editor_to_menu() -> void:
	_editor.queue_free()
	_editor = null
	_show_menu()

func _show_overlay(label: String, callback: Callable) -> void:
	_hide_overlay()
	_overlay = CanvasLayer.new()
	var button := Button.new()
	button.text = label
	button.position = Vector2(16, 16)
	button.pressed.connect(callback)
	_overlay.add_child(button)
	add_child(_overlay)

func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
