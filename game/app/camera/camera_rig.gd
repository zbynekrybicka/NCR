class_name CameraRig
extends Node3D

## Kamera (§17.3). Dva režimy: orbitální kolem aktivního robota a first
## person z jeho pohledu. Vzdálenost od robota mění jen kolečko myši —
## nikdy se neupravuje automaticky. Kamera překážkám neuhýbá: leží-li mezi
## ní a robotem kostka, robot není vidět (§2.1.1).

const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 18.0
const MOUSE_SENSITIVITY := 0.005
const FOLLOW_SPEED := 8.0

var camera: Camera3D
var first_person: bool = false

var _target := Vector3.ZERO
var _desired_target := Vector3.ZERO
var _yaw: float = 0.6
var _pitch: float = -0.5
var _distance: float = 8.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

func look_at_cell(cell: Vector3i, instant: bool = false) -> void:
	_desired_target = WorldView.cell_to_position(cell)
	if instant:
		_target = _desired_target

func set_facing(facing: int) -> void:
	if first_person:
		_yaw = WorldView.facing_to_yaw(facing)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 0.5, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 0.5, MIN_DISTANCE, MAX_DISTANCE)

func _process(delta: float) -> void:
	_target = _target.lerp(_desired_target, clampf(delta * FOLLOW_SPEED, 0.0, 1.0))
	if first_person:
		camera.global_position = _target
		camera.rotation = Vector3(_pitch * 0.5, _yaw, 0.0)
		return
	var direction := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw))
	camera.global_position = _target + direction * _distance
	camera.look_at(_target, Vector3.UP)
