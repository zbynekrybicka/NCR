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

## Tempo pádu z výšky (§11) — puštěný předmět i Hanem vysypaná kostka hlíny
## (han_dump.gd), když nedosednou hned na podklad ve výšce, odkud padají.
const FALL_TIME_PER_CELL := 1.0 / 3.0

## Puštěný předmět navíc nejdřív chvíli visí ve vzduchu, ať nezmizí mimo
## záběr, než se rozpadne (postřeh z hraní) — kostka hlíny žádný hang nemá,
## padá rovnou.
const ITEM_FALL_HANG_TIME := 1.0 / 3.0

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

## Náklon na šikmině (§2.1.4 design dok.) — mřížka staví šikminu vždy jako
## přesný poměr 1:1 (1 kostka vpřed = 1 kostka nahoru/dolů), tedy skutečných
## 45°. Znaménko stejné jako u Neta výš — kladné naklápí příď nahoru.
const RAMP_PITCH := PI / 4.0

## Nadzvednutí středu robota uprostřed kroku, kde se náklon na/ze šikminy
## mění (viz `_rounding` a _process()) — vyladěno od oka, klidně uprav podle
## toho, jak to v enginu vypadá.
const RAMP_ROUND_BULGE := WorldView.CELL_SIZE * 0.12

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

## Délka viditelného "postátí" ve vzduchu před pádem — jen `_mode == "item_fall"`
## (viz _start_item_dropped()), jinde beze smyslu.
var _item_fall_hang: float = 0.0

## Padající kostka (han_dump.gd) žije v MultiMesh, ne jako vlastní uzel —
## animuje se stejně jako náklad plošiny (_apply_platform_part), jen mimo
## _platform_parts, protože tu vždy padá nejvýš jedna kostka najednou.
## Platné jen `_mode == "block_fall"`.
var _block_mm: MultiMesh
var _block_mm_index: int = -1

## Aktuální náklon (§1.1.4) podle indexu robota — mimo šplhání Neta a chůzi
## po šikmině zůstává u všech na 0.0 a slovník se pro ně nikdy nezaplní.
var _pitch: Dictionary = {}

## Platí jen pro aktuálně přehrávanou "single" událost — true, když se v ní
## náklon skutečně mění (viz _start() u ROBOT_MOVED/ROBOT_TURNED). Robot má
## osu otáčení zhruba ve svém středu, ne u nohou, takže čistě lineární náklon
## během přímé chůze na/ze šikminy vypadá, že do ní probořuje nebo se nad ní
## vznáší. Vyhlazená (smoothstep) dráha + mírné nadzvednutí uprostřed kroku
## (viz _process()) tomu opticky brání. Netova šplhání po zdi se netýká —
## tam se současné lineární chování nemění.
var _rounding: bool = false

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
	if _mode == "item_fall":
		if _elapsed < _item_fall_hang and is_instance_valid(_node):
			_node.position = _from
		elif is_instance_valid(_node):
			var fall_duration := _duration - _item_fall_hang
			var fall_ratio := (_elapsed - _item_fall_hang) / fall_duration
			_node.position = _from.lerp(_to, clamp(fall_ratio, 0.0, 1.0))
		return
	if _mode == "block_fall":
		if is_instance_valid(_block_mm):
			_block_mm.set_instance_transform(_block_mm_index,
					Transform3D(Basis.IDENTITY, _from.lerp(_to, ratio)))
		return
	if _node != null and is_instance_valid(_node):
		_node.rotation.y = lerp_angle(_from_yaw, _to_yaw, ratio)
		if _rounding:
			# Zaoblení přechodu na/ze šikminy — viz `_rounding` výš.
			var eased := ratio * ratio * (3.0 - 2.0 * ratio)
			_node.position = _from.lerp(_to, eased)
			_node.position.y += RAMP_ROUND_BULGE * sin(PI * ratio)
			_node.rotation.x = lerp_angle(_from_pitch, _to_pitch, eased)
		else:
			_node.position = _from.lerp(_to, ratio)
			_node.rotation.x = lerp_angle(_from_pitch, _to_pitch, ratio)

func _finish_current() -> void:
	if _mode == "platform":
		for part in _platform_parts:
			_apply_platform_part(part, 1.0)
		_platform_parts.clear()
		_mode = ""
		_playing = false
		return
	if _mode == "item_fall":
		if _node != null and is_instance_valid(_node):
			_node.position = _to
		_mode = ""
		_playing = false
		_node = null
		return
	if _mode == "block_fall":
		if is_instance_valid(_block_mm):
			_block_mm.set_instance_transform(_block_mm_index, Transform3D(Basis.IDENTITY, _to))
		# Teprve teď kostka doopravdy dosedla — pokud dopadla do vody, hladina
		# se má zvednout v TENHLE moment, ne už při odhození (§9.3, §11).
		view.refresh_water()
		_mode = ""
		_playing = false
		_block_mm = null
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
			# Šplhání Neta si vystačí s dosavadním lineárním náklonem beze
			# změny (viz `_rounding` výš) — týká se jen chůze po šikmině.
			_rounding = not is_equal_approx(_from_pitch, _to_pitch) \
					and substep != GridTypes.Substep.UP_VERTICAL \
					and substep != GridTypes.Substep.DOWN_VERTICAL
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
			_rounding = false
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
		Event.EventType.BLOCK_REMOVED, Event.EventType.BLOCK_FELL, Event.EventType.ICE_MELTED:
			view.refresh_blocks()
			# Změna geometrie mění kapacitu vrstev, a tím i hladinu (§9.2).
			view.refresh_water()
			return false
		Event.EventType.BLOCK_PLACED:
			return _start_block_placed(event)
		Event.EventType.PLATFORM_MOVED:
			return _start_platform_moved(event)
		Event.EventType.WATER_VOLUME_CHANGED, Event.EventType.PUMP_TRANSFERRED:
			view.refresh_water()
			return false
		Event.EventType.ITEM_PICKED_UP, Event.EventType.KEY_PICKED_UP:
			view.refresh_items()
			return false
		Event.EventType.ITEM_DROPPED:
			return _start_item_dropped(event)
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

## Puštěný předmět (§11) — `view.refresh_items()` ho už postavil na finální
## místo (stejný postup jako _start_platform_moved()), tady se jen dočasně
## odtáhne zpátky na `from` a nechá dojet: chvíli visí, pak padá tempem
## FALL_TIME_PER_CELL na kostku pádu. Dosedne-li rovnou ve výšce, odkud
## byl puštěn, žádná animace netřeba — vrací false stejně jako beze změny.
func _start_item_dropped(event: Event) -> bool:
	view.refresh_items()
	var to_cell: Vector3i = event.data["cell"]
	var from_cell: Vector3i = event.data["from"]
	var distance := from_cell.y - to_cell.y
	if distance <= 0:
		return false
	_node = view.item_node(to_cell)
	if _node == null:
		return false
	_mode = "item_fall"
	_to = WorldView.cell_to_position(to_cell)
	_from = WorldView.cell_to_position(from_cell)
	_node.position = _from
	_item_fall_hang = ITEM_FALL_HANG_TIME
	_begin(ITEM_FALL_HANG_TIME + FALL_TIME_PER_CELL * distance)
	return true

## Kostka umístěná blokem (BLOCK_PLACED — Hanovo vysypání korby, Yeovo
## zmrazení) — `view.refresh_blocks()` ji už postavil do MultiMeshe na
## finální místo (viz block_multimesh_slot(), stejný postup jako u plošiny).
## Padá-li o patro a víc (han_dump.gd), dočasně se odtáhne zpátky na `from`
## a nechá dojet tempem FALL_TIME_PER_CELL na kostku — `view.refresh_water()`
## se schválně nezavolá hned (viz refresh_blocks()/refresh_water() dvojice u
## ostatních typů blokových událostí výš), ale až v _finish_current(), aby
## hladina stoupla přesně v okamžiku dopadu, ne už při odhození (§9.3, §11).
## Dosedne-li kostka rovnou (Yeo), animace není třeba a hladina se dorovná
## hned tady stejně jako dřív.
func _start_block_placed(event: Event) -> bool:
	view.refresh_blocks()
	var to_cell: Vector3i = event.data["cell"]
	var from_cell: Vector3i = event.data["from"]
	var distance := from_cell.y - to_cell.y
	if distance <= 0:
		view.refresh_water()
		return false
	var slot := view.block_multimesh_slot(to_cell)
	if slot.is_empty():
		view.refresh_water()
		return false
	_mode = "block_fall"
	_block_mm = slot["multimesh"]
	_block_mm_index = slot["index"]
	_to = WorldView.cell_to_position(to_cell)
	_from = WorldView.cell_to_position(from_cell)
	_block_mm.set_instance_transform(_block_mm_index, Transform3D(Basis.IDENTITY, _from))
	_begin(FALL_TIME_PER_CELL * distance)
	return true

## Cílový náklon pro daný substep (§1.1.4) — šplhání po zdi řeší jen Net
## (první větev, i když substep DOWN_VERTICAL sdílí s pádem vlivem gravitace,
## viz gravity.gd), chůzi po šikmině (RAMP_PITCH) sdílený match níž řeší
## pro kohokoli, kdo po šikmině vůbec chodí. Da po šikminách nikdy nechodí
## (viz da.json — nemá pro ně žádnou větev), takže se ho druhá větev nikdy
## netýká. U FORWARD (rovina, včetně dosednutí po šikmině nebo jejím vrcholu)
## zůstává 0.0.
##
## Sešplhání nemá zvlášť "dosednutí": strom (net.json, větev `climb_down`)
## poslední DOWN_VERTICAL rovnou ukončí přes `below_is_solid` → `succeed`,
## bez dalšího substepu navrch. Proto se tady musí narovnat rovnou v tomhle
## kroku, jakmile pod cílovou buňkou už je pevná podlaha — jinak by Net
## zůstal viset nakloněný na zdi, i když už fakticky stojí na zemi.
func _target_pitch(robot: RobotView, substep: int, to_cell: Vector3i) -> float:
	if robot != null and robot.kind == GridTypes.RobotKind.NET:
		match substep:
			GridTypes.Substep.UP_VERTICAL:
				return NET_PITCH_UP
			GridTypes.Substep.DOWN_VERTICAL:
				if view.world.has_support_below(to_cell):
					return 0.0
				return NET_PITCH_DOWN
	match substep:
		GridTypes.Substep.UP_RAMP:
			return RAMP_PITCH
		GridTypes.Substep.DOWN_RAMP:
			return -RAMP_PITCH
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
