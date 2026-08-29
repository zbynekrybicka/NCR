class_name DeviceView
extends Node3D

## Obal elektrického zařízení (import-assets §4.3). Model z Blenderu
## (`blender/devices/`) visí uvnitř; uzel sám o mřížce neví — pozici a
## natočení (podle `device.access_direction`, stejně jako `robot.facing`
## u RobotView) mu dává `WorldView._build_devices()`.
##
## Chybějící `.glb` NENÍ chyba: použije se placeholder se stejnou uzlovou
## strukturou (Lamp/Damage/SparkAnchor/Lever), aby stav šel zobrazit i bez
## reálného modelu (§2.4 import-assets — každý model má fallback).

const MODEL_PATHS := {
	GridTypes.DeviceKind.POWER_CABINET: "res://assets/devices/cabinet.glb",
	GridTypes.DeviceKind.CONTROL_UNIT: "res://assets/devices/control_unit.glb",
}

## Musí sedět s `devices_spec.LEVER_POSE_DEG` v Blenderu — dvě polohy páky,
## aby šel přepínač vizuálně rozlišit (viz zadání).
const LEVER_POSE_DEG := [-28.0, 28.0]

const LAMP_ON_COLOR := Color(0.25, 1.0, 0.35)
const LAMP_BROKEN_COLOR := Color(1.0, 0.2, 0.15)
const LAMP_OFF_COLOR := Color(0.12, 0.12, 0.12)

const SPARK_COLOR := Color(1.0, 0.80, 0.25)
const SPARK_COUNT := 12
const SPARK_LIFETIME := 0.35

static var _scene_cache: Dictionary = {}   # cesta -> PackedScene | null
static var _spark_mesh: QuadMesh

var kind: int = -1

var _lamp_material: StandardMaterial3D
var _damage_node: Node3D
var _spark_anchor: Node3D
var _spark_particles: GPUParticles3D
var _lever_node: Node3D

static func create(p_kind: int, color: Color) -> DeviceView:
	var view := DeviceView.new()
	view.kind = p_kind
	view.name = "Device_%s" % ("cabinet" if p_kind == GridTypes.DeviceKind.POWER_CABINET
			else "control_unit")
	var model := _instantiate_model(p_kind)
	if model == null:
		model = view._placeholder(p_kind, color)
	view.add_child(model)
	view._bind_model(model)
	return view

## Napojí se na pojmenované uzly modelu (skutečného i placeholderu) — funguje
## stejně pro oba, takže stav se dá zobrazit i bez reálného GLB (§2.4). Hledá
## se podle koncovky jména (`*Lamp` apod.), protože reálný model má uzly
## prefixované (`CABINET_Lamp`, `CTRL_Lever` — `blender/devices/common.py`
## kvůli `nc.purge()` potřebuje jednotný prefix na celý díl).
func _bind_model(model: Node) -> void:
	var lamp_mesh := model.find_child("*Lamp", true, false) as MeshInstance3D
	if lamp_mesh != null:
		_lamp_material = lamp_mesh.get_surface_override_material(0) as StandardMaterial3D
		if _lamp_material == null:
			var base: Material = null
			if lamp_mesh.mesh != null and lamp_mesh.mesh.get_surface_count() > 0:
				base = lamp_mesh.mesh.surface_get_material(0)
			_lamp_material = base.duplicate() if base != null else StandardMaterial3D.new()
			_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			lamp_mesh.set_surface_override_material(0, _lamp_material)
	_damage_node = model.find_child("*Damage", true, false) as Node3D
	_spark_anchor = model.find_child("*SparkAnchor", true, false) as Node3D
	_lever_node = model.find_child("*Lever", true, false) as Node3D

## POWER_CABINET (`device.is_broken`, `device.is_on` — §13.1). Kontrolka
## svítí zeleně pod napětím, červeně nakrátko při poruše (i bez napětí to
## hráči řekne "tady je problém"); jiskry (dynamické, ne z modelu) běží,
## dokud je skříň rozbitá.
func update_cabinet(is_broken: bool, is_on: bool) -> void:
	if _damage_node != null:
		_damage_node.visible = is_broken
	if is_broken:
		_set_lamp(true, LAMP_BROKEN_COLOR)
	else:
		_set_lamp(is_on, LAMP_ON_COLOR)
	_set_sparks(is_broken)

## CONTROL_UNIT — `pose` je 0/1 stav napojeného mechanismu (plošina
## `current_pose`, čerpadlo `current_direction`; `WorldView._control_unit_pose()`),
## ne vlastní stav zařízení (to CONTROL_UNIT nemá — §13.1: sepnutí je
## jednorázové). Bez napojení zůstává páka v poloze 0.
func update_control_unit(pose: int) -> void:
	if _lever_node == null:
		return
	var deg: float = LEVER_POSE_DEG[1] if pose == 1 else LEVER_POSE_DEG[0]
	_lever_node.rotation_degrees = Vector3(deg, 0.0, 0.0)

func _set_lamp(lit: bool, color: Color) -> void:
	if _lamp_material == null:
		return
	_lamp_material.albedo_color = color if lit else LAMP_OFF_COLOR
	_lamp_material.emission_enabled = lit
	if lit:
		_lamp_material.emission = color
		_lamp_material.emission_energy_multiplier = 3.0

func _set_sparks(active: bool) -> void:
	if active and _spark_particles == null:
		_spark_particles = _make_sparks()
		var parent: Node3D = _spark_anchor if _spark_anchor != null else self
		parent.add_child(_spark_particles)
	if _spark_particles != null:
		_spark_particles.emitting = active

## Krátká sprška jisker padající od kotvy dolů — stejný princip jako
## `WorldView`'s částice cíle (aditivní billboard + `ParticleProcessMaterial`),
## jen s gravitací a náhodným rozletem místo stoupání vzhůru.
func _make_sparks() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = SPARK_COUNT
	particles.lifetime = SPARK_LIFETIME
	particles.explosiveness = 0.15
	particles.randomness = 0.4
	particles.draw_pass_1 = _spark_draw_mesh()
	particles.process_material = _spark_process_material()
	return particles

func _spark_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, -1)   # lokální -Z = "dopředu" (§4.1 import-assets), od dvířek ven
	material.spread = 55.0
	material.gravity = Vector3(0, -2.4, 0)
	material.initial_velocity_min = 0.35
	material.initial_velocity_max = 0.9
	material.scale_min = 0.6
	material.scale_max = 1.3
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(1, 0.6, 0.1, 0.6), Color(0.4, 0.1, 0, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	material.color_ramp = fade_texture
	return material

func _spark_draw_mesh() -> QuadMesh:
	if _spark_mesh != null:
		return _spark_mesh
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = SPARK_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_spark_mesh = mesh
	return mesh

static func _instantiate_model(p_kind: int) -> Node3D:
	var path: String = MODEL_PATHS.get(p_kind, "")
	if path == "":
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scene_cache[path]
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model != null:
		model.name = "Model"
	return model

## Placeholder krychle se stejnou uzlovou strukturou jako reálný model
## (Lamp/Damage/SparkAnchor/Lever), ať jde stav zobrazit i bez GLB.
func _placeholder(p_kind: int, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Placeholder"

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.9, 1.0)
	mesh.material = material
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0, 0, 0)
	root.add_child(body)

	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.05
	lamp_mesh.height = 0.10
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0.0, 0.42, -0.46)
	root.add_child(lamp)

	var damage := Node3D.new()
	damage.name = "Damage"
	damage.visible = false
	damage.position = Vector3(0.0, 0.0, -0.46)
	var damage_mesh := BoxMesh.new()
	damage_mesh.size = Vector3(0.5, 0.06, 0.06)
	var damage_material := StandardMaterial3D.new()
	damage_material.albedo_color = Color(0.05, 0.05, 0.05)
	damage_mesh.material = damage_material
	var damage_body := MeshInstance3D.new()
	damage_body.mesh = damage_mesh
	damage.add_child(damage_body)
	root.add_child(damage)

	var spark_anchor := Node3D.new()
	spark_anchor.name = "SparkAnchor"
	spark_anchor.position = Vector3(0.0, 0.0, -0.5)
	root.add_child(spark_anchor)

	if p_kind == GridTypes.DeviceKind.CONTROL_UNIT:
		var lever := Node3D.new()
		lever.name = "Lever"
		lever.position = Vector3(0.0, 0.0, -0.48)
		var lever_mesh := BoxMesh.new()
		lever_mesh.size = Vector3(0.05, 0.05, 0.18)
		var lever_material := StandardMaterial3D.new()
		lever_material.albedo_color = Color(0.6, 0.1, 0.1)
		lever_mesh.material = lever_material
		var lever_body := MeshInstance3D.new()
		lever_body.mesh = lever_mesh
		lever_body.position = Vector3(0, 0, 0.09)
		lever.add_child(lever_body)
		root.add_child(lever)

	return root
