class_name IntroCameraFlight
extends Node

## Úvodní přelet kamery ze zadané pozice (uloženo v editoru, §2.2.1) do
## pozice, ve které CameraRig začíná sledovat aktivního robota (§2.1.1).
## Po dobu přeletu je CameraRig zastavená (viz LevelController) — obě uzly
## by si jinak kameru přetahovaly každý snímek.

signal finished

const DURATION := 3.0

## Ochrana proti první „trhané" snímce po spuštění levelu — kompilace shaderů
## pro nově viděný materiál (typicky krajina, viz LandscapeView) umí na pár
## sekund zaseknout hlavní vlákno. Bez ořezání by tenhle jeden snímek s
## obřím `delta` posunul `_elapsed` rovnou za `DURATION` a celý přelet (i
## navazující úvodní text, který se otevře hned po `finished`) by proběhl
## neviditelně v jediném snímku.
const MAX_DELTA := 0.1

var _camera: Camera3D
var _from_eye := Vector3.ZERO
var _from_target := Vector3.ZERO
var _to_eye := Vector3.ZERO
var _to_target := Vector3.ZERO
var _elapsed: float = 0.0
var _playing: bool = false

func start(camera: Camera3D, from_eye: Vector3, from_target: Vector3,
		to_eye: Vector3, to_target: Vector3) -> void:
	_camera = camera
	_from_eye = from_eye
	_from_target = from_target
	_to_eye = to_eye
	_to_target = to_target
	_elapsed = 0.0
	_playing = true
	_apply(0.0)

func is_playing() -> bool:
	return _playing

## Skočí rovnou do cílové pozice — stejná konvence jako EventAnimator.skip().
func skip() -> void:
	if not _playing:
		return
	_playing = false
	_apply(1.0)
	finished.emit()

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += minf(delta, MAX_DELTA)
	var t := clampf(_elapsed / DURATION, 0.0, 1.0)
	_apply(t * t * (3.0 - 2.0 * t)) # smoothstep — plynulý rozjezd i doběh
	if t >= 1.0:
		_playing = false
		finished.emit()

func _apply(t: float) -> void:
	_camera.global_position = _from_eye.lerp(_to_eye, t)
	_camera.look_at(_from_target.lerp(_to_target, t), Vector3.UP)
