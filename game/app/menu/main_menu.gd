class_name MainMenu
extends CanvasLayer

## Vstupní obrazovka (§20.4 zatím jen provizorně) — výběr mezi ukázkovým
## levelem a editorem. Vizuál je záměrně placeholder (§20.1).

signal play_demo_pressed
signal editor_pressed

func _ready() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.4
	box.anchor_bottom = 0.4
	box.position = Vector2(-100, 0)
	box.custom_minimum_size = Vector2(200, 0)
	add_child(box)

	var title := Label.new()
	title.text = "Nature Cybernetic Robots"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var play_button := Button.new()
	play_button.text = "Hrát ukázkový level"
	play_button.pressed.connect(func(): play_demo_pressed.emit())
	box.add_child(play_button)

	var editor_button := Button.new()
	editor_button.text = "Editor levelů"
	editor_button.pressed.connect(func(): editor_pressed.emit())
	box.add_child(editor_button)
