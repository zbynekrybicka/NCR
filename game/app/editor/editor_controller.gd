class_name EditorController
extends Node3D

## Propojuje EditorSession (data, §16) se scénou: EditorView (vykreslení),
## EditorCamera (pohled) a EditorUi (paleta/dialogy). Myš se promítá do
## mřížky obyčejným krokováním paprsku po malých úsecích — stejný princip
## jako CameraRig._clamp_to_grid, ne fyzikální raycast (level nemá kolizní
## tvary, je to čistě datová mřížka).

signal play_requested(simulation: Simulation)
signal menu_requested

enum Tool { BLOCK, ROBOT, ITEM, KEY, ERASE }

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

var _active: bool = true

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
	ui.rotate_pressed.connect(_on_rotate)
	ui.undo_pressed.connect(_on_undo)
	ui.redo_pressed.connect(_on_redo)
	ui.save_requested.connect(_on_save)
	ui.load_requested.connect(_on_load)
	ui.new_level_requested.connect(_on_new_level)
	ui.play_pressed.connect(_on_play)
	ui.menu_pressed.connect(func(): menu_requested.emit())

func _process(_delta: float) -> void:
	if not _active:
		return
	var pick := _pick()
	if not pick.hit:
		view.set_cursor(null, false)
		return
	var target_cell: Vector3i = pick.solid_cell if _tool == Tool.ERASE else pick.place_cell
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
		ui.set_status("Uloženo: %s" % path.get_file())
	else:
		ui.set_status("Uložení selhalo (chyba %d)" % error)

func _on_load(path: String) -> void:
	var error := session.load_from_file(path)
	if error == "":
		view.show_level(session.level)
		camera.center_on(session.level)
		ui.set_status("Načteno: %s" % path.get_file())
	else:
		ui.set_status("Načtení selhalo: %s" % error)
	view.rebuild()

func _on_new_level(size: Vector3i) -> void:
	session = EditorSession.new(LevelData.create_empty(size))
	view.show_level(session.level)
	camera.center_on(session.level)
	_refresh_status()

func _on_play() -> void:
	var problems := session.validate()
	if not problems.is_empty():
		ui.set_status("Nelze přehrát — level je nevalidní:\n" + "\n".join(problems))
		return
	play_requested.emit(session.start_playtest())

func _refresh_status() -> void:
	var problems := session.validate()
	if problems.is_empty():
		ui.set_status("Level je platný.")
	else:
		ui.set_status("Problémy:\n" + "\n".join(problems))

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
