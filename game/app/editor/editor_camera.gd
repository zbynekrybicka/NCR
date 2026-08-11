class_name EditorCamera
extends Node3D

## Volná orbitální kamera pro editor — na rozdíl od CameraRig nesleduje
## robota a nekoliduje s mřížkou (v editoru je běžné dívat se zvenku
## i skrz kostky).

const MOUSE_SENSITIVITY := 0.005
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 80.0
const PAN_SPEED := 8.0

var camera: Camera3D
var target := Vector3.ZERO

var _yaw: float = 0.6
var _pitch: float = -0.6
var _distance: float = 12.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.far = 500.0
	add_child(camera)
	_apply()

## Namíří a oddálí kameru tak, aby byl vidět celý level.
func center_on(level: LevelData) -> void:
	target = Vector3(level.size) * WorldView.CELL_SIZE * 0.5
	_distance = clampf(maxf(level.size.x, maxf(level.size.y, level.size.z)) * 1.6 + 4.0,
			MIN_DISTANCE, MAX_DISTANCE)
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 1.0, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 1.0, MIN_DISTANCE, MAX_DISTANCE)

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
	var direction := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw))
	camera.global_position = target + direction * _distance
	camera.look_at(target, Vector3.UP)
