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

## Vygenerované textury (docs/zadani_textury_kostky_urovne_dalle.md) — RAMP a
## TARGET textury zatím nemají, zůstávají u ploché barvy z BLOCK_COLORS.
const BLOCK_TEXTURES := {
	GridTypes.BlockType.WALL: preload("res://assets/level_blocks/textures/zed_ocel.jpg"),
	GridTypes.BlockType.DIRT: preload("res://assets/level_blocks/textures/hlina.jpg"),
	GridTypes.BlockType.STONE: preload("res://assets/level_blocks/textures/kamen.jpg"),
	GridTypes.BlockType.ICE: preload("res://assets/level_blocks/textures/led.jpg"),
	GridTypes.BlockType.WOOD: preload("res://assets/level_blocks/textures/drevo.jpg"),
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

## Voda se kreslí stejně jako v editoru (§17.1) — jen hladina, ne celý objem
## pod ní (§9.2): tenká čtvercová deska v horní části kostky u hluboké vody,
## v polovině výšky kostky u mělčiny. Kreslí se jen nejvyšší mokrá buňka v
## každém sloupci nádrže, sytější barvou v hluboké vodě.
const WATER_COLOR_SHALLOW := Color(0.35, 0.7, 1.0, 0.25)
const WATER_COLOR_DEEP := Color(0.2, 0.45, 0.95, 0.35)
const WATER_SURFACE_THICKNESS := CELL_SIZE * 0.04

## Ohrádka lemující půdorys levelu — hranoly o průřezu 0,01 kostky přiléhající
## k okraji mřížky, aby byla vidět hranice hratelné plochy (zejména v
## krajině, kde level nemá vlastní stěny).
const BOUNDARY_THICKNESS := CELL_SIZE * 0.1
const BOUNDARY_COLOR := Color(0.1, 0.1, 0.1)

var world: WorldState
var _block_layers: Dictionary = {}   # BlockType -> MultiMeshInstance3D
var _robot_nodes: Array = []         # index robota -> RobotView
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
				block_type == GridTypes.BlockType.RAMP,
				BLOCK_TEXTURES.get(block_type))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi_mesh
		add_child(instance)
		_block_layers[block_type] = instance

	refresh_blocks()
	_build_robots()
	refresh_items()
	refresh_water()
	_build_boundary_fence()
	_add_light()

func _box_mesh(color: Color, half_height: bool, texture: Texture2D = null) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, CELL_SIZE * (0.5 if half_height else 1.0), CELL_SIZE)
	var material := StandardMaterial3D.new()
	if texture != null:
		material.albedo_texture = texture
	else:
		material.albedo_color = color
	mesh.material = material
	return mesh

func _add_light() -> void:
	add_sun_and_sky(self)

## Modrá obloha + Slunce vrhající stíny (reálné osvětlení scény, na rozdíl
## od placeholder barev bloků/robotů zůstává i toto stejné pro hru i editor
## — sdílené s EditorView, aby autor levelu viděl stejné osvětlení jako hráč).
static func add_sun_and_sky(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.55, 0.9)
	sky_material.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky_material.ground_bottom_color = Color(0.3, 0.28, 0.25)
	sky_material.ground_horizon_color = Color(0.75, 0.85, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	parent.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	parent.add_child(sun)

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
		for cell: Vector3i in res.cells:
			var depth := world.water_depth_at(cell)
			if depth == GridTypes.WaterDepth.DRY:
				continue
			if world.block_at(cell) != GridTypes.BlockType.EMPTY:
				continue # led nebo jiný blok na hladině už buňku zabírá vizuálně
			var above: Vector3i = cell + GridTypes.UP_VECTOR
			if res.has_cell(above) and world.water_depth_at(above) != GridTypes.WaterDepth.DRY:
				continue # pod hladinou, nezvýrazňovat
			_water_root.add_child(make_water_surface(cell, depth == GridTypes.WaterDepth.DEEP))

## Tenká deska hladiny na dané buňce — u hluboké vody přiléhá k horní stěně
## kostky, u mělčiny leží v polovině její výšky. Sdíleno s EditorView, aby
## autor levelu viděl přesně to, co uvidí hráč.
static func make_water_surface(cell: Vector3i, deep: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.98, WATER_SURFACE_THICKNESS, CELL_SIZE * 0.98)
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER_COLOR_DEEP if deep else WATER_COLOR_SHALLOW
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var pos := cell_to_position(cell)
	if deep:
		pos.y += CELL_SIZE * 0.5 - WATER_SURFACE_THICKNESS * 0.5
	node.position = pos
	return node

## Čtyři tenké hranoly podél obvodu půdorysu (X/Z), přiléhající zvenčí k
## okraji mřížky (roh (0,0,0) leží v počátku, viz cell_to_position) — leží
## celé mimo buňky levelu, aby do jeho prostoru nijak nezasahovaly; jen na
## úrovni země, ne celý ohraničující box jako u EditorView._build_bounds.
func _build_boundary_fence() -> void:
	var extent := Vector3(world.size) * CELL_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = BOUNDARY_COLOR
	var half := BOUNDARY_THICKNESS * 0.5
	var bars := [
		[Vector3(extent.x, BOUNDARY_THICKNESS, BOUNDARY_THICKNESS), Vector3(extent.x * 0.5, half, -half)],
		[Vector3(extent.x, BOUNDARY_THICKNESS, BOUNDARY_THICKNESS), Vector3(extent.x * 0.5, half, extent.z + half)],
		[Vector3(BOUNDARY_THICKNESS, BOUNDARY_THICKNESS, extent.z), Vector3(-half, half, extent.z * 0.5)],
		[Vector3(BOUNDARY_THICKNESS, BOUNDARY_THICKNESS, extent.z), Vector3(extent.x + half, half, extent.z * 0.5)],
	]
	for bar in bars:
		var mesh := BoxMesh.new()
		mesh.size = bar[0]
		mesh.material = material
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = bar[1]
		add_child(node)

func _build_robots() -> void:
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		var node := RobotView.create(robot.kind,
				ROBOT_COLORS.get(robot.kind, Color.WHITE))
		node.position = cell_to_position(robot.cell)
		node.rotation.y = facing_to_yaw(robot.facing)
		add_child(node)
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

## Totéž, jen typovaně — pro animace uvnitř modelu (import-assets §4.1).
func robot_view(index: int) -> RobotView:
	return robot_node(index) as RobotView
