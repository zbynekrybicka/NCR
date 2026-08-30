class_name WorldPlacementUi
extends CanvasLayer

## Ovládací panel pro umístění levelu do krajiny (docs/import-assets.md
## §7.3). Neřeší kde přesně level leží ani jak se to ukládá — jen sesbírá
## vstup a pošle ho ven signálem, o zbytek se stará
## WorldPlacementController (stejné rozdělení práce jako u EditorUi).

signal position_changed(position: Vector3)
signal snap_pressed
signal confirm_pressed
signal cancel_pressed
signal camera_position_requested

var _x_spin: SpinBox
var _y_spin: SpinBox
var _z_spin: SpinBox
var _status_label: Label
var _camera_status_label: Label
var _confirm_button: Button
var _snap_button: Button
var _camera_button: Button

var _updating_fields: bool = false

func _ready() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)

	var title := Label.new()
	title.text = "Umístění levelu ve světě"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	var hint := Label.new()
	hint.text = "Klikni do krajiny, nebo zadej souřadnice ručně. " \
			+ "Otáčení kamery pravým tlačítkem, posun WASDQE, zoom kolečkem."
	panel.add_child(hint)

	var coords := HBoxContainer.new()
	_x_spin = _make_axis_spin(coords, "X")
	_y_spin = _make_axis_spin(coords, "Y")
	_z_spin = _make_axis_spin(coords, "Z")
	panel.add_child(coords)

	var buttons := HBoxContainer.new()
	_snap_button = _add_button(buttons, "Snapnout na povrch (Y)", func(): snap_pressed.emit())
	_confirm_button = _add_button(buttons, "Potvrdit", func(): confirm_pressed.emit())
	_add_button(buttons, "Zrušit", func(): cancel_pressed.emit())
	panel.add_child(buttons)

	_status_label = Label.new()
	panel.add_child(_status_label)

	var camera_hint := Label.new()
	camera_hint.text = "Nastav pohled kamery (jako výše — pravé tlačítko, WASDQE, kolečko) " \
			+ "a ulož ho jako úvodní přelet: takhle uvidíš rovnou, jestli cesta neprochází " \
			+ "domem nebo stromem."
	panel.add_child(camera_hint)

	var camera_buttons := HBoxContainer.new()
	_camera_button = _add_button(camera_buttons, "Uložit pozici kamery",
			func(): camera_position_requested.emit())
	panel.add_child(camera_buttons)

	_camera_status_label = Label.new()
	panel.add_child(_camera_status_label)

	set_position_fields(Vector3.ZERO, false)

func _make_axis_spin(parent: Control, axis_label: String) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = axis_label
	label.custom_minimum_size = Vector2(16, 0)
	var spin := SpinBox.new()
	spin.min_value = -100000.0
	spin.max_value = 100000.0
	spin.step = 0.05
	spin.custom_minimum_size = Vector2(90, 0)
	spin.value_changed.connect(func(_v): _on_field_changed())
	row.add_child(label)
	row.add_child(spin)
	parent.add_child(row)
	return spin

func _add_button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _on_field_changed() -> void:
	if _updating_fields:
		return
	position_changed.emit(current_position())

func current_position() -> Vector3:
	return Vector3(_x_spin.value, _y_spin.value, _z_spin.value)

## Nastaví pole bez vyvolání position_changed (volá to controller, když
## pozici mění on sám — klikem nebo snapem).
func set_position_fields(pos: Vector3, has_position: bool) -> void:
	_updating_fields = true
	_x_spin.value = pos.x
	_y_spin.value = pos.y
	_z_spin.value = pos.z
	_updating_fields = false
	_confirm_button.disabled = not has_position
	_snap_button.disabled = not has_position
	_camera_button.disabled = not has_position
	_status_label.text = ("Pozice: %s" % pos) if has_position \
			else "Level zatím nemá místo ve světě — klikni do krajiny."

## Zpráva k uložení pozice kamery (viz camera_position_requested) — odděleně
## od _status_label, který hlásí stav umístění levelu samotného.
func set_camera_status(text: String) -> void:
	_camera_status_label.text = text
