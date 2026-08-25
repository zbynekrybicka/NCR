class_name EditorController
extends Node3D

## Propojuje EditorSession (data, §16) se scénou: EditorView (vykreslení),
## EditorCamera (pohled) a EditorUi (paleta/dialogy). Myš se promítá do
## mřížky obyčejným krokováním paprsku po malých úsecích, ne fyzikálním
## raycastem (level nemá kolizní tvary, je to čistě datová mřížka).

signal play_requested(simulation: Simulation, world_position: Variant)
signal menu_requested

enum Tool { BLOCK, ROBOT, ITEM, KEY, ERASE, DEVICE, RESERVOIR, PLATFORM }

const PICK_STEP := 0.04
const PICK_MARGIN := 1

var session: EditorSession
var view: EditorView
var camera: EditorCamera
var ui: EditorUi

var _tool: int = Tool.BLOCK
var _block_type: int = GridTypes.BlockType.WALL
var _robot_kind: int = GridTypes.RobotKind.HAN
var _item_type: int = GridTypes.ItemType.FUEL
var _orientation: int = GridTypes.Direction.NORTH

# Mechanismy (§13): zařízení se kladou po jedné buňce, nádrž se zakládá
# kliknutím do uzavřené dutiny, plošina se skládá z vybraných zdí.
var _device_kind: int = GridTypes.DeviceKind.POWER_CABINET
var _device_control_mode: int = GridTypes.ControlMode.BUTTON
var _device_broken: bool = false
var _reservoir_volume: int = 0
var _reservoir_unlimited: bool = false
var _platform_selection: Array = []   # Vector3i, buňky zdí v poloze A
## Jednorázová hláška k poslednímu úkonu; _refresh_status ji vypíše nad
## seznam problémů levelu a zase zahodí.
var _hint: String = ""

var _active: bool = true

# Umístění levelu do krajiny (§7.3 import-assets.md) — pozice se váže na
# cestu k uloženému souboru, ne na LevelData samotné (level ji neukládá).
var _current_level_path: String = ""
var _world_placement: WorldPlacementController

func _ready() -> void:
	session = EditorSession.new()

	view = EditorView.new()
	add_child(view)
	view.show_level(session.level)

	camera = EditorCamera.new()
	add_child(camera)
	camera.center_on(session.level)

	ui = EditorUi.new()
	add_child(ui)
	_connect_ui()
	_refresh_status()

func set_active(active: bool) -> void:
	_active = active
	view.visible = active
	ui.visible = active
	set_process(active)
	set_process_unhandled_input(active)
	camera.set_process(active)
	camera.set_process_unhandled_input(active)
	if active:
		camera.camera.current = true

func _connect_ui() -> void:
	ui.block_tool_selected.connect(func(block_type):
		_tool = Tool.BLOCK
		_block_type = block_type
		ui.set_tool_label("Nástroj: %s" % EditorUi.BLOCK_LABELS.get(block_type, "?")))
	ui.robot_tool_selected.connect(func(kind):
		_tool = Tool.ROBOT
		_robot_kind = kind
		ui.set_tool_label("Nástroj: robot %s" % GridTypes.robot_name(kind)))
	ui.item_tool_selected.connect(func(item_type):
		_tool = Tool.ITEM
		_item_type = item_type
		ui.set_tool_label("Nástroj: %s" % EditorUi.ITEM_LABELS.get(item_type, "?")))
	ui.key_tool_selected.connect(func():
		_tool = Tool.KEY
		ui.set_tool_label("Nástroj: klíč"))
	ui.erase_tool_selected.connect(func():
		_tool = Tool.ERASE
		ui.set_tool_label("Nástroj: guma"))
	ui.device_tool_selected.connect(func(kind):
		_tool = Tool.DEVICE
		_device_kind = kind
		ui.set_tool_label("Nástroj: %s" % EditorUi.DEVICE_LABELS.get(kind, "?")))
	ui.device_settings_changed.connect(func(control_mode, is_broken):
		_device_control_mode = control_mode
		_device_broken = is_broken)
	ui.reservoir_tool_selected.connect(func():
		_tool = Tool.RESERVOIR
		ui.set_tool_label("Nástroj: nádrž"))
	ui.reservoir_settings_changed.connect(func(volume_units, unlimited):
		_reservoir_volume = volume_units
		_reservoir_unlimited = unlimited)
	ui.platform_tool_selected.connect(func():
		_tool = Tool.PLATFORM
		ui.set_tool_label("Nástroj: výběr buněk plošiny"))
	ui.platform_selection_cleared.connect(func():
		_clear_platform_selection()
		_refresh_status())
	ui.platform_create_requested.connect(_on_create_platform)
	ui.pump_create_requested.connect(_on_create_pump)
	ui.mechanism_remove_requested.connect(_on_remove_mechanism)
	ui.rotate_pressed.connect(_on_rotate)
	ui.undo_pressed.connect(_on_undo)
	ui.redo_pressed.connect(_on_redo)
	ui.save_requested.connect(_on_save)
	ui.load_requested.connect(_on_load)
	ui.new_level_requested.connect(_on_new_level)
	ui.play_pressed.connect(_on_play)
	ui.menu_pressed.connect(func(): menu_requested.emit())
	ui.world_placement_requested.connect(_on_world_placement_requested)

func _process(_delta: float) -> void:
	if not _active:
		return
	var pick := _pick()
	if not pick.hit:
		view.set_cursor(null, false)
		return
	# Guma a výběr buněk plošiny míří na kostku samotnou, ostatní nástroje
	# na prázdnou buňku před ní.
	var target_cell: Vector3i = pick.solid_cell \
			if _tool == Tool.ERASE or _tool == Tool.PLATFORM else pick.place_cell
	view.set_cursor(target_cell, session.level.is_inside(target_cell))

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_rotate()
			return
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_on_undo()
			return
		if event.ctrl_pressed and event.keycode == KEY_Y:
			_on_redo()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click() # pravé tlačítko je vyhrazené pro orbit kamery (EditorCamera)

func _on_click() -> void:
	var handle := _pick_resize_handle()
	if not handle.is_empty():
		_on_resize_handle_clicked(int(handle["direction"]), bool(handle["grow"]))
		return
	var pick := _pick()
	if not pick.hit:
		return
	match _tool:
		Tool.BLOCK:
			if session.level.is_inside(pick.place_cell):
				session.run(EditorOperation.SetCell.new(
						pick.place_cell, _block_type, 0, _orientation))
		Tool.ERASE:
			_erase_at(pick.solid_cell)
		Tool.ROBOT:
			if session.level.is_inside(pick.place_cell):
				session.run(EditorOperation.PlaceRobotAppend.new(
						_robot_kind, pick.place_cell, _orientation))
		Tool.ITEM:
			if session.level.is_inside(pick.place_cell):
				session.run(EditorOperation.PlaceItem.new(pick.place_cell, _item_type))
		Tool.KEY:
			if session.level.is_inside(pick.place_cell):
				session.run(EditorOperation.MoveKey.new(pick.place_cell))
		Tool.DEVICE:
			_place_device(pick.place_cell)
		Tool.RESERVOIR:
			_set_reservoir(pick.place_cell)
		Tool.PLATFORM:
			_toggle_platform_cell(pick.solid_cell)
	view.rebuild()
	_refresh_status()

# ── Rozšíření/zúžení levelu (§2.2.1) ────────────────────────────────────

## Klik na zelený prvek level rozšíří o řadu ve zvoleném směru, klik na
## červený ho zúží — ale jen když je celá odebíraná řada úplně prázdná;
## jinak se zúžení odmítne a jen se vypíše hláška (aby se do undo historie
## nezanášela operace, která nic nezměnila).
func _on_resize_handle_clicked(direction: int, grow: bool) -> void:
	if not grow and not session.can_shrink_in_direction(direction):
		_hint = "Zúžení směrem %s nejde — odebíraná řada není prázdná." \
				% String(EditorUi.DIRECTION_LABELS.get(direction, "?"))
		view.rebuild()
		_refresh_status()
		return
	session.run(EditorOperation.ResizeRow.new(direction, grow))
	view.rebuild()
	_refresh_status()

## Vlastní paprsek na prvky u okraje levelu, stejným způsobem jako `_pick()`
## na mřížku, ale bez krokování — jde jen o pár koulí, obyčejný test
## paprsek-koule stačí. Vrací {} když paprsek nic netrefil.
func _pick_resize_handle() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.camera.project_ray_origin(mouse)
	var dir := camera.camera.project_ray_normal(mouse)
	var best: Dictionary = {}
	var best_dist := INF
	for handle in view.resize_handles():
		var center: Vector3 = handle["position"]
		var proj := (center - from).dot(dir)
		if proj < 0.0:
			continue
		var closest := from + dir * proj
		if closest.distance_to(center) > float(handle["radius"]):
			continue
		if proj < best_dist:
			best_dist = proj
			best = handle
	return best

# ── Mechanismy (§13) ─────────────────────────────────────────────────────

## Zařízení zabírá vlastní kostku, která se chová jako zeď (design dok.
## §2.2.1) — operace ji rovnou položí. Přístupový směr je aktuální orientace
## nástroje (klávesa R), takže musí být vodorovný.
func _place_device(cell: Vector3i) -> void:
	if not session.level.is_inside(cell):
		return
	if not GridTypes.is_horizontal(_orientation):
		_hint = "Zařízení se ovládá jen z vodorovného směru — otoč nástroj (R)."
		return
	session.run(EditorOperation.PlaceDevice.new(cell, _device_kind, _orientation,
			_device_control_mode, _device_broken))

## Nádrž nelze umístit volně — zakládá se v uzavřené dutině, jejíž tvar
## a kapacita vyplynou z okolních zdí (design dok. §2.2.1, §9.1). Klik do
## buňky, která už do nějaké nádrže patří, jen upraví její nastavení.
func _set_reservoir(cell: Vector3i) -> void:
	if not session.level.is_inside(cell):
		return
	var existing := session.reservoir_index_at(cell)
	if existing != -1:
		var anchor: Vector3i = session.level.reservoirs[existing].anchor
		session.run(EditorOperation.SetReservoir.new(anchor, _reservoir_volume,
				_reservoir_unlimited))
		return
	if not session.cell_is_in_closed_cavity(cell):
		_hint = "Nádrž musí být uzavřená dutina — %s je otevřená, voda by vytekla." % cell
		return
	session.run(EditorOperation.SetReservoir.new(cell, _reservoir_volume,
			_reservoir_unlimited))

## Plošina se skládá ze série zdí (design dok. §2.2.1); klik zeď do výběru
## přidá, další klik ji zase odebere.
func _toggle_platform_cell(cell: Vector3i) -> void:
	if not session.level.is_inside(cell):
		return
	if session.level.block_at(cell) != GridTypes.BlockType.WALL:
		_hint = "Plošinu tvoří jen zdi — na %s zeď není." % cell
		return
	if _platform_selection.has(cell):
		_platform_selection.erase(cell)
	else:
		_platform_selection.append(cell)
	view.set_platform_selection(_platform_selection)

func _on_create_platform(pose_b: Vector3i, weight_limit: int, cabinets: Array,
		control_units: Array) -> void:
	if _platform_selection.is_empty():
		_hint = "Nejdřív vyber buňky plošiny (nástroj „Výběr buněk plošiny\")."
		return
	session.run(EditorOperation.AddPlatform.new(_platform_selection, pose_b,
			weight_limit, cabinets, control_units))
	_clear_platform_selection()
	view.rebuild()
	_refresh_status()

func _clear_platform_selection() -> void:
	_platform_selection.clear()
	view.set_platform_selection(_platform_selection)

func _on_create_pump(reservoir_a: int, reservoir_b: int, cabinets: Array,
		control_unit: int, bidirectional: bool, default_direction: int) -> void:
	if reservoir_a < 0 or reservoir_b < 0:
		_hint = "Čerpadlo potřebuje dvě nádrže — nejdřív je v levelu vytvoř."
		return
	if reservoir_a == reservoir_b:
		_hint = "Čerpadlo musí spojovat dvě různé nádrže."
		return
	session.run(EditorOperation.AddPump.new(reservoir_a, reservoir_b, cabinets,
			control_unit, bidirectional, default_direction))
	view.rebuild()
	_refresh_status()

func _on_remove_mechanism(kind: String, index: int) -> void:
	match kind:
		"device":
			if index >= 0 and index < session.level.devices.size():
				session.run(EditorOperation.RemoveDevice.new(session.level.devices[index].cell))
		"reservoir":
			if index >= 0 and index < session.level.reservoirs.size():
				session.run(EditorOperation.RemoveReservoir.new(
						session.level.reservoirs[index].anchor))
		"platform":
			session.run(EditorOperation.RemovePlatform.new(index))
		"pump":
			session.run(EditorOperation.RemovePump.new(index))
	view.rebuild()
	_refresh_status()

func _erase_at(cell: Vector3i) -> void:
	if not session.level.is_inside(cell):
		return
	var robot_index := session.level.robot_at(cell)
	if robot_index != -1:
		session.run(EditorOperation.RemoveRobotRenumber.new(session.level.robots[robot_index].kind))
		return
	if session.level.item_at(cell) != GridTypes.NO_ITEM:
		session.run(EditorOperation.RemoveItem.new(cell))
		return
	# Zařízení mizí i s kostkou zdi, ve které sedí; nádrž se maže kliknutím
	# na kteroukoli buňku své dutiny.
	if session.device_index_at(cell) != -1:
		session.run(EditorOperation.RemoveDevice.new(cell))
		return
	var platform_index := session.platform_index_at(cell)
	if platform_index != -1:
		session.run(EditorOperation.RemovePlatform.new(platform_index))
		return
	var reservoir_index := session.reservoir_index_at(cell)
	if reservoir_index != -1:
		session.run(EditorOperation.RemoveReservoir.new(
				session.level.reservoirs[reservoir_index].anchor))
		return
	if session.level.block_at(cell) != GridTypes.BlockType.EMPTY:
		session.run(EditorOperation.SetCell.new(cell, GridTypes.BlockType.EMPTY))

func _on_rotate() -> void:
	_orientation = GridTypes.turn_right(_orientation)
	ui.set_status("Orientace: %s" % GridTypes.Direction.keys()[_orientation])

func _on_undo() -> void:
	session.undo()
	view.rebuild()
	_refresh_status()

func _on_redo() -> void:
	session.redo()
	view.rebuild()
	_refresh_status()

func _on_save(path: String) -> void:
	if not path.ends_with(".ncr"):
		path += ".ncr"
	var error := session.save_to_file(path)
	if error == OK:
		_current_level_path = path
		ui.set_status("Uloženo: %s" % path.get_file())
	else:
		ui.set_status("Uložení selhalo (chyba %d)" % error)

func _on_load(path: String) -> void:
	var error := session.load_from_file(path)
	if error == "":
		_current_level_path = path
		_clear_platform_selection()
		view.show_level(session.level)
		camera.center_on(session.level)
		ui.set_status("Načteno: %s" % path.get_file())
	else:
		ui.set_status("Načtení selhalo: %s" % error)
	view.rebuild()

func _on_new_level(size: Vector3i) -> void:
	session = EditorSession.new(LevelData.create_empty(size))
	_current_level_path = ""
	_clear_platform_selection()
	view.show_level(session.level)
	camera.center_on(session.level)
	_refresh_status()

# ── Umístění ve světě (§7.3 import-assets.md) ───────────────────────────────

func _on_world_placement_requested() -> void:
	if _current_level_path == "":
		_hint = "Nejdřív level ulož — pozice ve světě se váže na uložený soubor."
		_refresh_status()
		return
	var campaign := CampaignMap.new()
	campaign.load_from_file()
	var existing = campaign.get_position(_current_level_path)

	set_active(false)
	_world_placement = WorldPlacementController.new()
	add_child(_world_placement)
	_world_placement.confirmed.connect(_on_world_placement_confirmed)
	_world_placement.cancelled.connect(_on_world_placement_cancelled)
	var footprint := Vector2(session.level.size.x, session.level.size.z) * WorldView.CELL_SIZE \
			* LevelController.LEVEL_SCALE_IN_WORLD
	_world_placement.start_at(
			existing if existing != null else Vector3.ZERO, existing != null, footprint)

func _on_world_placement_confirmed(position: Vector3) -> void:
	var campaign := CampaignMap.new()
	campaign.load_from_file()
	campaign.set_position(_current_level_path, position)
	var error := campaign.save_to_file()
	_close_world_placement()
	if error == OK:
		ui.set_status("Umístění ve světě uloženo: %s" % position)
	else:
		ui.set_status("Uložení umístění selhalo (chyba %d)" % error)

func _on_world_placement_cancelled() -> void:
	_close_world_placement()

func _close_world_placement() -> void:
	_world_placement.queue_free()
	_world_placement = null
	set_active(true)

func _on_play() -> void:
	var problems := session.validate()
	if not problems.is_empty():
		ui.set_status("Nelze přehrát — level je nevalidní:\n" + "\n".join(problems))
		return
	play_requested.emit(session.start_playtest(), _saved_world_position())

## Pozice levelu v krajině (viz "Umístit ve světě…"), nebo null, když ji
## level nemá (nebo ještě nebyl uložený) — §7.3 import-assets.md.
func _saved_world_position() -> Variant:
	if _current_level_path == "":
		return null
	var campaign := CampaignMap.new()
	campaign.load_from_file()
	return campaign.get_position(_current_level_path)

func _refresh_status() -> void:
	ui.set_mechanism_data(_mechanism_data())
	var problems := session.validate()
	var text := "Level je platný." if problems.is_empty() \
			else "Problémy:\n" + "\n".join(problems)
	if _hint != "":
		text = _hint + "\n" + text
		_hint = ""
	ui.set_status(text)

## Popisy mechanismů pro nabídky a seznam v UI. UI nezná pravidla ani
## datový model — dostane hotové dvojice [index, popis].
func _mechanism_data() -> Dictionary:
	var level := session.level
	var cabinets: Array = []
	var control_units: Array = []
	var devices: Array = []
	for i in level.devices.size():
		var device = level.devices[i]
		var detail := "%d — %s %s, přístup %s" % [i,
				String(EditorUi.DEVICE_LABELS.get(device.kind, "?")), device.cell,
				String(EditorUi.DIRECTION_LABELS.get(device.access_direction, "?"))]
		if device.kind == GridTypes.DeviceKind.CONTROL_UNIT:
			detail += ", %s" % String(EditorUi.CONTROL_MODE_LABELS.get(device.control_mode, "?"))
		if device.is_broken:
			detail += " (rozbité)"
		if device.kind == GridTypes.DeviceKind.CONTROL_UNIT:
			control_units.append([i, detail])
		else:
			cabinets.append([i, detail])
		devices.append([i, detail])

	var reservoirs: Array = []
	for i in level.reservoirs.size():
		var res = level.reservoirs[i]
		var capacity := session.reservoir_capacity(i)
		var fill := "neomezená" if res.unlimited \
				else ("%d/%d jednotek" % [res.volume_units, capacity] if capacity >= 0
						else "bez dutiny!")
		reservoirs.append([i, "%d — kotva %s, %s" % [i, res.anchor, fill]])

	var platforms: Array = []
	for i in level.platforms.size():
		var platform = level.platforms[i]
		var mode := "automatická" if platform.linked_control_units.is_empty() else "manuální"
		platforms.append([i, "%d — %d buněk, posun %s, práh %d, %s"
				% [i, platform.cells.size(), platform.pose_b, platform.weight_limit, mode]])

	var pumps: Array = []
	for i in level.pumps.size():
		var pump = level.pumps[i]
		var arrow := "%d → %d" % [pump.reservoir_a, pump.reservoir_b] \
				if pump.default_direction == 0 else "%d → %d" % [pump.reservoir_b, pump.reservoir_a]
		if pump.bidirectional:
			arrow += " (obousměrné)"
		var mode := "automatické" if pump.linked_control_unit == -1 else "manuální"
		pumps.append([i, "%d — nádrže %s, %s" % [i, arrow, mode]])

	return {
		"devices": devices,
		"cabinets": cabinets,
		"control_units": control_units,
		"reservoirs": reservoirs,
		"platforms": platforms,
		"pumps": pumps,
		"platform_selection": _platform_selection.size(),
	}

## Krokuje paprsek od kamery skrz mřížku a najde první pevnou buňku.
## `place_cell` je poslední prázdná buňka před ní (kam se dá něco položit),
## `solid_cell` je buňka, na kterou hráč klikl (co se dá smazat).
##
## Ohraničující box má okraj o PICK_MARGIN buněk navíc jen proto, aby bylo
## kam umístit start paprsku, když je kamera mimo skutečný level — samotný
## okraj ale (na rozdíl od dřívější verze) NENÍ brán jako pevný, jinak by
## paprsek narazil na okrajovou buňku hned při vstupu do boxu a nikdy by se
## nedostal ke skutečným buňkám uvnitř. Pevná je proto jen skutečná buňka
## uvnitř levelu a virtuální podlaha těsně pod mřížkou (viz _is_pick_solid).
func _pick() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.camera.project_ray_origin(mouse)
	var dir := camera.camera.project_ray_normal(mouse)

	var lo := Vector3(-PICK_MARGIN, -PICK_MARGIN, -PICK_MARGIN) * EditorView.CELL_SIZE
	var hi := (Vector3(session.level.size) + Vector3.ONE * PICK_MARGIN) * EditorView.CELL_SIZE
	var aabb := AABB(lo, hi - lo)

	var start := from
	if not aabb.has_point(from):
		var entry = aabb.intersects_ray(from, dir)
		if entry == null:
			return {"hit": false}
		start = entry

	var max_dist := (hi - lo).length()
	var steps := int(max_dist / PICK_STEP)
	var prev_cell := _cell_at(start - dir * PICK_STEP)
	for i in steps:
		var point := start + dir * (PICK_STEP * i)
		var cell := _cell_at(point)
		if cell == prev_cell:
			continue
		if _is_pick_solid(cell):
			return {"hit": true, "solid_cell": cell, "place_cell": prev_cell}
		prev_cell = cell
	return {"hit": false}

## Pevné pro účely pickování je skutečný pevný blok uvnitř levelu, nebo
## virtuální podlaha těsně pod mřížkou (y == -1) — díky tomu jde stavět i do
## zcela prázdného, čerstvě založeného levelu.
func _is_pick_solid(cell: Vector3i) -> bool:
	if session.level.is_inside(cell):
		return GridTypes.is_solid(session.level.block_at(cell))
	return cell.y == -1 and cell.x >= 0 and cell.x < session.level.size.x \
			and cell.z >= 0 and cell.z < session.level.size.z

func _cell_at(point: Vector3) -> Vector3i:
	return Vector3i(
		floori(point.x / EditorView.CELL_SIZE),
		floori(point.y / EditorView.CELL_SIZE),
		floori(point.z / EditorView.CELL_SIZE))
