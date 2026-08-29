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

## Vygenerované textury (docs/zadani_textury_kostky_urovne_dalle.md) — TARGET
## texturu zatím nemá, zůstává u ploché barvy z BLOCK_COLORS. RAMP tu chybí
## schválně: nese stejnou zed_ocel texturu jako WALL, ale ne jako plochý
## `BoxMesh` materiál — je to UV mapovaná na reálný klínový model, viz
## `ramp_mesh()`.
const BLOCK_TEXTURES := {
	GridTypes.BlockType.WALL: preload("res://assets/level_blocks/textures/zed_ocel.jpg"),
	GridTypes.BlockType.DIRT: preload("res://assets/level_blocks/textures/hlina.jpg"),
	GridTypes.BlockType.STONE: preload("res://assets/level_blocks/textures/kamen.jpg"),
	GridTypes.BlockType.ICE: preload("res://assets/level_blocks/textures/led.jpg"),
	GridTypes.BlockType.WOOD: preload("res://assets/level_blocks/textures/drevo.jpg"),
}

## Šikmina má (na rozdíl od ostatních bloků) reálný model z Blenderu
## (`blender/level_blocks/`, viz README tam) — bokorys pravoúhlého trojúhelníku
## s ocelovou texturou sdílenou se zdí (design dok. §2.1.4, zadání "texturu
## mu dej ocelovou jako u zdí"). Chybějící `.glb` NENÍ chyba: `ramp_mesh()`
## vrátí null a volající použije dosavadní placeholder půlku kostky (§2.4
## import-assets — každý model má fallback).
const RAMP_MODEL_PATH := "res://assets/level_blocks/ramp.glb"
static var _ramp_mesh_cache: Mesh
static var _ramp_mesh_tried: bool = false

static func ramp_mesh() -> Mesh:
	if not _ramp_mesh_tried:
		_ramp_mesh_tried = true
		_ramp_mesh_cache = _extract_mesh(RAMP_MODEL_PATH)
	return _ramp_mesh_cache

## Z GLB (scéna) vytáhne jeden Mesh použitelný v MultiMesh — materiál z
## importu může sedět na uzlu, ne na mesh datech, proto se přenáší ručně.
##
## `instance.mesh` sám o sobě nese jen lokální geometrii DÍLU, ne transformaci
## kořene scény — a právě na kořeni sedí otočka o 180° z `nc.godot_forward()`
## (§2.5 import-assets), díky které model po exportu míří tam, kam má
## (`Direction.NORTH` místo blenderového −Y). Roboti a zařízení tuhle otočku
## dostanou zadarmo, protože se vkládá celý uzel scény (`RobotView`/
## `DeviceView`), ale `MultiMesh` bere jen holý `Mesh` — bez upečení
## `instance.global_transform` do vrcholů by šikmina stoupala přesně opačným
## směrem, než říká `orientation_at()`.
static func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var root := scene.instantiate()
	var mesh: Mesh = null
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var source: Mesh = instance.mesh
		if source == null:
			continue
		var xform := _chain_transform(instance)
		mesh = source if xform.is_equal_approx(Transform3D.IDENTITY) else \
				_bake_transform(source, xform)
		var override := instance.get_surface_override_material(0)
		if override != null:
			mesh.surface_set_material(0, override)
		break
	root.free()
	return mesh

## Složí transformaci uzlu vůči kořeni scény ručně přes lokální `transform`.
## `global_transform` mimo živý `SceneTree` vrací identitu i chybu
## (`Node3D.get_global_transform()` to hlídá přes `is_inside_tree()`) — a
## `scene.instantiate()` žádný live strom nedává, takže na ni tady spoléhat nejde.
static func _chain_transform(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current := node
	while current != null:
		xform = current.transform * xform
		current = current.get_parent() as Node3D
	return xform

## Přepočítá vrcholy a normály meshe do souřadnic daných `xform` a vrátí
## novou (nezávislou) kopii — `source` zůstává nedotčený, protože `mesh`
## resource dané scény může být sdílený.
static func _bake_transform(source: Mesh, xform: Transform3D) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = xform * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if normals.size() > 0:
		var normal_basis := xform.basis.orthonormalized()
		for i in normals.size():
			normals[i] = normal_basis * normals[i]
		arrays[Mesh.ARRAY_NORMAL] = normals
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	baked.surface_set_material(0, source.surface_get_material(0))
	return baked

## Barvy jen pro placeholder, když chybí `.glb` (§2.4 import-assets) — reálný
## model rozlišuje skříň/jednotku tvarem (blesk vs. páka), ne barvou pouzdra.
const DEVICE_COLORS := {
	GridTypes.DeviceKind.POWER_CABINET: Color(0.30, 0.30, 0.33),
	GridTypes.DeviceKind.CONTROL_UNIT: Color(0.26, 0.32, 0.30),
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

## Cíl (TARGET) se místo plné barevné kostky kreslí jako částice světla
## vznikající u podlahy buňky, stoupající k jejímu vrcholu a tam zanikající —
## odděleno od _block_layers, protože každá cílová buňka potřebuje vlastní
## emitor (na rozdíl od ostatních bloků, kterým stačí sdílený MultiMesh).
const TARGET_PARTICLE_COLOR := Color(1.0, 0.85, 0.3)
const TARGET_PARTICLE_SIZE := 0.01
const TARGET_PARTICLE_COUNT := 8
const TARGET_PARTICLE_LIFETIME := 1.0

## Dokud cíl neodemkl nositel klíče (world.target_unlocked, §14), obklopuje
## jeho částice průsvitná "skleněná" kostka — barva podle původní plné
## kostky TARGET z BLOCK_COLORS, jen s nízkou krytím.
const TARGET_LOCK_COLOR := Color(0.95, 0.80, 0.20, 0.28)

var world: WorldState
var _block_layers: Dictionary = {}   # BlockType -> MultiMeshInstance3D
## Vector3i -> {"type": BlockType, "index": int} — kam refresh_blocks() dala
## instanci dané buňky, ať ji EventAnimator umí najít a animovat (plošina).
var _block_cell_index: Dictionary = {}
var _robot_nodes: Array = []         # index robota -> RobotView
var _item_nodes: Dictionary = {}     # Vector3i -> Node3D
var _key_node: Node3D
var _water_root: Node3D
var _target_nodes: Dictionary = {}       # Vector3i -> GPUParticles3D
var _target_particle_mesh: QuadMesh      # sdílený mezi všemi cílovými buňkami
var _target_lock_nodes: Dictionary = {}  # Vector3i -> MeshInstance3D (skleněná kostka)
var _target_lock_mesh: BoxMesh           # sdílený mezi všemi cílovými buňkami
var _device_nodes: Dictionary = {}       # index do world.devices -> DeviceView

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
	_target_nodes.clear()
	_target_lock_nodes.clear()
	_device_nodes.clear()

	for block_type in BLOCK_COLORS.keys():
		if block_type == GridTypes.BlockType.TARGET:
			continue # kreslí se jako částice, viz refresh_targets()
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		if block_type == GridTypes.BlockType.RAMP:
			multi_mesh.mesh = ramp_mesh() if ramp_mesh() != null else \
					_box_mesh(BLOCK_COLORS[block_type], true)
		else:
			multi_mesh.mesh = _box_mesh(BLOCK_COLORS[block_type], false,
					BLOCK_TEXTURES.get(block_type))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi_mesh
		add_child(instance)
		_block_layers[block_type] = instance

	refresh_blocks()
	_build_robots()
	_build_devices()
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
	# Buňka se zařízením nese BlockType.WALL jen kvůli pevnosti/gravitaci
	# (editor_operation.gd PlaceDevice — design dok. §2.2.1: "zařízení se
	# chová jako zeď"), ne kvůli vzhledu. Bez tohohle vyloučení by přes
	# DeviceView prosvítala ještě ocelová kostka bloku ze stejné buňky.
	var device_cells: Dictionary = {}
	for device: DeviceState in world.devices:
		device_cells[device.cell] = true

	var positions: Dictionary = {}
	for block_type in _block_layers.keys():
		positions[block_type] = []
	for index in world.cell_count():
		var block := world.blocks[index]
		if not positions.has(block):
			continue
		var cell := world.index_to_cell(index)
		if device_cells.has(cell):
			continue
		positions[block].append(cell)

	var ramp_has_model := ramp_mesh() != null
	_block_cell_index.clear()
	for block_type in _block_layers.keys():
		var cells: Array = positions[block_type]
		var instance: MultiMeshInstance3D = _block_layers[block_type]
		instance.multimesh.instance_count = cells.size()
		for i in cells.size():
			var offset := Vector3.ZERO
			var basis := Basis.IDENTITY
			if block_type == GridTypes.BlockType.RAMP:
				# Šikmina stoupá ve směru své orientace (§2.3 import-assets) —
				# model se natáčí stejně jako roboti/zařízení podle facing_to_yaw().
				basis = Basis(Vector3.UP, facing_to_yaw(world.orientation_at(cells[i])))
				if not ramp_has_model:
					offset = Vector3(0, -CELL_SIZE * 0.25, 0)
			instance.multimesh.set_instance_transform(i,
					Transform3D(basis, cell_to_position(cells[i]) + offset))
			_block_cell_index[cells[i]] = {"type": block_type, "index": i}

	refresh_targets()

## Kde refresh_blocks() zrovna vykreslil danou buňku — prázdný slovník, když
## na ní žádný typovaný blok není (EMPTY, nebo TARGET jako částice bokem).
## Slouží jen event_animator.gd k rozjetí/dojetí animace přejezdu plošiny —
## instance samotné jsou už na svém finálním místě, animátor je jen dočasně
## odtáhne zpátky na start a nechá dojet přes _process().
func block_multimesh_slot(cell: Vector3i) -> Dictionary:
	if not _block_cell_index.has(cell):
		return {}
	var entry: Dictionary = _block_cell_index[cell]
	return {"multimesh": _block_layers[entry["type"]].multimesh, "index": entry["index"]}

## Cíl nemá vlastní vrstvu v _block_layers (viz build()) — každá buňka s
## TARGET dostane svůj emitor částic, tady se jen dorovná podle aktuální
## mřížky (buňky s TARGET typicky nepřibývají/neubývají za běhu, ale
## refresh_blocks() se volá po každé změně geometrie, tak ať zůstane platné).
func refresh_targets() -> void:
	var wanted: Dictionary = {}
	for index in world.cell_count():
		if world.blocks[index] == GridTypes.BlockType.TARGET:
			wanted[world.index_to_cell(index)] = true

	for cell in _target_nodes.keys():
		if not wanted.has(cell):
			_target_nodes[cell].queue_free()
			_target_nodes.erase(cell)

	for cell in wanted.keys():
		if not _target_nodes.has(cell):
			var particles := _make_target_particles(cell)
			add_child(particles)
			_target_nodes[cell] = particles

	_refresh_target_locks(wanted)

## Průsvitná "skleněná" kostka kolem zamčeného cíle — zmizí, jakmile
## world.target_unlocked (odemkne ho nositel klíče vstupem, §14, viz
## Event.EventType.TARGET_UNLOCKED v event_animator.gd).
func _refresh_target_locks(target_cells: Dictionary) -> void:
	if world.target_unlocked:
		for cell in _target_lock_nodes.keys():
			_target_lock_nodes[cell].queue_free()
		_target_lock_nodes.clear()
		return

	for cell in _target_lock_nodes.keys():
		if not target_cells.has(cell):
			_target_lock_nodes[cell].queue_free()
			_target_lock_nodes.erase(cell)

	for cell in target_cells.keys():
		if not _target_lock_nodes.has(cell):
			var glass := _make_target_lock_glass(cell)
			add_child(glass)
			_target_lock_nodes[cell] = glass

func _make_target_lock_glass(cell: Vector3i) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _target_lock_draw_mesh()
	node.position = cell_to_position(cell)
	return node

func _target_lock_draw_mesh() -> BoxMesh:
	if _target_lock_mesh != null:
		return _target_lock_mesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CELL_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = TARGET_LOCK_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_target_lock_mesh = mesh
	return mesh

## Emitor jedné cílové buňky — částice vznikají na ploché "krabici" u dna
## buňky a stoupají rovnou vzhůru; rychlost je odvozená tak, aby buňku
## (výšky CELL_SIZE) přesně projely za TARGET_PARTICLE_LIFETIME sekund.
## amount/lifetime bez explosiveness rozloží vznik částic rovnoměrně v čase,
## takže je jich živých najednou přibližně TARGET_PARTICLE_COUNT (5-10, viz
## zadání) — preprocess navíc scénu "nahřeje", ať jsou vidět hned od startu.
func _make_target_particles(cell: Vector3i) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = TARGET_PARTICLE_COUNT
	particles.lifetime = TARGET_PARTICLE_LIFETIME
	particles.preprocess = TARGET_PARTICLE_LIFETIME
	particles.explosiveness = 0.0
	particles.randomness = 0.1
	particles.draw_pass_1 = _target_particle_draw_mesh()
	particles.process_material = _target_particle_process_material()
	particles.position = cell_to_position(cell) - Vector3(0, CELL_SIZE * 0.5, 0)
	return particles

func _target_particle_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 4.0
	material.gravity = Vector3.ZERO
	var speed := CELL_SIZE / TARGET_PARTICLE_LIFETIME
	material.initial_velocity_min = speed * 0.9
	material.initial_velocity_max = speed * 1.1
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(CELL_SIZE * 0.4, 0.0, CELL_SIZE * 0.4)
	# Krátce se rozjasní při vzniku a ztlumí těsně před zánikem u vrcholu
	# kostky, místo aby beze změny zmizely (§ zadání: "zanikají").
	var fade := Gradient.new()
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	material.color_ramp = fade_texture
	return material

## Billboard čtverec sdílený všemi cílovými emitory — kreslí malou jasnou
## tečku (TARGET_PARTICLE_SIZE, viz zadání) obklopenou paprsky do kříže a
## měkkou září, aditivním mísením jako u pozorování hvězd na noční obloze.
func _target_particle_draw_mesh() -> QuadMesh:
	if _target_particle_mesh != null:
		return _target_particle_mesh
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * (TARGET_PARTICLE_SIZE * 8.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = TARGET_PARTICLE_COLOR
	material.albedo_texture = _target_star_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = material
	_target_particle_mesh = mesh
	return mesh

## Bílá (tónovaná až materiálem) textura hvězdičky: plná tečka uprostřed +
## kontinuální radiální záře + čtyři tenké paprsky do kříže, vše kódováno do
## alfy, aby ji šlo aditivně sečíst s pozadím.
func _target_star_texture() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) / 2.0
	var half := size / 2.0
	for y in size:
		for x in size:
			var dx := (x - center) / half
			var dy := (y - center) / half
			var d := Vector2(dx, dy).length()
			var core: float = clamp(1.0 - d / 0.14, 0.0, 1.0)
			var glow: float = pow(clamp(1.0 - d, 0.0, 1.0), 3.0)
			var ray_x: float = exp(-absf(dy) * 22.0) * clamp(1.0 - absf(dx), 0.0, 1.0)
			var ray_y: float = exp(-absf(dx) * 22.0) * clamp(1.0 - absf(dy), 0.0, 1.0)
			var alpha: float = clamp(core + glow * 0.6 + max(ray_x, ray_y) * 0.7, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

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
			var block := world.block_at(cell)
			if block != GridTypes.BlockType.EMPTY and block != GridTypes.BlockType.RAMP:
				continue # led nebo jiný blok na hladině už buňku zabírá vizuálně; šikmina nemá
				# tvar kostky, takže s hladinou neglitchuje a smí se zobrazit i nad ní
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

## Zařízení mají stav (`is_broken`, `is_on`, poloha páky) a nesmí jet přes
## `MultiMesh` (§4.3 import-assets — "A10", dosavadní díra ve vykreslování).
## Uzel se staví na `device.cell` a natočí podle `access_direction` — přesně
## jak `_build_robots()` natáčí robota podle `robot.facing`, protože čelo
## modelu (dvířka/páka) má koukat na buňku, ze které Il zařízení ovládá.
func _build_devices() -> void:
	for node in _device_nodes.values():
		node.queue_free()
	_device_nodes.clear()
	for i in world.devices.size():
		var device: DeviceState = world.devices[i]
		var node := DeviceView.create(device.kind, DEVICE_COLORS.get(device.kind, Color.WHITE))
		node.position = cell_to_position(device.cell)
		node.rotation.y = facing_to_yaw(device.access_direction)
		add_child(node)
		_device_nodes[i] = node
	refresh_devices()

## Volá se po `build()` a po každé události, která může zařízení ovlivnit
## (`DEVICE_TOGGLED`, `DEVICE_REPAIRED`, `PLATFORM_MOVED` — event_animator.gd).
## Počet zařízení se za běhu nemění, pozice ano (viz `node.position` níže).
func refresh_devices() -> void:
	for i in world.devices.size():
		if not _device_nodes.has(i):
			continue
		var device: DeviceState = world.devices[i]
		var node: DeviceView = _device_nodes[i]
		# Zařízení v kostce transportní plošiny jede s ní (devices.gd:164) —
		# dorovnat i pozici, ne jen stav, ať PLATFORM_MOVED nenechá zařízení viset.
		node.position = cell_to_position(device.cell)
		if device.kind == GridTypes.DeviceKind.POWER_CABINET:
			node.update_cabinet(device.is_broken, device.is_on)
		else:
			node.update_control_unit(_control_unit_pose(i))

## CONTROL_UNIT sám o sobě žádný trvalý stav nenese (sepnutí je jednorázové,
## §13.1) — páka proto ukazuje polohu mechanismu, který ovládá: plošinu
## (`current_pose`) nebo čerpadlo (`current_direction`). Bez napojení (nebo
## u BUTTONu bez napojeného stavu) zůstává v poloze 0.
func _control_unit_pose(device_index: int) -> int:
	for platform: PlatformState in world.platforms:
		if platform.linked_control_units.has(device_index):
			return platform.current_pose
	for pump: PumpState in world.pumps:
		if pump.linked_control_unit == device_index:
			return pump.current_direction
	return 0

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

## Pro EventAnimator (animace přejezdu plošiny) — uzly zůstávají stabilní
## mezi refresh_devices() voláními, na rozdíl od _item_nodes/_key_node, které
## refresh_items() při každém volání staví znovu (viz item_node()/key_node()).
func device_node(index: int) -> Node3D:
	return _device_nodes.get(index)

## Uzel předmětu na dané buňce, pokud tam nějaký leží — volat AŽ PO
## refresh_items(), protože ten uzly (znovu)staví.
func item_node(cell: Vector3i) -> Node3D:
	return _item_nodes.get(cell)

## Uzel volně ležícího klíče, nebo null, když ho už někdo nese — stejně jako
## item_node() platný až po refresh_items().
func key_node() -> Node3D:
	return _key_node
