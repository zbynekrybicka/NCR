class_name EventAnimator
extends Node

## Přehrávání událostí (§17.2). Simulace na animaci nikdy nečeká — stav je
## dávno finální; animátor jen v čase dohrává, co se stalo. Po dobu
## přehrávání je blokovaný VSTUP, ne simulace.

signal finished

const STEP_TIME := 0.35
const TURN_TIME := 0.25

## Klipy uvnitř modelu robota podle substepu (§6.4). Bere se první, který
## model doopravdy má — kdo klip nemá, se jen posune. Krok po šikmině je pořád
## chůze, svislý (šplhání Neta, let Da) už ne — tam by `walk` lhal.
const MOVE_CLIPS := {
	GridTypes.Substep.FORWARD: ["walk"],
	GridTypes.Substep.UP_RAMP: ["walk_ramp_up", "walk"],
	GridTypes.Substep.DOWN_RAMP: ["walk_ramp_down", "walk"],
	GridTypes.Substep.UP_VERTICAL: ["climb_up", "fly_up"],
	GridTypes.Substep.DOWN_VERTICAL: ["climb_down", "fly_down"],
}

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
var _robot: RobotView

## Řetěz šikmin dolů (vícepatrové schodiště, viz _start) — dokud
## `_ramp_chain_robot` sedí na aktuálním robotovi, jede se svah, který
## začal o jednu událost dřív. -1, když žádný sjezd neprobíhá.
##
## Na šikmině nelze setrvat (design dok. §2.1.4), takže jeden vizuální sjezd
## je vždy nejmíň dvě simulační události: DOWN_RAMP (na blok rampy) a
## dosednutí (FORWARD, nebo další DOWN_RAMP u schodiště). Cílová výška
## události DOWN_RAMP ale odpovídá středu rampové kostky — poloviční sklon
## uprostřed jejího svahu, ne úpatí. Proto se pád o jednu kostku schválně
## odloží na NÁSLEDUJÍCÍ událost (`_ramp_pending_y`): událost DOWN_RAMP jede
## vodorovně (ve výšce, odkud vyjela), a teprve další událost — ať už
## dosednutí, nebo další patro schodiště — sjede tu odloženou kostku šikmo
## dolů, protože JEJÍ vlastní cílová výška už s odloženým pádem počítá.
var _ramp_chain_robot: int = -1
var _ramp_pending_y: float = 0.0

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
	if _robot != null and is_instance_valid(_robot):
		_robot.settle()
	_playing = false
	_node = null
	_robot = null

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
			var robot_index := int(event.data["robot"])
			_node = view.robot_node(robot_index)
			if _node == null:
				return false
			_robot = view.robot_view(robot_index)
			_from = _node.position
			var target := WorldView.cell_to_position(event.data["to"])
			_from_yaw = _node.rotation.y
			_to_yaw = _node.rotation.y
			var substep := int(event.data["substep"])
			if substep == GridTypes.Substep.DOWN_RAMP:
				if _ramp_chain_robot != robot_index:
					# První šikmina sjezdu — pád se teprve začíná odkládat.
					_ramp_pending_y = _from.y
				_to = Vector3(target.x, _ramp_pending_y, target.z)
				_begin(STEP_TIME)
				_ramp_pending_y = target.y
				_ramp_chain_robot = robot_index
			else:
				# Dosednutí po sjezdu (nebo běžná chůze) použije svůj vlastní
				# cíl beze změny — pokud navazuje na řetěz šikmin, `_from` je
				# pořád ve výšce před odloženým pádem, takže tenhle úsek vyjde
				# jako čistá 45° šikmina dolů do správné výšky.
				_to = target
				_begin(STEP_TIME)
				_ramp_chain_robot = -1
			_play_clips(MOVE_CLIPS.get(substep, []), STEP_TIME)
			return true
		Event.EventType.ROBOT_TURNED:
			_ramp_chain_robot = -1
			_node = view.robot_node(int(event.data["robot"]))
			if _node == null:
				return false
			_robot = view.robot_view(int(event.data["robot"]))
			_from = _node.position
			_to = _node.position
			_from_yaw = _node.rotation.y
			_to_yaw = WorldView.facing_to_yaw(int(event.data["to_dir"]))
			_begin(TURN_TIME)
			_play_clips(_turn_clips(int(event.data["from_dir"]),
					int(event.data["to_dir"])), TURN_TIME)
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
			if event.type == Event.EventType.PLATFORM_MOVED:
				# Zařízení v kostkách plošiny jedou s ní (devices.gd:157) —
				# refresh_devices() dorovná i pozici, ne jen stav.
				view.refresh_devices()
			return false
		Event.EventType.WATER_VOLUME_CHANGED, Event.EventType.PUMP_TRANSFERRED:
			view.refresh_water()
			return false
		Event.EventType.ITEM_PICKED_UP, Event.EventType.ITEM_DROPPED, \
		Event.EventType.KEY_PICKED_UP:
			view.refresh_items()
			return false
		Event.EventType.TARGET_UNLOCKED:
			view.refresh_targets()
			return false
		Event.EventType.DEVICE_TOGGLED, Event.EventType.DEVICE_REPAIRED:
			view.refresh_devices()
			return false
	return false

func _begin(duration: float) -> void:
	_elapsed = 0.0
	_duration = duration
	_playing = true

## Klip se roztahuje na dobu události, ne naopak (§6.3): tempo hry je herní
## rozhodnutí, ne důsledek toho, kolik snímků měl klip v Blenderu.
func _play_clips(clips: Array, duration: float) -> void:
	if _robot == null or clips.is_empty():
		return
	_robot.play_action(PackedStringArray(clips), duration)

## Směr otáčky z rozdílu světových stran. Klipy jsou pojmenované z pohledu
## robota (blender/net/anim_walk.py), takže NORTH -> EAST je `turn_right`.
static func _turn_clips(from_dir: int, to_dir: int) -> Array:
	match posmod(to_dir - from_dir, 4):
		1:
			return ["turn_right"]
		2:
			return ["turn_around"]
		3:
			return ["turn_left"]
	return []
