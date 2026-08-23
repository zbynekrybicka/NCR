class_name WorldPlacementController
extends Node3D

## Samostatný režim editoru pro umístění levelu do krajiny (mapa světa,
## docs/import-assets.md §7.3). EditorController do něj na dobu použití
## přepne (skryje mřížkový editor stejně jako pro playtest) a zase se
## vrátí po potvrzení/zrušení — sám o pozici nic neukládá, to dělá
## CampaignMap na úrovni EditorControlleru.
##
## Přibližný střed a rozsah scény krajiny podle
## docs/zadani_krajina_lowpoly_bpy.md §1 (Blender X -45..35, Y -10..185,
## Blender Y dopředu → Godot -Z po exportu) — použito jen jako výchozí
## pohled kamery, než je vybraná konkrétní pozice.
const LANDSCAPE_CENTER := Vector3(0.0, 15.0, -90.0)
const LANDSCAPE_VIEW_DISTANCE := 180.0

signal confirmed(position: Vector3)
signal cancelled

var view: WorldPlacementView
var camera_rig: WorldPlacementCamera
var ui: WorldPlacementUi

var _position: Vector3 = Vector3.ZERO
var _has_position: bool = false

func _ready() -> void:
	view = WorldPlacementView.new()
	add_child(view)

	camera_rig = WorldPlacementCamera.new()
	camera_rig.terrain = view
	add_child(camera_rig)

	ui = WorldPlacementUi.new()
	add_child(ui)
	ui.position_changed.connect(_on_field_position_changed)
	ui.snap_pressed.connect(_on_snap_pressed)
	ui.confirm_pressed.connect(_on_confirm_pressed)
	ui.cancel_pressed.connect(func(): cancelled.emit())

## `initial` je poslední známá pozice levelu (z CampaignMap), `has_position`
## rozlišuje "level tu ještě nikdy nebyl" od "má pozici (0,0,0)".
## `footprint_size` je rozměr levelu (X, Z) v mřížkových buňkách — deska
## umístění ho kopíruje, aby bylo vidět přesný prostor, který level zabere.
func start_at(initial: Vector3, has_position: bool, footprint_size: Vector2) -> void:
	_position = initial
	_has_position = has_position
	view.set_footprint_size(footprint_size)
	if has_position:
		view.set_marker_position(_position)
		camera_rig.center_on(_position, 40.0)
	else:
		view.hide_marker()
		camera_rig.center_on(LANDSCAPE_CENTER, LANDSCAPE_VIEW_DISTANCE)
	ui.set_position_fields(_position, _has_position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_at_mouse()

## Klik rovnou umísťuje na povrch, protože se míří přes raycast do
## krajiny — vertikální snap je tu tedy vlastností samotného umístění, ne
## dodatečný krok. Tlačítko "Snapnout" (viz _on_snap_pressed) slouží k
## dorovnání Y potom, co autor doladil X/Z ručně v polích.
func _pick_at_mouse() -> void:
	var mouse := get_viewport().get_mouse_position()
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * cam.far
	var hit = view.raycast(from, to)
	if hit == null:
		return
	_set_position(hit, true)

func _on_field_position_changed(pos: Vector3) -> void:
	_set_position(pos, true)

func _on_snap_pressed() -> void:
	if not _has_position:
		return
	var height = view.surface_height(_position.x, _position.z)
	if height == null:
		return
	_set_position(Vector3(_position.x, height, _position.z), true)

func _on_confirm_pressed() -> void:
	if not _has_position:
		return
	confirmed.emit(_position)

func _set_position(pos: Vector3, has_position: bool) -> void:
	_position = pos
	_has_position = has_position
	view.set_marker_position(pos)
	ui.set_position_fields(pos, has_position)
	camera_rig.point_at(pos)
