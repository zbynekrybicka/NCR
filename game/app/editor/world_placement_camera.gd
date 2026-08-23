class_name WorldPlacementCamera
extends Node3D

## Volná orbitální kamera pro umístění levelu do krajiny. Stejný ovládací
## vzor jako EditorCamera (pravé tlačítko = orbit, kolečko = zoom, WASDQE =
## posun), jen s rozsahy odpovídajícími krajině místo jedné buňky mřížky —
## krajina je scéna ~200 m dlouhá (docs/zadani_krajina_lowpoly_bpy.md §1),
## ne pár kostek.
##
## Omezení pitche samo o sobě nestačí — orbit má nulovou vodorovnou
## rezervu jen vůči SVÉMU cíli (`target`), ale ten se dá posunout pod
## povrch klidně svislým posunem (Q), nebo prostým odjezdem nad prudší
## kopec, aniž by se pitch vůbec změnil. Kamera proto navíc každý snímek
## přisvorkuje jak cíl, tak vlastní pozici k výšce terénu pod nimi
## (viz `terrain`, `_clamp_above_ground`) — to je skutečné omezení „pod
## scénu se nedostaneš", pitch je jen ovládací pomůcka navrch.

const MOUSE_SENSITIVITY := 0.005
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 400.0
const PAN_SPEED := 40.0
## Orbit kolem osy Y (yaw) volný, kolem Z se nerotuje; kolem X (pitch)
## nejvýš 90° od pohledu shora (MIN_PITCH) po vodorovnou polohu
## (MAX_PITCH) — stejná konvence jako CameraRig.
const MIN_PITCH := -PI / 2.0
const MAX_PITCH := 0.0
const GROUND_MARGIN := 0.5

var camera: Camera3D
var target := Vector3.ZERO
## Zdroj výšky terénu pro _clamp_above_ground; nastavuje
## WorldPlacementController po vytvoření obou uzlů. Bez něj (nebo dokud
## krajina není načtená) se nic neomezuje.
var terrain: WorldPlacementView

var _yaw: float = 0.6
var _pitch: float = -0.5
var _distance: float = 60.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.far = 2000.0
	add_child(camera)
	_apply()

func center_on(pos: Vector3, distance: float = 60.0) -> void:
	target = pos
	_distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)
	_apply()

## Přesune orbitální cíl na `pos`, beze změny vzdálenosti/úhlu pohledu.
## Volá se pokaždé, když se určí nová pozice levelu (klik, pole, snap) —
## na rozdíl od `center_on` (jen výchozí pohled při otevření) nemá měnit
## zoom, jen doladit, kam kamera míří, aby šla najitá pozice hned vidět.
func point_at(pos: Vector3) -> void:
	target = pos
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance * 0.9, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * 1.1, MIN_DISTANCE, MAX_DISTANCE)

func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan.z += 1.0
	if Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		pan.y += 1.0
	if pan != Vector3.ZERO:
		var basis := Basis(Vector3.UP, _yaw)
		target += basis * pan.normalized() * PAN_SPEED * delta
	_apply()

func _apply() -> void:
	target.y = _clamp_above_ground(target.x, target.z, target.y)
	var direction := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw))
	var eye := target + direction * _distance
	eye.y = _clamp_above_ground(eye.x, eye.z, eye.y)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)

## Nedovolí bodu (cíli orbitu i oku kamery) klesnout pod povrch krajiny na
## jeho vlastním (x, z) — bez ohledu na to, jak se tam dostal (pan, zoom,
## orbit). Bez načtené kolize vrací `y` beze změny (fail-open, stejné jako
## dřív, ne regrese).
func _clamp_above_ground(x: float, z: float, y: float) -> float:
	if terrain == null:
		return y
	var height = terrain.surface_height(x, z)
	if height == null:
		return y
	return maxf(y, float(height) + GROUND_MARGIN)
