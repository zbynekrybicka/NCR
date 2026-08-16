class_name WorldView
extends Node3D

## Zobrazení světa (§17.1). Scéna se staví z WorldState jednou při načtení
## a dál se upravuje podle událostí. Vizuál je záměrně placeholder (§20.1):
## bloky jsou barevné krychle, roboti rozlišitelné primitivy.

const CELL_SIZE := 1.0

const BLOCK_COLORS := {
	GridTypes.BlockType.WALL: Color(0.55, 0.55, 0.58),
	GridTypes.BlockType.RAMP: Color(0.45, 0.45, 0.50),
	GridTypes.BlockType.DIRT: Color(0.45, 0.32, 0.18),
	GridTypes.BlockType.STONE: Color(0.38, 0.38, 0.40),
	GridTypes.BlockType.ICE: Color(0.65, 0.85, 0.95),
	GridTypes.BlockType.WOOD: Color(0.55, 0.38, 0.20),
	GridTypes.BlockType.TARGET: Color(0.95, 0.80, 0.20),
}

const ROBOT_COLORS := {
	GridTypes.RobotKind.HAN: Color(0.60, 0.40, 0.20),
	GridTypes.RobotKind.DUL: Color(0.20, 0.45, 0.85),
	GridTypes.RobotKind.SET: Color(0.85, 0.25, 0.15),
	GridTypes.RobotKind.NET: Color(0.25, 0.65, 0.30),
	GridTypes.RobotKind.DA: Color(0.85, 0.85, 0.90),
	GridTypes.RobotKind.YEO: Color(0.55, 0.85, 0.95),
	GridTypes.RobotKind.IL: Color(0.90, 0.75, 0.25),
}

## Voda se kreslí stejně jako v editoru (§17.1) — průhledná kostka na každé
## zatopené buňce, sytější v hluboké vodě.
const WATER_COLOR_SHALLOW := Color(0.35, 0.7, 1.0, 0.25)
const WATER_COLOR_DEEP := Color(0.2, 0.45, 0.95, 0.35)

var world: WorldState
var _block_layers: Dictionary = {}   # BlockType -> MultiMeshInstance3D
var _robot_nodes: Array = []         # index robota -> Node3D
var _item_nodes: Dictionary = {}     # Vector3i -> Node3D
var _key_node: Node3D
var _water_root: Node3D

static func cell_to_position(cell: Vector3i) -> Vector3:
	return Vector3(cell) * CELL_SIZE + Vector3.ONE * (CELL_SIZE * 0.5)

func build(p_world: WorldState) -> void:
	world = p_world
	for child in get_children():
		child.queue_free()
	_block_layers.clear()
	_robot_nodes.clear()
	_item_nodes.clear()
	_water_root = null

	for block_type in BLOCK_COLORS.keys():
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = _box_mesh(BLOCK_COLORS[block_type],
				block_type == GridTypes.BlockType.RAMP)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi_mesh
		add_child(instance)
		_block_layers[block_type] = instance

	refresh_blocks()
	_build_robots()
	refresh_items()
	refresh_water()
	_add_light()

func _box_mesh(color: Color, half_height: bool) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, CELL_SIZE * (0.5 if half_height else 1.0), CELL_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	return mesh

func _add_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)

## Bloky se překreslují jen po událostech, které mřížku mění.
func refresh_blocks() -> void:
	var positions: Dictionary = {}
	for block_type in _block_layers.keys():
		positions[block_type] = []
	for index in world.cell_count():
		var block := world.blocks[index]
		if not positions.has(block):
			continue
		positions[block].append(world.index_to_cell(index))

	for block_type in _block_layers.keys():
		var cells: Array = positions[block_type]
		var instance: MultiMeshInstance3D = _block_layers[block_type]
		instance.multimesh.instance_count = cells.size()
		for i in cells.size():
			var offset := Vector3.ZERO
			if block_type == GridTypes.BlockType.RAMP:
				offset = Vector3(0, -CELL_SIZE * 0.25, 0)
			instance.multimesh.set_instance_transform(i,
					Transform3D(Basis.IDENTITY, cell_to_position(cells[i]) + offset))

## Hladina je odvozená veličina (§9.2), ne uložený stav — překreslí se proto
## celá po každé události, která mění objem nebo kapacitu nádrže (voda
## načerpaná/vypuštěná, vykopaná díra v mělčině, roztátý led).
func refresh_water() -> void:
	if _water_root != null and is_instance_valid(_water_root):
		_water_root.queue_free()
	_water_root = null
	if world.reservoirs.is_empty():
		return
	_water_root = Node3D.new()
	add_child(_water_root)
	for res in world.reservoirs:
		for cell in res.cells:
			var depth := world.water_depth_at(cell)
			if depth == GridTypes.WaterDepth.DRY:
				continue
			_add_water_box(cell, WATER_COLOR_DEEP if depth == GridTypes.WaterDepth.DEEP \
					else WATER_COLOR_SHALLOW)

func _add_water_box(cell: Vector3i, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (CELL_SIZE * 0.98)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = cell_to_position(cell)
	_water_root.add_child(node)

func _build_robots() -> void:
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.6, 0.6, 0.6)
		var material := StandardMaterial3D.new()
		material.albedo_color = ROBOT_COLORS.get(robot.kind, Color.WHITE)
		mesh.material = material
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = cell_to_position(robot.cell)
		add_child(node)
		# Malý „nos" ukazující směr pohledu
		var nose := MeshInstance3D.new()
		var nose_mesh := BoxMesh.new()
		nose_mesh.size = Vector3(0.15, 0.15, 0.3)
		nose_mesh.material = material
		nose.mesh = nose_mesh
		nose.position = Vector3(0, 0, -0.4)
		node.add_child(nose)
		node.rotation.y = facing_to_yaw(robot.facing)
		_robot_nodes.append(node)

static func facing_to_yaw(facing: int) -> float:
	match facing:
		GridTypes.Direction.NORTH:
			return 0.0
		GridTypes.Direction.EAST:
			return -PI / 2.0
		GridTypes.Direction.SOUTH:
			return PI
		GridTypes.Direction.WEST:
			return PI / 2.0
	return 0.0

func refresh_items() -> void:
	for node in _item_nodes.values():
		node.queue_free()
	_item_nodes.clear()
	for cell in world.items_on_ground.keys():
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.5, 0.1) \
			if world.items_on_ground[cell] == GridTypes.ItemType.FUEL \
			else Color(0.3, 0.8, 0.9)
		mesh.material = material
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = cell_to_position(cell)
		add_child(node)
		_item_nodes[cell] = node

	if _key_node != null and is_instance_valid(_key_node):
		_key_node.queue_free()
	if world.key_holder == -1:
		var key_mesh := TorusMesh.new()
		key_mesh.inner_radius = 0.1
		key_mesh.outer_radius = 0.2
		var key_material := StandardMaterial3D.new()
		key_material.albedo_color = Color(1.0, 0.85, 0.2)
		key_mesh.material = key_material
		var key_node := MeshInstance3D.new()
		key_node.mesh = key_mesh
		key_node.position = cell_to_position(world.key_position)
		add_child(key_node)
		_key_node = key_node

func robot_node(index: int) -> Node3D:
	if index < 0 or index >= _robot_nodes.size():
		return null
	return _robot_nodes[index]
