class_name CameraRig
extends Node3D

## Kamera (§17.3). Dva režimy: orbitální kolem aktivního robota a first
## person z jeho pohledu. Vzdálenost od robota mění jen kolečko myši —
## nikdy se neupravuje automaticky. Kamera překážkám neuhýbá: leží-li mezi
## ní a robotem kostka, robot není vidět (§2.1.1).

## Vzdálenosti platí pro měřítko 1.0 (level mimo krajinu); je-li level
## zmenšený (viz set_level_scale), škálují se stejným poměrem, jinak by
## kamera zůstala v „metrech krajiny" a robot by z ní vypadal jako mravenec.
const BASE_MIN_DISTANCE := 2.0
const BASE_MAX_DISTANCE := 18.0
const MOUSE_SENSITIVITY := 0.005

## Orbit kolem osy Y (yaw) je volný, celých 360°, kolem osy Z se nerotuje
## vůbec. Kolem osy X (pitch) svírá nejvýš 90° od pohledu shora: MIN_PITCH
## je pohled kolmo dolů, MAX_PITCH vodorovná poloha — dál (podhled, kamera
## by se dívala zespoda/zpod povrchu) už ne.
const MIN_PITCH := -PI / 2.0
const MAX_PITCH := 0.0

var camera: Camera3D
var first_person: bool = false

var level_scale: float = 1.0

## Uzel sledovaného robota (WorldView.robot_node) — kamera si cíl čte přímo
## z jeho `global_position` KAŽDÝ SNÍMEK, ne z buňky cíle přes vlastní lerp.
## EventAnimator totéž `position` za pohybu plynule interpoluje (§17.2), takže
## kamera tím pádem kopíruje přesně tu samou křivku jako robot — žádné
## nezávislé dohánění, tedy žádné poskakování.
var _followed_robot: Node3D

var _target := Vector3.ZERO
var _yaw: float = 0.6
var _pitch: float = -0.5
var _distance: float = 8.0
var _min_distance: float = BASE_MIN_DISTANCE
var _max_distance: float = BASE_MAX_DISTANCE

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

## Level zasazený do krajiny se kreslí zmenšený (LevelController), takže
## kamera musí orbitovat ve stejném měřítku, jinak by od robota buď příliš
## odskočila, nebo do něj vjela.
func set_level_scale(scale: float) -> void:
	level_scale = scale
	_min_distance = BASE_MIN_DISTANCE * scale
	_max_distance = BASE_MAX_DISTANCE * scale
	_distance = clampf(_distance * scale, _min_distance, _max_distance)

func follow(robot: Node3D) -> void:
	_followed_robot = robot
	if robot != null and is_instance_valid(robot):
		_target = robot.global_position

func set_facing(facing: int) -> void:
	if first_person:
		_yaw = WorldView.facing_to_yaw(facing)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 0.5 * level_scale, _min_distance, _max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 0.5 * level_scale, _min_distance, _max_distance)

func _process(_delta: float) -> void:
	if not first_person:
		var resting := resting_transform()
		camera.global_position = resting["eye"]
		camera.look_at(resting["target"], Vector3.UP)
		return
	if _followed_robot != null and is_instance_valid(_followed_robot):
		_target = _followed_robot.global_position
	camera.global_position = _target
	camera.rotation = Vector3(_pitch * 0.5, _yaw, 0.0)

## Kam by kamera v tomto okamžiku mířila v běžném (ne first-person) režimu —
## bez vedlejších účinků na `_target`, aby to šlo spočítat i dřív, než
## CameraRig vůbec dostane první `_process` (viz IntroCameraFlight, kam se
## tahle hodnota předává jako cílový bod přeletu).
func resting_transform() -> Dictionary:
	var target := _target
	if _followed_robot != null and is_instance_valid(_followed_robot):
		target = _followed_robot.global_position
	var direction := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw))
	return {"eye": target + direction * _distance, "target": target}
