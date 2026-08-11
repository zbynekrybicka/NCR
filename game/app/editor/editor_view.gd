class_name EditorView
extends Node3D

## Vizualizace LevelData v editoru (placeholder, §20.1). Na rozdíl od
## WorldView, které kreslí WorldState a průběžně se aktualizuje podle
## událostí, tady se celá scéna jednoduše přestaví po každé editační
## operaci — levely v editoru jsou malé, výkon není problém.

const CELL_SIZE := WorldView.CELL_SIZE

var level: LevelData

var _content: Node3D
var _cursor: MeshInstance3D
var _mesh_cache: Dictionary = {} # block_type -> Mesh

func _ready() -> void:
	_content = Node3D.new()
	add_child(_content)
	_add_light()
	_build_cursor()

func show_level(p_level: LevelData) -> void:
	level = p_level
	rebuild()

func rebuild() -> void:
	if level == null:
		return
	for child in _content.get_children():
		child.queue_free()
	_build_bounds()
	_build_blocks()
	_build_robots()
	_build_items()
	_build_key()

## Zvýrazní buňku pod kurzorem (zeleně = platné umístění, červeně = mimo
## level). cell == null skryje kurzor.
func set_cursor(cell, valid: bool) -> void:
	if cell == null:
		_cursor.visible = false
		return
	_cursor.visible = true
	_cursor.position = WorldView.cell_to_position(cell)
	var material: StandardMaterial3D = _cursor.mesh.surface_get_material(0)
	material.albedo_color = Color(0.3, 1.0, 0.3, 0.35) if valid else Color(1.0, 0.3, 0.3, 0.35)

func _add_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)

func _build_cursor() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (CELL_SIZE * 1.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 1.0, 0.3, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, material)
	_cursor = MeshInstance3D.new()
	_cursor.mesh = mesh
	_cursor.visible = false
	add_child(_cursor)

func _build_bounds() -> void:
	var size := Vector3(level.size) * CELL_SIZE
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.6)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var corners := [
		Vector3(0, 0, 0), Vector3(size.x, 0, 0), Vector3(size.x, 0, size.z), Vector3(0, 0, size.z),
		Vector3(0, size.y, 0), Vector3(size.x, size.y, 0),
		Vector3(size.x, size.y, size.z), Vector3(0, size.y, size.z),
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	for edge in edges:
		immediate.surface_add_vertex(corners[edge[0]])
		immediate.surface_add_vertex(corners[edge[1]])
	immediate.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = immediate
	_content.add_child(node)

func _mesh_for(block_type: int) -> Mesh:
	if _mesh_cache.has(block_type):
		return _mesh_cache[block_type]
	var color: Color = WorldView.BLOCK_COLORS.get(block_type, Color.MAGENTA)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, CELL_SIZE * (0.5 if block_type == GridTypes.BlockType.RAMP else 1.0), CELL_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	_mesh_cache[block_type] = mesh
	return mesh

func _build_blocks() -> void:
	for index in level.cell_count():
		var block: int = level.blocks[index]
		if block == GridTypes.BlockType.EMPTY:
			continue
		var cell := level.index_to_cell(index)
		var node := MeshInstance3D.new()
		node.mesh = _mesh_for(block)
		var offset := Vector3.ZERO
		if block == GridTypes.BlockType.RAMP:
			offset = Vector3(0, -CELL_SIZE * 0.25, 0)
		node.position = WorldView.cell_to_position(cell) + offset
		node.rotation.y = -WorldView.facing_to_yaw(level.orientation_at(cell))
		_content.add_child(node)

func _build_robots() -> void:
	for placement in level.robots:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.6, 0.6, 0.6)
		var material := StandardMaterial3D.new()
		material.albedo_color = WorldView.ROBOT_COLORS.get(placement.kind, Color.WHITE)
		mesh.material = material
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = WorldView.cell_to_position(placement.cell)
		node.rotation.y = WorldView.facing_to_yaw(placement.facing)
		var nose := MeshInstance3D.new()
		var nose_mesh := BoxMesh.new()
		nose_mesh.size = Vector3(0.15, 0.15, 0.3)
		nose_mesh.material = material
		nose.mesh = nose_mesh
		nose.position = Vector3(0, 0, -0.4)
		node.add_child(nose)
		var label := Label3D.new()
		label.text = GridTypes.robot_name(placement.kind)
		label.position = Vector3(0, 0.55, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(label)
		_content.add_child(node)

func _build_items() -> void:
	for item in level.items:
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.5, 0.1) if item.item_type == GridTypes.ItemType.FUEL \
				else Color(0.3, 0.8, 0.9)
		mesh.material = material
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = WorldView.cell_to_position(item.cell)
		_content.add_child(node)

func _build_key() -> void:
	if not level.is_inside(level.key_position):
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.1
	mesh.outer_radius = 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.2)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = WorldView.cell_to_position(level.key_position)
	_content.add_child(node)
