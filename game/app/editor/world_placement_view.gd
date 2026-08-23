class_name WorldPlacementView
extends Node3D

## Vykreslení krajiny (LandscapeView) plus editorová kolize navíc, pro
## umístění levelu do světa (docs/import-assets.md §7.3 — "mapa světa").
## Kolize, kterou si tu stavíme, slouží jen raycastu pro klik a vertikální
## snap na povrch, ne herní fyzice. Kolize s jednotlivými objekty krajiny
## (stromy, keře…) záměrně neřešíme — o tu se stará autor sám mimo tenhle
## nástroj.

signal landscape_ready(found: bool)

## Nad terénem, aby deska nebliká (z-fighting) s povrchem krajiny.
const MARKER_Y_OFFSET := 0.05

var _landscape: LandscapeView
var _collider: StaticBody3D
var _marker: MeshInstance3D
var _marker_footprint: Vector2 = Vector2.ONE

func _ready() -> void:
	_build_marker()
	_landscape = LandscapeView.new()
	# Připojit signál PŘED add_child: jakmile je WorldPlacementView ve
	# stromu (a to je, jinak by _ready() neběžel), add_child() rovnou
	# spustí _landscape._ready() a s ním i landscape_ready.emit() — kdyby
	# se connect() volal až po add_child(), signál by proletěl bez
	# posluchače a _collider by se nikdy nepostavil (raycast/klik by pak
	# ticho nenašel nic, viz surface_height/raycast níže).
	_landscape.landscape_ready.connect(_on_landscape_ready)
	add_child(_landscape)

func _on_landscape_ready(found: bool) -> void:
	if found:
		_build_collision()
	landscape_ready.emit(found)

## Trimesh kolize ze všech mesh uzlů krajiny — jen pro editorový raycast
## (klik do scény, vertikální snap), ne pro herní fyziku.
func _build_collision() -> void:
	_collider = StaticBody3D.new()
	add_child(_collider)
	for node in _landscape.instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = mesh_instance.global_transform
		_collider.add_child(collision)

func _build_marker() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.15, 0.15, 0.55)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := PlaneMesh.new()
	mesh.material = material
	_marker = MeshInstance3D.new()
	_marker.mesh = mesh
	_marker.visible = false
	add_child(_marker)
	_apply_marker_size()

## Rozměr půdorysu levelu (X, Z) ve světových jednotkách — deska ho přesně
## kopíruje, aby bylo vidět, jaký prostor level v krajině zabere.
func set_footprint_size(size: Vector2) -> void:
	_marker_footprint = size
	_apply_marker_size()

func _apply_marker_size() -> void:
	if _marker == null:
		return
	(_marker.mesh as PlaneMesh).size = _marker_footprint

## `pos` je pozice rohu levelu (mřížková buňka 0,0,0), stejně jako
## world_position v LevelController.setup_with_simulation — deska proto
## nesedí na `pos` středem, ale je od ní posunutá o půl svého rozměru.
func set_marker_position(pos: Vector3) -> void:
	_marker.visible = true
	_marker.position = pos + Vector3(_marker_footprint.x, 0.0, _marker_footprint.y) * 0.5 \
			+ Vector3(0.0, MARKER_Y_OFFSET, 0.0)

func hide_marker() -> void:
	_marker.visible = false

## Nejbližší průsečík paprsku `from → to` s krajinou, nebo null.
func raycast(from: Vector3, to: Vector3) -> Variant:
	if _collider == null:
		return null
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	return result["position"]

## Výška povrchu (nejvyšší bod krajiny) v daném (x, z), nebo null, když pod
## bodem nic není. Použito pro vertikální snap.
func surface_height(x: float, z: float) -> Variant:
	var hit = raycast(Vector3(x, 1000.0, z), Vector3(x, -1000.0, z))
	if hit == null:
		return null
	return (hit as Vector3).y
