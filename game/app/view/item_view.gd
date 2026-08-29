class_name ItemView
extends Node3D

## Plovoucí předmět na zemi — volně ležící klíč, kanystr nebo service kit
## (import-assets §4.2). Vnější uzel (tenhle) drží POZICI V MŘÍŽCE stejně
## jako dřív holý `MeshInstance3D` — hýbe jím `WorldView`/`EventAnimator`
## (`item_node()`/`key_node()` tweenují jeho `.position` při přejezdu
## plošiny, `event_animator.gd:283`). Vnitřní uzel `_float` dělá idle pohyb
## (otáčení kolem svislé osy + pomalé pohupování nahoru/dolů, zadání) — model
## uvnitř o pohybu po mřížce neví, stejný princip odstínění jako u RobotView.
##
## Chybějící `.glb` NENÍ chyba: použije se dosavadní placeholder (koule/
## torus, přesunuté sem z `world_view.gd`), ať se otáčí a pohupuje stejně
## jako reálný model (§2.4 — každý model má fallback).

enum Kind { KEY, FUEL, SERVICE_KIT }

const MODEL_PATHS := {
	Kind.KEY: "res://assets/items/key.glb",
	Kind.FUEL: "res://assets/items/canister.glb",
	Kind.SERVICE_KIT: "res://assets/items/service_kit.glb",
}

const PLACEHOLDER_COLORS := {
	Kind.KEY: Color(1.0, 0.85, 0.2),
	Kind.FUEL: Color(0.9, 0.5, 0.1),
	Kind.SERVICE_KIT: Color(0.3, 0.8, 0.9),
}

const SPIN_SPEED := 0.9          # rad/s kolem svislé osy
const BOB_AMPLITUDE := 0.05      # kostky nahoru/dolů od klidové polohy
const BOB_PERIOD := 2.4          # s, celý cyklus nahoru-dolů-nahoru

static var _scene_cache: Dictionary = {}   # cesta -> PackedScene | null

var kind: int = -1

var _float: Node3D
var _phase: float = 0.0

## Náhodná počáteční fáze (`randf() * TAU`), ať několik předmětů v levelu
## nepulzuje synchronně — čistě kosmetický detail idle animace.
static func create(p_kind: int) -> ItemView:
	var view := ItemView.new()
	view.kind = p_kind
	view.name = "Item_%s" % ["key", "fuel", "service_kit"][p_kind]
	view._phase = randf() * TAU

	view._float = Node3D.new()
	view._float.name = "Float"
	view.add_child(view._float)

	var model := _instantiate_model(p_kind)
	view._float.add_child(model if model != null else _placeholder(p_kind))

	return view

static func for_item_type(item_type: int) -> ItemView:
	return create(kind_for_item_type(item_type))

## Sdílené s `WorldView.refresh_items()`, aby poznal, jestli se `GridTypes.ItemType`
## na dané buňce oproti dřívějšku změnil, nebo jestli jde nechat stávající uzel
## (a jeho idle animaci) na pokoji.
static func kind_for_item_type(item_type: int) -> int:
	return Kind.FUEL if item_type == GridTypes.ItemType.FUEL else Kind.SERVICE_KIT

static func for_key() -> ItemView:
	return create(Kind.KEY)

func _process(delta: float) -> void:
	_phase += delta
	_float.rotation.y += SPIN_SPEED * delta
	_float.position.y = BOB_AMPLITUDE * sin(_phase * TAU / BOB_PERIOD)

static func _instantiate_model(p_kind: int) -> Node3D:
	var path: String = MODEL_PATHS.get(p_kind, "")
	if path == "":
		return null
	if not _scene_cache.has(path):
		# `load()` na GLB není zadarmo a scéna se staví znovu při každém
		# restartu levelu (level_controller.gd), proto cache.
		_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scene_cache[path]
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model != null:
		model.name = "Model"
	return model

## Dosavadní placeholder z `world_view.gd` (koule pro kanystr/service kit,
## torus pro klíč) — jen přestěhovaný sem, ať ho `ItemView` může otáčet a
## pohupovat stejně jako reálný model.
static func _placeholder(p_kind: int) -> Node3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLORS[p_kind]
	var node := MeshInstance3D.new()
	node.name = "Placeholder"
	if p_kind == Kind.KEY:
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.1
		mesh.outer_radius = 0.2
		mesh.material = material
		node.mesh = mesh
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		mesh.material = material
		node.mesh = mesh
	return node
