class_name EventAnimator
extends Node

## Přehrávání událostí (§17.2). Simulace na animaci nikdy nečeká — stav je
## dávno finální; animátor jen v čase dohrává, co se stalo. Po dobu
## přehrávání je blokovaný VSTUP, ne simulace.

signal finished

const STEP_TIME := 0.35
const TURN_TIME := 0.25
## Přejezd transportní plošiny (§13.2) — pomalejší, "těžší" pohyb než krok
## robota, a hlavně jednotný pro celý náklad (paluba, jezdci, klíč/předměty),
## viz _start_platform_moved().
const PLATFORM_TIME := 1.0

## Klipy uvnitř modelu robota podle substepu (§6.4). Bere se první, který
## model doopravdy má — kdo klip nemá, se jen posune. Krok po šikmině je pořád
## chůze, svislý (šplhání Neta, let Da) už ne — tam by `walk` lhal.
const MOVE_CLIPS := {
	GridTypes.Substep.FORWARD: ["walk"],
	GridTypes.Substep.UP_RAMP: ["walk_ramp_up", "walk"],
	GridTypes.Substep.DOWN_RAMP: ["walk_ramp_down", "walk"],
	# Net nemá vlastní klip na šplhání — venku ho napřímí `_target_pitch()`
	# na 90° a stejný `walk` klip mu pak nohama "kráčí" po stěně vzhůru/dolů.
	GridTypes.Substep.UP_VERTICAL: ["climb_up", "fly_up", "walk"],
	GridTypes.Substep.DOWN_VERTICAL: ["climb_down", "fly_down", "walk"],
}

## Náklon Neta při šplhání (§1.1.4 design dok.) — kladná rotace kolem
## lokální X naklápí příď od vodorovné (-Z) směrem k +Y, tedy nahoru.
const NET_PITCH_UP := PI / 2.0
const NET_PITCH_DOWN := -PI / 2.0

var view: WorldView
var _queue: Array = []
var _playing: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _from_yaw: float = 0.0
var _to_yaw: float = 0.0
var _from_pitch: float = 0.0
var _to_pitch: float = 0.0
var _node: Node3D
var _robot: RobotView

## "" = nic (mimo přehrávání), "single" = běžný _node/_robot pohyb výš,
## "platform" = souběžná jízda více částí najednou, viz _platform_parts.
var _mode: String = ""
## Každá položka: {kind:"multimesh", multimesh, index, basis, from, to} pro
## kostky paluby (MultiMesh instance), nebo {kind:"node", node, from, to} pro
## roboty/zařízení/předměty/klíč — viz _start_platform_moved().
var _platform_parts: Array = []

## Aktuální náklon (§1.1.4) podle indexu robota — mimo šplhání Neta zůstává
## u všech na 0.0 a slovník se pro ně nikdy nezaplní.
var _pitch: Dictionary = {}

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
	if _mode == "platform":
		for part in _platform_parts:
			_apply_platform_part(part, ratio)
		return
	if _node != null and is_instance_valid(_node):
		_node.position = _from.lerp(_to, ratio)
		_node.rotation.y = lerp_angle(_from_yaw, _to_yaw, ratio)
		_node.rotation.x = lerp_angle(_from_pitch, _to_pitch, ratio)

func _finish_current() -> void:
	if _mode == "platform":
		for part in _platform_parts:
			_apply_platform_part(part, 1.0)
		_platform_parts.clear()
		_mode = ""
		_playing = false
		return
	if _node != null and is_instance_valid(_node):
		_node.position = _to
		_node.rotation.y = _to_yaw
		_node.rotation.x = _to_pitch
	if _robot != null and is_instance_valid(_robot):
		_robot.settle()
	_playing = false
	_node = null
	_robot = null

## Aplikuje `ratio` (0..1) na jednu část jízdy plošiny — kostku paluby
## (MultiMesh instance) nebo uzel (robot/zařízení/předmět/klíč).
func _apply_platform_part(part: Dictionary, ratio: float) -> void:
	var pos: Vector3 = (part["from"] as Vector3).lerp(part["to"], ratio)
	if part["kind"] == "multimesh":
		var mm: MultiMesh = part["multimesh"]
		if is_instance_valid(mm):
			mm.set_instance_transform(part["index"], Transform3D(part["basis"], pos))
	else:
		var node: Node3D = part["node"]
		if node != null and is_instance_valid(node):
			node.position = pos

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
			_mode = "single"
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
			_from_pitch = _pitch.get(robot_index, 0.0)
			_to_pitch = _target_pitch(_robot, substep, event.data["to"])
			_pitch[robot_index] = _to_pitch
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
			_mode = "single"
			_ramp_chain_robot = -1
			var turned_robot_index := int(event.data["robot"])
			_node = view.robot_node(turned_robot_index)
			if _node == null:
				return false
			_robot = view.robot_view(turned_robot_index)
			_from = _node.position
			_to = _node.position
			_from_yaw = _node.rotation.y
			_to_yaw = WorldView.facing_to_yaw(int(event.data["to_dir"]))
			# Otočka na místě náklon ze šplhání nemění (§1.1.4) — mění se jen
			# na dalším pohybu pryč ze stěny.
			_from_pitch = _pitch.get(turned_robot_index, 0.0)
			_to_pitch = _from_pitch
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
		Event.EventType.BLOCK_FELL, Event.EventType.ICE_MELTED:
			view.refresh_blocks()
			# Změna geometrie mění kapacitu vrstev, a tím i hladinu (§9.2).
			view.refresh_water()
			return false
		Event.EventType.PLATFORM_MOVED:
			return _start_platform_moved(event)
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

## Přejezd transportní plošiny (§13.2, design dok. §2.2.1) jako JEDNA
## synchronní jízda: paluba, jezdci, zařízení, klíč i odložené předměty se
## po dobu PLATFORM_TIME pohybují stejným tempem, ne postupně za sebou.
##
## Simulace v tuhle chvíli už je hotová — svět nese CÍLOVÝ stav. Proto se
## nejdřív vše dorovná na finální pozici obvyklými refresh_*() (stejně jako
## dřív), a teprve pak se každá nesená část dočasně "odtáhne" zpátky o
## `delta` (viz _apply_platform_part(part, 0.0) níž) a nechá dojet přes
## _process(). Roboti výjimku netvoří obráceně: jejich uzel refresh nemá,
## takže zůstává na staré pozici, dokud ho sem sama nedotáhneme na cíl.
func _start_platform_moved(event: Event) -> bool:
	var platform_index := int(event.data["platform"])
	var from_offset: Vector3i = event.data["from_offset"]
	var to_offset: Vector3i = event.data["to_offset"]
	var delta := to_offset - from_offset
	var offset := Vector3(delta) * WorldView.CELL_SIZE
	var platform: PlatformState = view.world.platforms[platform_index]

	view.refresh_blocks()
	view.refresh_water()
	view.refresh_devices()
	view.refresh_items()

	_platform_parts.clear()

	for base_cell: Vector3i in platform.cells:
		var slot := view.block_multimesh_slot(base_cell + to_offset)
		if slot.is_empty():
			continue
		var mm: MultiMesh = slot["multimesh"]
		var index: int = slot["index"]
		var final_pos: Vector3 = mm.get_instance_transform(index).origin
		var basis: Basis = mm.get_instance_transform(index).basis
		_platform_parts.append({"kind": "multimesh", "multimesh": mm, "index": index,
				"basis": basis, "from": final_pos - offset, "to": final_pos})

	for device_index in event.data["carried_devices"]:
		var device_node := view.device_node(int(device_index))
		if device_node != null:
			_platform_parts.append({"kind": "node", "node": device_node,
					"from": device_node.position - offset, "to": device_node.position})

	# Roboti nemají žádný refresh, který by je posunul dopředu — jejich uzel
	# je pořád na staré pozici, cíl je proto `+ offset`, ne `- offset`.
	for robot_index in event.data["riders"]:
		var robot_node := view.robot_node(int(robot_index))
		if robot_node != null:
			_platform_parts.append({"kind": "node", "node": robot_node,
					"from": robot_node.position, "to": robot_node.position + offset})

	for cell: Vector3i in event.data["moved_item_cells"]:
		var item_node := view.item_node(cell)
		if item_node != null:
			_platform_parts.append({"kind": "node", "node": item_node,
					"from": item_node.position - offset, "to": item_node.position})

	if bool(event.data["key_moved"]):
		var key_node := view.key_node()
		if key_node != null:
			_platform_parts.append({"kind": "node", "node": key_node,
					"from": key_node.position - offset, "to": key_node.position})

	for part in _platform_parts:
		_apply_platform_part(part, 0.0)

	_mode = "platform"
	_begin(PLATFORM_TIME)
	return true

## Cílový náklon pro daný substep (§1.1.4) — jen Net se naklápí, u ostatních
## robotů (i když substep DOWN_VERTICAL sdílí s pádem vlivem gravitace,
## viz gravity.gd) zůstává 0.0.
##
## Sešplhání nemá zvlášť "dosednutí": strom (net.json, větev `climb_down`)
## poslední DOWN_VERTICAL rovnou ukončí přes `below_is_solid` → `succeed`,
## bez dalšího substepu navrch. Proto se tady musí narovnat rovnou v tomhle
## kroku, jakmile pod cílovou buňkou už je pevná podlaha — jinak by Net
## zůstal viset nakloněný na zdi, i když už fakticky stojí na zemi.
func _target_pitch(robot: RobotView, substep: int, to_cell: Vector3i) -> float:
	if robot == null or robot.kind != GridTypes.RobotKind.NET:
		return 0.0
	match substep:
		GridTypes.Substep.UP_VERTICAL:
			return NET_PITCH_UP
		GridTypes.Substep.DOWN_VERTICAL:
			if view.world.has_support_below(to_cell):
				return 0.0
			return NET_PITCH_DOWN
	return 0.0

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
