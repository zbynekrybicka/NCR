class_name EditorUi
extends CanvasLayer

## Ovládací panel editoru (placeholder vzhled, §20.1). Neřeší žádná
## pravidla hry ani formát souboru — jen sesbírá vstup od hráče a pošle ho
## ven jako signál; o zbytek se stará EditorController.

signal block_tool_selected(block_type: int)
signal robot_tool_selected(kind: int)
signal item_tool_selected(item_type: int)
signal key_tool_selected
signal erase_tool_selected
signal rotate_pressed
signal undo_pressed
signal redo_pressed
signal save_requested(path: String)
signal load_requested(path: String)
signal new_level_requested(size: Vector3i)
signal play_pressed
signal menu_pressed

const LEVELS_DIR := "user://levels"

const BLOCK_LABELS := {
	GridTypes.BlockType.WALL: "Zeď",
	GridTypes.BlockType.RAMP: "Šikmina",
	GridTypes.BlockType.DIRT: "Hlína",
	GridTypes.BlockType.STONE: "Kámen",
	GridTypes.BlockType.ICE: "Led",
	GridTypes.BlockType.WOOD: "Dřevo",
	GridTypes.BlockType.TARGET: "Cíl",
}

const ITEM_LABELS := {
	GridTypes.ItemType.FUEL: "Palivo",
	GridTypes.ItemType.SERVICE_KIT: "Service kit",
}

var _status_label: Label
var _tool_label: Label
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _new_dialog: ConfirmationDialog
var _new_size_fields: Array = []
var _tool_group := ButtonGroup.new()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(LEVELS_DIR)

	var top_bar := _make_top_bar()
	add_child(top_bar)

	var side_panel := _make_side_panel()
	add_child(side_panel)

	_status_label = Label.new()
	_status_label.position = Vector2(220, 40)
	_status_label.add_theme_font_size_override("font_size", 14)
	add_child(_status_label)

	_tool_label = Label.new()
	_tool_label.position = Vector2(16, 40)
	_tool_label.add_theme_font_size_override("font_size", 14)
	add_child(_tool_label)
	set_tool_label("Nástroj: zeď")

	_build_dialogs()

func set_status(text: String) -> void:
	_status_label.text = text

func set_tool_label(text: String) -> void:
	_tool_label.text = text

# ── Horní lišta ──────────────────────────────────────────────────────────

func _make_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 8)
	_add_button(bar, "Nový", func(): _new_dialog.popup_centered())
	_add_button(bar, "Uložit", func(): _save_dialog.popup_centered())
	_add_button(bar, "Načíst", func(): _load_dialog.popup_centered())
	_add_button(bar, "Zpět (Ctrl+Z)", func(): undo_pressed.emit())
	_add_button(bar, "Znovu (Ctrl+Y)", func(): redo_pressed.emit())
	_add_button(bar, "Otočit (R)", func(): rotate_pressed.emit())
	_add_button(bar, "Přehrát", func(): play_pressed.emit())
	_add_button(bar, "Menu", func(): menu_pressed.emit())
	return bar

func _add_button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

# ── Levý panel s paletou ─────────────────────────────────────────────────

func _make_side_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 40)
	scroll.custom_minimum_size = Vector2(200, 560)

	var list := VBoxContainer.new()
	scroll.add_child(list)

	list.add_child(_section_label("Bloky"))
	_add_tool_button(list, "Guma (smazat)", func(): erase_tool_selected.emit())
	for block_type in BLOCK_LABELS.keys():
		_add_tool_button(list, BLOCK_LABELS[block_type],
				func(): block_tool_selected.emit(block_type))

	list.add_child(_section_label("Roboti"))
	for kind in GridTypes.ROBOT_NAMES.keys():
		_add_tool_button(list, GridTypes.robot_name(kind),
				func(): robot_tool_selected.emit(kind))

	list.add_child(_section_label("Předměty"))
	for item_type in ITEM_LABELS.keys():
		_add_tool_button(list, ITEM_LABELS[item_type],
				func(): item_tool_selected.emit(item_type))
	_add_tool_button(list, "Klíč", func(): key_tool_selected.emit())

	return scroll

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label

func _add_tool_button(parent: Control, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_group = _tool_group
	button.pressed.connect(callback)
	parent.add_child(button)

# ── Dialogy ──────────────────────────────────────────────────────────────

func _build_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.current_dir = LEVELS_DIR
	_save_dialog.add_filter("*.ncr", "Level NCR")
	_save_dialog.file_selected.connect(func(path): save_requested.emit(path))
	add_child(_save_dialog)

	_load_dialog = FileDialog.new()
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_load_dialog.current_dir = LEVELS_DIR
	_load_dialog.add_filter("*.ncr", "Level NCR")
	_load_dialog.file_selected.connect(func(path): load_requested.emit(path))
	add_child(_load_dialog)

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Nový level"
	var fields := VBoxContainer.new()
	_new_size_fields = []
	for axis in ["Délka (X)", "Výška (Y)", "Šířka (Z)"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = axis
		label.custom_minimum_size = Vector2(90, 0)
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 64
		spin.value = 8
		row.add_child(label)
		row.add_child(spin)
		fields.add_child(row)
		_new_size_fields.append(spin)
	_new_dialog.add_child(fields)
	_new_dialog.confirmed.connect(func():
		new_level_requested.emit(Vector3i(
			int(_new_size_fields[0].value),
			int(_new_size_fields[1].value),
			int(_new_size_fields[2].value))))
	add_child(_new_dialog)
