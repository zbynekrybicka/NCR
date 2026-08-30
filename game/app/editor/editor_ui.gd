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
signal world_placement_requested
signal intro_text_edit_requested
signal intro_text_changed(text: String)

# Mechanismy (§13): zařízení, nádrže, plošiny, čerpadla.
signal device_tool_selected(kind: int)
signal device_settings_changed(control_mode: int, is_broken: bool)
signal reservoir_tool_selected
signal reservoir_settings_changed(volume_units: int, unlimited: bool)
signal platform_tool_selected
signal platform_selection_cleared
signal platform_create_requested(pose_b: Vector3i, weight_limit: int, cabinets: Array,
		control_units: Array)
signal pump_create_requested(reservoir_a: int, reservoir_b: int, cabinets: Array,
		control_unit: int, bidirectional: bool, default_direction: int)
signal mechanism_remove_requested(kind: String, index: int)

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

const DEVICE_LABELS := {
	GridTypes.DeviceKind.POWER_CABINET: "Elektrická skříň",
	GridTypes.DeviceKind.CONTROL_UNIT: "Řídicí jednotka",
}

const CONTROL_MODE_LABELS := {
	GridTypes.ControlMode.BUTTON: "tlačítko",
	GridTypes.ControlMode.SWITCH: "přepínač",
}

const DIRECTION_LABELS := {
	GridTypes.Direction.NORTH: "sever",
	GridTypes.Direction.EAST: "východ",
	GridTypes.Direction.SOUTH: "jih",
	GridTypes.Direction.WEST: "západ",
	GridTypes.Direction.UP: "nahoru",
	GridTypes.Direction.DOWN: "dolů",
}

var _status_label: Label
var _tool_label: Label
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _new_dialog: ConfirmationDialog
var _new_size_fields: Array = []
var _tool_group := ButtonGroup.new()

# Mechanismy
var _mechanisms: Dictionary = {}      # data z controlleru, viz set_mechanism_data
var _control_mode_option: OptionButton
var _broken_check: CheckBox
var _volume_spin: SpinBox
var _unlimited_check: CheckBox
var _selection_label: Label
var _platform_dialog: ConfirmationDialog
var _platform_offset_fields: Array = []
var _platform_limit_spin: SpinBox
var _platform_cabinets: ItemList
var _platform_units: ItemList
var _pump_dialog: ConfirmationDialog
var _pump_source: OptionButton
var _pump_target: OptionButton
var _pump_bidirectional: CheckBox
var _pump_cabinets: ItemList
var _pump_unit: OptionButton
var _list_dialog: AcceptDialog
var _list_content: VBoxContainer
var _intro_text_dialog: ConfirmationDialog
var _intro_text_edit: TextEdit

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
	_add_button(bar, "Umístit ve světě…", func(): world_placement_requested.emit())
	_add_button(bar, "Úvodní text…", func(): intro_text_edit_requested.emit())
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

	_build_mechanism_section(list)
	return scroll

## Mechanismy (§13). Zařízení se kladou po jedné buňce, nádrž se zakládá
## kliknutím do uzavřené dutiny, plošina se skládá z vybraných zdí, čerpadlo
## propojuje dvě nádrže.
func _build_mechanism_section(list: VBoxContainer) -> void:
	list.add_child(_section_label("Zařízení"))
	for kind in DEVICE_LABELS.keys():
		_add_tool_button(list, DEVICE_LABELS[kind],
				func(): device_tool_selected.emit(kind))

	_control_mode_option = OptionButton.new()
	for mode in CONTROL_MODE_LABELS.keys():
		_control_mode_option.add_item(String(CONTROL_MODE_LABELS[mode]), mode)
	_control_mode_option.item_selected.connect(func(_i): _emit_device_settings())
	list.add_child(_control_mode_option)

	_broken_check = CheckBox.new()
	_broken_check.text = "Rozbité (nutná oprava)"
	_broken_check.toggled.connect(func(_on): _emit_device_settings())
	list.add_child(_broken_check)

	list.add_child(_section_label("Nádrž"))
	_add_tool_button(list, "Nádrž (klik do dutiny)", func(): reservoir_tool_selected.emit())
	var volume_row := HBoxContainer.new()
	var volume_label := Label.new()
	volume_label.text = "Voda"
	volume_label.custom_minimum_size = Vector2(60, 0)
	_volume_spin = SpinBox.new()
	_volume_spin.min_value = 0
	_volume_spin.max_value = 9999
	_volume_spin.tooltip_text = "Počáteční objem v půlkostkách (1 kostka = 2)"
	_volume_spin.value_changed.connect(func(_v): _emit_reservoir_settings())
	volume_row.add_child(volume_label)
	volume_row.add_child(_volume_spin)
	list.add_child(volume_row)
	_unlimited_check = CheckBox.new()
	_unlimited_check.text = "Neomezená"
	_unlimited_check.toggled.connect(func(_on): _emit_reservoir_settings())
	list.add_child(_unlimited_check)

	list.add_child(_section_label("Plošina a čerpadlo"))
	_add_tool_button(list, "Výběr buněk plošiny", func(): platform_tool_selected.emit())
	_selection_label = Label.new()
	_selection_label.text = "Vybráno buněk: 0"
	list.add_child(_selection_label)
	_add_button(list, "Zrušit výběr", func(): platform_selection_cleared.emit())
	_add_button(list, "Vytvořit plošinu…", _open_platform_dialog)
	_add_button(list, "Vytvořit čerpadlo…", _open_pump_dialog)
	_add_button(list, "Seznam mechanismů…", _open_list_dialog)

func _emit_device_settings() -> void:
	device_settings_changed.emit(_control_mode_option.get_selected_id(),
			_broken_check.button_pressed)

func _emit_reservoir_settings() -> void:
	reservoir_settings_changed.emit(int(_volume_spin.value), _unlimited_check.button_pressed)

## Data mechanismů z controlleru — UI je jen zobrazuje, žádná pravidla nezná.
func set_mechanism_data(data: Dictionary) -> void:
	_mechanisms = data
	if _selection_label != null:
		_selection_label.text = "Vybráno buněk: %d" % int(data.get("platform_selection", 0))

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

	_build_platform_dialog()
	_build_pump_dialog()
	_build_list_dialog()
	_build_intro_text_dialog()

# ── Dialogy mechanismů ───────────────────────────────────────────────────

## Plošina: druhá poloha je libovolný posun vůči první (vodorovný, svislý
## i diagonální, §13.2), hmotnostní limit je spouštěcí práh.
func _build_platform_dialog() -> void:
	_platform_dialog = ConfirmationDialog.new()
	_platform_dialog.title = "Nová transportní plošina"
	var fields := VBoxContainer.new()

	fields.add_child(_section_label("Posun druhé polohy"))
	_platform_offset_fields = []
	for axis in ["Posun X", "Posun Y", "Posun Z"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = axis
		label.custom_minimum_size = Vector2(90, 0)
		var spin := SpinBox.new()
		spin.min_value = -64
		spin.max_value = 64
		spin.value = 0
		row.add_child(label)
		row.add_child(spin)
		fields.add_child(row)
		_platform_offset_fields.append(spin)

	var limit_row := HBoxContainer.new()
	var limit_label := Label.new()
	limit_label.text = "Spouštěcí práh"
	limit_label.custom_minimum_size = Vector2(90, 0)
	_platform_limit_spin = SpinBox.new()
	_platform_limit_spin.min_value = 0
	_platform_limit_spin.max_value = 99
	_platform_limit_spin.tooltip_text = \
			"Minimální hmotnost na plošině pro rozjezd; u automatické plošiny aspoň 1"
	limit_row.add_child(limit_label)
	limit_row.add_child(_platform_limit_spin)
	fields.add_child(limit_row)

	fields.add_child(_section_label("Elektrické skříně (nutná aspoň jedna)"))
	_platform_cabinets = _make_multi_list()
	fields.add_child(_platform_cabinets)
	fields.add_child(_section_label("Řídicí jednotky (žádná = automatická)"))
	_platform_units = _make_multi_list()
	fields.add_child(_platform_units)

	_platform_dialog.add_child(fields)
	_platform_dialog.confirmed.connect(func():
		platform_create_requested.emit(
			Vector3i(int(_platform_offset_fields[0].value),
					int(_platform_offset_fields[1].value),
					int(_platform_offset_fields[2].value)),
			int(_platform_limit_spin.value),
			_selected_indices(_platform_cabinets),
			_selected_indices(_platform_units)))
	add_child(_platform_dialog)

func _open_platform_dialog() -> void:
	_fill_list(_platform_cabinets, _mechanisms.get("cabinets", []))
	_fill_list(_platform_units, _mechanisms.get("control_units", []))
	_platform_dialog.popup_centered()

## Čerpadlo: dvě nádrže, směr, skříně a případná řídicí jednotka (§13.3).
func _build_pump_dialog() -> void:
	_pump_dialog = ConfirmationDialog.new()
	_pump_dialog.title = "Nové čerpadlo"
	var fields := VBoxContainer.new()

	_pump_source = OptionButton.new()
	_pump_target = OptionButton.new()
	fields.add_child(_section_label("Zdrojová nádrž (výchozí směr)"))
	fields.add_child(_pump_source)
	fields.add_child(_section_label("Cílová nádrž"))
	fields.add_child(_pump_target)

	_pump_bidirectional = CheckBox.new()
	_pump_bidirectional.text = "Obousměrné (přepínač střídá směr)"
	fields.add_child(_pump_bidirectional)

	fields.add_child(_section_label("Elektrické skříně (nutná aspoň jedna)"))
	_pump_cabinets = _make_multi_list()
	fields.add_child(_pump_cabinets)
	fields.add_child(_section_label("Řídicí jednotka"))
	_pump_unit = OptionButton.new()
	fields.add_child(_pump_unit)

	_pump_dialog.add_child(fields)
	_pump_dialog.confirmed.connect(func():
		var source := _selected_index(_pump_source)
		var target := _selected_index(_pump_target)
		pump_create_requested.emit(source, target, _selected_indices(_pump_cabinets),
				_selected_index(_pump_unit), _pump_bidirectional.button_pressed, 0))
	add_child(_pump_dialog)

func _open_pump_dialog() -> void:
	var reservoirs: Array = _mechanisms.get("reservoirs", [])
	_fill_options(_pump_source, reservoirs)
	_fill_options(_pump_target, reservoirs)
	if _pump_target.item_count > 1:
		_pump_target.select(1)
	_fill_list(_pump_cabinets, _mechanisms.get("cabinets", []))
	_pump_unit.clear()
	# „Žádná" je platná volba — čerpadlo bez řídicí jednotky je automatické
	# (§13.3). Index se nese v metadatech, ne v id položky: OptionButton
	# záporné id zahodí a nahradí ho indexem položky, takže by se z volby
	# „žádná" stal odkaz na zařízení 0 a validace by hlásila falešnou chybu.
	_pump_unit.add_item("žádná (automatické)")
	_pump_unit.set_item_metadata(0, -1)
	for entry in _mechanisms.get("control_units", []):
		_pump_unit.add_item(String(entry[1]))
		_pump_unit.set_item_metadata(_pump_unit.item_count - 1, int(entry[0]))
	_pump_dialog.popup_centered()

## Přehled všech mechanismů s možností je smazat.
func _build_list_dialog() -> void:
	_list_dialog = AcceptDialog.new()
	_list_dialog.title = "Mechanismy v levelu"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 360)
	_list_content = VBoxContainer.new()
	scroll.add_child(_list_content)
	_list_dialog.add_child(scroll)
	add_child(_list_dialog)

func _open_list_dialog() -> void:
	for child in _list_content.get_children():
		child.queue_free()
	_add_list_group("Zařízení", "device", _mechanisms.get("devices", []))
	_add_list_group("Nádrže", "reservoir", _mechanisms.get("reservoirs", []))
	_add_list_group("Plošiny", "platform", _mechanisms.get("platforms", []))
	_add_list_group("Čerpadla", "pump", _mechanisms.get("pumps", []))
	_list_dialog.popup_centered()

func _add_list_group(title: String, kind: String, entries: Array) -> void:
	_list_content.add_child(_section_label(title))
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "— žádné —"
		_list_content.add_child(empty)
		return
	for entry in entries:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(entry[1])
		label.custom_minimum_size = Vector2(420, 0)
		row.add_child(label)
		var index := int(entry[0])
		_add_button(row, "Smazat", func():
			mechanism_remove_requested.emit(kind, index)
			_list_dialog.hide())
		_list_content.add_child(row)

## Úvodní textová zpráva (§2.1.1, §2.2.1): prostý text, odstavce oddělené
## prázdným řádkem, bez dalšího formátování — proto obyčejný TextEdit, ne
## RichTextLabel/editor s vyznačováním.
func _build_intro_text_dialog() -> void:
	_intro_text_dialog = ConfirmationDialog.new()
	_intro_text_dialog.title = "Úvodní textová zpráva"
	_intro_text_dialog.ok_button_text = "Uložit"
	_intro_text_edit = TextEdit.new()
	_intro_text_edit.custom_minimum_size = Vector2(480, 320)
	_intro_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_intro_text_edit.placeholder_text = "Text zobrazený hráči po příjezdu kamery na začátku " \
			+ "levelu. Odstavce odděl prázdným řádkem."
	_intro_text_dialog.add_child(_intro_text_edit)
	_intro_text_dialog.confirmed.connect(func(): intro_text_changed.emit(_intro_text_edit.text))
	add_child(_intro_text_dialog)

func open_intro_text_dialog(text: String) -> void:
	_intro_text_edit.text = text
	_intro_text_dialog.popup_centered(Vector2(520, 380))

func _make_multi_list() -> ItemList:
	var list := ItemList.new()
	list.select_mode = ItemList.SELECT_MULTI
	list.custom_minimum_size = Vector2(420, 90)
	return list

func _fill_list(list: ItemList, entries: Array) -> void:
	list.clear()
	for entry in entries:
		var item := list.add_item(String(entry[1]))
		list.set_item_metadata(item, int(entry[0]))

func _fill_options(options: OptionButton, entries: Array) -> void:
	options.clear()
	for entry in entries:
		options.add_item(String(entry[1]))
		options.set_item_metadata(options.item_count - 1, int(entry[0]))

## Index mechanismu za vybranou položkou; -1, když není z čeho vybírat.
func _selected_index(options: OptionButton) -> int:
	if options.selected < 0:
		return -1
	return int(options.get_item_metadata(options.selected))

func _selected_indices(list: ItemList) -> Array:
	var out: Array = []
	for item in list.get_selected_items():
		out.append(int(list.get_item_metadata(item)))
	return out
