class_name EditorView
extends Node3D

## Vizualizace LevelData v editoru (placeholder, §20.1). Na rozdíl od
## WorldView, které kreslí WorldState a průběžně se aktualizuje podle
## událostí, tady se celá scéna jednoduše přestaví po každé editační
## operaci — levely v editoru jsou malé, výkon není problém.

const CELL_SIZE := WorldView.CELL_SIZE
const RESIZE_HANDLE_RADIUS := 0.28

var level: LevelData

var _content: Node3D
var _cursor: MeshInstance3D
var _mesh_cache: Dictionary = {} # block_type -> Mesh
var _platform_selection: Array = [] # Vector3i, rozestavěná plošina
var _resize_handles: Array = [] # {direction:int, grow:bool, position:Vector3, radius:float}

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
	_build_water()
	_build_devices()
	_build_platforms()
	_build_pumps()
	_build_platform_selection()
	_build_resize_handles()

## Rozklikávací prvky pro rozšíření/zúžení levelu o řadu, jeden pár
## (zelený = rozšířit, červený = zúžit) u okraje pro každý směr z
## EditorSession.RESIZABLE_DIRECTIONS (design dok. §2.2.1). EditorController
## na ně hází vlastní paprsek (stejně jako `_pick()` u mřížky), proto tu není
## potřeba žádná kolizní forma — jen si drží středy a poloměr.
func resize_handles() -> Array:
	return _resize_handles

## Rozestavěná plošina (buňky vybrané nástrojem, ještě nepotvrzené).
func set_platform_selection(cells: Array) -> void:
	_platform_selection = cells.duplicate()
	rebuild()

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
	WorldView.add_sun_and_sky(self)

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
	var mesh: Mesh = WorldView.ramp_mesh() if block_type == GridTypes.BlockType.RAMP else null
	if mesh == null:
		var color: Color = WorldView.BLOCK_COLORS.get(block_type, Color.MAGENTA)
		var texture: Texture2D = WorldView.BLOCK_TEXTURES.get(block_type)
		var box := BoxMesh.new()
		box.size = Vector3(CELL_SIZE, CELL_SIZE * (0.5 if block_type == GridTypes.BlockType.RAMP else 1.0), CELL_SIZE)
		var material := StandardMaterial3D.new()
		if texture != null:
			material.albedo_texture = texture
		else:
			material.albedo_color = color
		box.material = material
		mesh = box
	_mesh_cache[block_type] = mesh
	return mesh

func _build_blocks() -> void:
	var ramp_has_model := WorldView.ramp_mesh() != null
	for index in level.cell_count():
		var block: int = level.blocks[index]
		if block == GridTypes.BlockType.EMPTY:
			continue
		var cell := level.index_to_cell(index)
		var node := MeshInstance3D.new()
		node.mesh = _mesh_for(block)
		var offset := Vector3.ZERO
		if block == GridTypes.BlockType.RAMP and not ramp_has_model:
			offset = Vector3(0, -CELL_SIZE * 0.25, 0)
		node.position = WorldView.cell_to_position(cell) + offset
		# Stejné znaménko jako u robotů/zařízení (facing_to_yaw), ne obrácené —
		# šikmina teď má reálný nesymetrický model, takže na tom závisí, jestli
		# stoupá tam, kam říkají data (§2.3 import-assets).
		node.rotation.y = WorldView.facing_to_yaw(level.orientation_at(cell))
		_content.add_child(node)

## Roboti se v editoru kreslí stejně jako ve hře (týž RobotView), aby autor
## levelu viděl, co pak uvidí hráč — navíc jen jmenovka nad modelem.
func _build_robots() -> void:
	for placement in level.robots:
		var node := RobotView.create(placement.kind,
				WorldView.ROBOT_COLORS.get(placement.kind, Color.WHITE))
		node.position = WorldView.cell_to_position(placement.cell)
		node.rotation.y = WorldView.facing_to_yaw(placement.facing)
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

# ── Mechanismy (§13) ───────────────────────────────────────────────────────

## Voda v nádržích. Hladina je odvozená veličina (§9.2) — editor ji počítá
## přes tentýž WorldState, jaký postaví runtime, takže autor levelu vidí
## přesně to, co uvidí hráč.
func _build_water() -> void:
	if level.reservoirs.is_empty():
		return
	var world := WorldState.from_level(level)
	for i in world.reservoirs.size():
		var res: ReservoirState = world.reservoirs[i]
		for cell: Vector3i in res.cells:
			var depth := world.water_depth_at(cell)
			var shown := depth != GridTypes.WaterDepth.DRY or res.unlimited
			if not shown:
				continue
			var above: Vector3i = cell + GridTypes.UP_VECTOR
			var above_shown := res.has_cell(above) and \
					(world.water_depth_at(above) != GridTypes.WaterDepth.DRY or res.unlimited)
			if above_shown:
				continue # pod hladinou, nezvýrazňovat
			var block := world.block_at(cell)
			if block != GridTypes.BlockType.EMPTY and block != GridTypes.BlockType.RAMP:
				continue # led nebo jiný blok na hladině už buňku zabírá vizuálně; šikmina nemá
				# tvar kostky, takže s hladinou neglitchuje a smí se zobrazit i nad ní
			_content.add_child(WorldView.make_water_surface(cell, depth == GridTypes.WaterDepth.DEEP))
		_add_marker(res.anchor, Color(0.2, 0.5, 1.0), "Nádrž %d" % i)

func _build_devices() -> void:
	for i in level.devices.size():
		var device = level.devices[i]
		if not level.is_inside(device.cell):
			continue
		var is_cabinet: bool = device.kind == GridTypes.DeviceKind.POWER_CABINET
		var color := Color(1.0, 0.75, 0.15) if is_cabinet else Color(0.6, 0.9, 0.4)
		if device.is_broken:
			color = Color(0.8, 0.25, 0.25)
		_add_translucent_box(device.cell, color, 1.04)
		var name := "Skříň %d" if is_cabinet else "Jednotka %d"
		_add_marker(device.cell, color, name % i)
		# Šipka ukazuje, ze které buňky se dá zařízení ovládat (§13.1).
		_add_line(WorldView.cell_to_position(device.cell),
				WorldView.cell_to_position(device.cell + GridTypes.dir_vector(
						device.access_direction)), color)

func _build_platforms() -> void:
	for i in level.platforms.size():
		var platform = level.platforms[i]
		for cell in platform.cells:
			var at_a: Vector3i = cell + platform.pose_a
			var at_b: Vector3i = cell + platform.pose_b
			_add_translucent_box(at_a, Color(0.9, 0.4, 0.9, 0.3), 1.05)
			# Druhá poloha jako duch — dráha mezi polohami musí zůstat volná (V8).
			_add_translucent_box(at_b, Color(0.9, 0.4, 0.9, 0.15), 0.9)
			_add_line(WorldView.cell_to_position(at_a), WorldView.cell_to_position(at_b),
					Color(0.9, 0.4, 0.9))
		if not platform.cells.is_empty():
			_add_marker(platform.cells[0] + platform.pose_a, Color(0.9, 0.4, 0.9),
					"Plošina %d" % i)

## Čerpadlo je abstraktní vazba mezi dvěma nádržemi (vzdálenost neomezená,
## model nepovinný — design dok. §2.2.1); v editoru se kreslí jako spojnice
## kotevních buněk.
func _build_pumps() -> void:
	for i in level.pumps.size():
		var pump = level.pumps[i]
		if pump.reservoir_a >= level.reservoirs.size() or pump.reservoir_b >= level.reservoirs.size():
			continue
		if pump.reservoir_a < 0 or pump.reservoir_b < 0:
			continue
		var from: Vector3i = level.reservoirs[pump.reservoir_a].anchor
		var to: Vector3i = level.reservoirs[pump.reservoir_b].anchor
		_add_line(WorldView.cell_to_position(from), WorldView.cell_to_position(to),
				Color(0.2, 0.9, 0.9))
		_add_marker(from, Color(0.2, 0.9, 0.9), "Čerpadlo %d →" % i)

func _build_resize_handles() -> void:
	_resize_handles.clear()
	var full := Vector3(level.size) * CELL_SIZE
	var half := full * 0.5
	for direction in EditorSession.RESIZABLE_DIRECTIONS:
		for grow in [true, false]:
			var position := _resize_handle_position(direction, grow, full, half)
			_resize_handles.append({"direction": direction, "grow": grow,
					"position": position, "radius": RESIZE_HANDLE_RADIUS})
			_add_resize_handle_marker(position, grow)

## Zelený prvek sedí kousek za okrajem levelu (rozšíření), červený kousek
## před ním, ještě uvnitř (zúžení) — oba uprostřed příslušné stěny/hrany.
func _resize_handle_position(direction: int, grow: bool, full: Vector3, half: Vector3) -> Vector3:
	var gap := CELL_SIZE * 0.5
	var outward := gap if grow else -gap
	match direction:
		GridTypes.Direction.EAST:
			return Vector3(full.x + outward, half.y, half.z)
		GridTypes.Direction.WEST:
			return Vector3(-outward, half.y, half.z)
		GridTypes.Direction.SOUTH:
			return Vector3(half.x, half.y, full.z + outward)
		GridTypes.Direction.NORTH:
			return Vector3(half.x, half.y, -outward)
		_: # UP — DOWN se v RESIZABLE_DIRECTIONS nevyskytuje (dno se nemění)
			return Vector3(half.x, full.y + outward, half.z)

func _add_resize_handle_marker(position: Vector3, grow: bool) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = RESIZE_HANDLE_RADIUS
	mesh.height = RESIZE_HANDLE_RADIUS * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.9, 0.3, 0.9) if grow else Color(0.9, 0.3, 0.3, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	_content.add_child(node)

	var label := Label3D.new()
	label.text = "+" if grow else "-"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.position = position
	_content.add_child(label)

func _build_platform_selection() -> void:
	for cell in _platform_selection:
		_add_translucent_box(cell, Color(1.0, 1.0, 0.3, 0.35), 1.08)

func _add_translucent_box(cell: Vector3i, color: Color, scale: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (CELL_SIZE * scale)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = WorldView.cell_to_position(cell)
	_content.add_child(node)

func _add_marker(cell: Vector3i, color: Color, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = WorldView.cell_to_position(cell) + Vector3(0, 0.6, 0)
	_content.add_child(label)

func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate.surface_add_vertex(from)
	immediate.surface_add_vertex(to)
	immediate.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = immediate
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
