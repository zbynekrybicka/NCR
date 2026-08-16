class_name EventAnimator
extends Node

## Přehrávání událostí (§17.2). Simulace na animaci nikdy nečeká — stav je
## dávno finální; animátor jen v čase dohrává, co se stalo. Po dobu
## přehrávání je blokovaný VSTUP, ne simulace.

signal finished

const STEP_TIME := 0.14
const TURN_TIME := 0.10

var view: WorldView
var _queue: Array = []
var _playing: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _from_yaw: float = 0.0
var _to_yaw: float = 0.0
var _node: Node3D

func is_playing() -> bool:
	return _playing or not _queue.is_empty()

func play(events: Array) -> void:
	for event in events:
		_queue.append(event)
	if not _playing:
		_next()

## Přeskočení animace — dokončí vše okamžitě (§17.2).
func skip() -> void:
	while _playing or not _queue.is_empty():
		_finish_current()
		_next()

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_finish_current()
		_next()
		return
	var ratio := _elapsed / _duration
	if _node != null and is_instance_valid(_node):
		_node.position = _from.lerp(_to, ratio)
		_node.rotation.y = lerp_angle(_from_yaw, _to_yaw, ratio)

func _finish_current() -> void:
	if _node != null and is_instance_valid(_node):
		_node.position = _to
		_node.rotation.y = _to_yaw
	_playing = false
	_node = null

func _next() -> void:
	while not _queue.is_empty():
		var event: Event = _queue.pop_front()
		if _start(event):
			return
	_playing = false
	finished.emit()

func _start(event: Event) -> bool:
	match event.type:
		Event.EventType.ROBOT_MOVED:
			_node = view.robot_node(int(event.data["robot"]))
			if _node == null:
				return false
			_from = _node.position
			_to = WorldView.cell_to_position(event.data["to"])
			_from_yaw = _node.rotation.y
			_to_yaw = _node.rotation.y
			_begin(STEP_TIME)
			return true
		Event.EventType.ROBOT_TURNED:
			_node = view.robot_node(int(event.data["robot"]))
			if _node == null:
				return false
			_from = _node.position
			_to = _node.position
			_from_yaw = _node.rotation.y
			_to_yaw = WorldView.facing_to_yaw(int(event.data["to_dir"]))
			_begin(TURN_TIME)
			return true
		Event.EventType.ROBOT_ENTERED_TARGET:
			var node := view.robot_node(int(event.data["robot"]))
			if node != null:
				node.visible = false
			return false
		Event.EventType.BLOCK_REMOVED, Event.EventType.BLOCK_PLACED, \
		Event.EventType.BLOCK_FELL, Event.EventType.PLATFORM_MOVED, \
		Event.EventType.ICE_MELTED:
			view.refresh_blocks()
			# Změna geometrie mění kapacitu vrstev, a tím i hladinu (§9.2).
			view.refresh_water()
			return false
		Event.EventType.WATER_VOLUME_CHANGED, Event.EventType.PUMP_TRANSFERRED:
			view.refresh_water()
			return false
		Event.EventType.ITEM_PICKED_UP, Event.EventType.ITEM_DROPPED, \
		Event.EventType.KEY_PICKED_UP:
			view.refresh_items()
			return false
	return false

func _begin(duration: float) -> void:
	_elapsed = 0.0
	_duration = duration
	_playing = true
