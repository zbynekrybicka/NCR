class_name RobotView
extends Node3D

## Obal robota (import-assets §4.1). Tímhle uzlem hýbe EventAnimator — dává
## mu pozici buňky a yaw; model z Blenderu (`blender/<robot>/`) visí uvnitř
## a o mřížce nic neví. Díky obalu se klipy uvnitř modelu míchají s pohybem
## po mřížce, aniž by o sobě navzájem věděly.
##
## Chybějící `.glb` NENÍ chyba: použije se dosavadní barevná krychle s nosem
## (§2.4 — každý model má fallback, aby šly assety přidávat po jednom).

const MODEL_PATHS := {
	GridTypes.RobotKind.HAN: "res://assets/robots/han.glb",
	GridTypes.RobotKind.DUL: "res://assets/robots/dul.glb",
	GridTypes.RobotKind.SET: "res://assets/robots/set.glb",
	GridTypes.RobotKind.NET: "res://assets/robots/net.glb",
	GridTypes.RobotKind.DA: "res://assets/robots/da.glb",
	GridTypes.RobotKind.YEO: "res://assets/robots/yeo.glb",
	GridTypes.RobotKind.IL: "res://assets/robots/il.glb",
}

## Klipy, které u robota běží pořád (vrtule Da). Nepatří do fronty událostí
## a nesmí se roztahovat přes `speed_scale` (§6.3) — proto se pouští zvlášť
## a v přirozeném tempu. Pořadí je pořadí priority.
const LOOP_CLIPS := ["idle", "rotors"]

static var _scene_cache: Dictionary = {}   # cesta -> PackedScene | null

var kind: int = -1

var _player: AnimationPlayer = null
var _loop_clip: String = ""
var _action_clip: String = ""

## `color` se použije jen pro fallback krychli, aby RobotView nemusel sahat
## do WorldView (a nevznikl kruhový odkaz mezi třídami).
static func create(p_kind: int, color: Color) -> RobotView:
	var view := RobotView.new()
	view.kind = p_kind
	view.name = "Robot_%s" % GridTypes.robot_name(p_kind)
	var model := _instantiate_model(p_kind)
	if model == null:
		view.add_child(_placeholder(color))
	else:
		view.add_child(model)
		view._setup_animation(model)
	return view

## Zahraje první klip ze seznamu, který model doopravdy má, a roztáhne ho na
## dobu události (§6.3 — autorita je tabulka časů, ne délka klipu v Blenderu).
## Když žádný z klipů neexistuje, uzel se prostě jen posune.
func play_action(clips: PackedStringArray, duration: float) -> void:
	if _player == null:
		return
	var clip := ""
	for candidate in clips:
		if _player.has_animation(candidate):
			clip = candidate
			break
	if clip == "":
		return
	var length: float = _player.get_animation(clip).length
	_player.speed_scale = length / maxf(duration, 0.001)
	_player.play(clip)
	_action_clip = clip

## Koncová póza akce jednou operací (§6.6, pravidlo 3) — po přeskočení
## animace musí scéna odpovídat stavu, ne doběhnout „časem".
func settle() -> void:
	if _player == null or _action_clip == "":
		return
	_player.seek(_player.get_animation(_action_clip).length, true)
	_play_loop()

func _setup_animation(model: Node) -> void:
	for node in model.find_children("*", "AnimationPlayer", true, false):
		_player = node
		break
	if _player == null:
		return
	for clip_name in LOOP_CLIPS:
		if _player.has_animation(clip_name):
			_loop_clip = clip_name
			# Smyčku zapínáme v kódu: v .glb žádný příznak opakování není a
			# ruční nastavení v .import by se ztratilo při reexportu modelu.
			_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
			break
	_player.animation_finished.connect(_on_animation_finished)
	_play_loop()

func _on_animation_finished(finished_clip: StringName) -> void:
	if finished_clip == _loop_clip:
		return
	_play_loop()

func _play_loop() -> void:
	_action_clip = ""
	if _player == null:
		return
	_player.speed_scale = 1.0
	if _loop_clip == "":
		return   # robot bez smyčky zůstane stát v koncové póze klipu
	_player.play(_loop_clip)

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

## Dosavadní placeholder: krychle s „nosem" ve směru pohledu (§20.1).
static func _placeholder(color: Color) -> Node3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.6, 0.6)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = "Placeholder"
	node.mesh = mesh
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.15, 0.15, 0.3)
	nose_mesh.material = material
	var nose := MeshInstance3D.new()
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0, -0.4)
	node.add_child(nose)
	return node
