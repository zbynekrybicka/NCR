class_name IntroTextOverlay
extends CanvasLayer

## Úvodní textová zpráva levelu (§2.1.1) — prostý text zacentrovaný na
## poloprůsvitném pozadí s černým rámem, zobrazený po příjezdu kamery na
## začátku levelu. Odkliknutelná klávesou Enter nebo tlačítkem „Zavřít";
## LevelController po dobu zobrazení drží vstup uzamčený stejně jako během
## intro přeletu, takže tenhle uzel si sám hlídá jen svoje dvě zavírací akce.

signal closed

const BORDER_WIDTH := 5
const PANEL_MIN_WIDTH := 520

var _label: Label
var _close_button: Button

func _ready() -> void:
	layer = 50 # nad HUD i 3D scénou, ale to na pořadí unhandled_input nemá vliv

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_label = Label.new()
	_label.custom_minimum_size = Vector2(PANEL_MIN_WIDTH - 48, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label)

	_close_button = Button.new()
	_close_button.text = "Zavřít"
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(_close)
	vbox.add_child(_close_button)

func show_text(text: String) -> void:
	_label.text = text
	_close_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_close()

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.border_width_left = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = Color.BLACK
	return style

func _close() -> void:
	closed.emit()
