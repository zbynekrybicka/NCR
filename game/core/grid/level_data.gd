class_name LevelData
extends RefCounted

## Statická definice levelu — přesně to, co je v souboru (§5.2).
## Za běhu se nemění; restart levelu znamená postavit z ní nový WorldState.

const FORMAT_VERSION := 1

var format_version: int = FORMAT_VERSION
var size: Vector3i = Vector3i.ZERO
var blocks: PackedByteArray = PackedByteArray()      # block_type na buňku, pořadí §4
var models: PackedInt32Array = PackedInt32Array()    # model_id na buňku
var orientations: PackedByteArray = PackedByteArray() # Direction na buňku
var items: Array = []            # ItemPlacement
var key_position: Vector3i = Vector3i.ZERO
var robots: Array = []           # RobotPlacement
var reservoirs: Array = []       # ReservoirDef
var devices: Array = []          # DeviceDef
var platforms: Array = []        # PlatformDef
var pumps: Array = []            # PumpDef
var level_name: String = ""
var author: String = ""
var created_unix: int = 0


class ItemPlacement extends RefCounted:
	var item_type: int
	var cell: Vector3i

	func _init(p_item_type: int = 0, p_cell: Vector3i = Vector3i.ZERO) -> void:
		item_type = p_item_type
		cell = p_cell

	func duplicate_placement() -> ItemPlacement:
		return ItemPlacement.new(item_type, cell)


class RobotPlacement extends RefCounted:
	var kind: int
	var cell: Vector3i
	var facing: int
	var sequence_index: int

	func _init(p_kind: int = 0, p_cell: Vector3i = Vector3i.ZERO, p_facing: int = 0,
			p_sequence_index: int = 0) -> void:
		kind = p_kind
		cell = p_cell
		facing = p_facing
		sequence_index = p_sequence_index

	func duplicate_placement() -> RobotPlacement:
		return RobotPlacement.new(kind, cell, facing, sequence_index)


class ReservoirDef extends RefCounted:
	## Tvar nádrže se neukládá — odvozuje se z geometrie (§5.2, §9.1).
	## Ukládá se jen kotevní buňka, počáteční objem a příznak neomezenosti.
	var anchor: Vector3i
	var volume_units: int
	var unlimited: bool

	func _init(p_anchor: Vector3i = Vector3i.ZERO, p_volume_units: int = 0,
			p_unlimited: bool = false) -> void:
		anchor = p_anchor
		volume_units = p_volume_units
		unlimited = p_unlimited

	func duplicate_def() -> ReservoirDef:
		return ReservoirDef.new(anchor, volume_units, unlimited)


class DeviceDef extends RefCounted:
	var kind: int                 # GridTypes.DeviceKind
	var control_mode: int         # GridTypes.ControlMode (jen CONTROL_UNIT)
	var cell: Vector3i
	var access_direction: int     # z jaké strany se dá ovládat
	var is_broken: bool

	func _init(p_kind: int = 0, p_control_mode: int = 0, p_cell: Vector3i = Vector3i.ZERO,
			p_access_direction: int = 0, p_is_broken: bool = false) -> void:
		kind = p_kind
		control_mode = p_control_mode
		cell = p_cell
		access_direction = p_access_direction
		is_broken = p_is_broken

	func duplicate_def() -> DeviceDef:
		return DeviceDef.new(kind, control_mode, cell, access_direction, is_broken)


class PlatformDef extends RefCounted:
	var cells: Array = []                  # Vector3i, nemusí sousedit
	var pose_a: Vector3i = Vector3i.ZERO   # offsety, libovolný směr
	var pose_b: Vector3i = Vector3i.ZERO
	var weight_limit: int = 0
	var linked_cabinets: Array = []        # indexy do devices
	var linked_control_units: Array = []   # prázdné → automatická plošina

	func duplicate_def() -> PlatformDef:
		var d := PlatformDef.new()
		d.cells = cells.duplicate()
		d.pose_a = pose_a
		d.pose_b = pose_b
		d.weight_limit = weight_limit
		d.linked_cabinets = linked_cabinets.duplicate()
		d.linked_control_units = linked_control_units.duplicate()
		return d


class PumpDef extends RefCounted:
	## Čerpadlo se napojuje na jednu i víc elektrických skříní (stejně jako
	## plošina) a případně na jednu řídicí jednotku (design dok. §2.2.1).
	var reservoir_a: int = 0
	var reservoir_b: int = 0
	var bidirectional: bool = false
	var default_direction: int = 0    # 0 = A→B, 1 = B→A
	var linked_cabinets: Array = []   # indexy do devices
	var linked_control_unit: int = -1 # -1 → automatické

	func _init(p_a: int = 0, p_b: int = 0, p_bidirectional: bool = false,
			p_default_direction: int = 0, p_cabinets: Array = [],
			p_control_unit: int = -1) -> void:
		reservoir_a = p_a
		reservoir_b = p_b
		bidirectional = p_bidirectional
		default_direction = p_default_direction
		linked_cabinets = p_cabinets.duplicate()
		linked_control_unit = p_control_unit

	func duplicate_def() -> PumpDef:
		return PumpDef.new(reservoir_a, reservoir_b, bidirectional, default_direction,
				linked_cabinets, linked_control_unit)


# ── Indexace buněk (§4) ────────────────────────────────────────────────────

func cell_count() -> int:
	return size.x * size.y * size.z

## i = y * (x_len * z_width) + z * x_len + x
func cell_index(cell: Vector3i) -> int:
	return cell.y * (size.x * size.z) + cell.z * size.x + cell.x

func index_to_cell(index: int) -> Vector3i:
	var layer := size.x * size.z
	var y := index / layer
	var rest := index % layer
	return Vector3i(rest % size.x, y, rest / size.x)

func is_inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 \
		and cell.x < size.x and cell.y < size.y and cell.z < size.z

func block_at(cell: Vector3i) -> int:
	if not is_inside(cell):
		return GridTypes.BlockType.OUTSIDE
	return blocks[cell_index(cell)]

func set_block(cell: Vector3i, block: int) -> void:
	if is_inside(cell):
		blocks[cell_index(cell)] = block

func orientation_at(cell: Vector3i) -> int:
	if not is_inside(cell):
		return GridTypes.Direction.NORTH
	return orientations[cell_index(cell)]

func set_orientation(cell: Vector3i, dir: int) -> void:
	if is_inside(cell):
		orientations[cell_index(cell)] = dir

func model_at(cell: Vector3i) -> int:
	if not is_inside(cell):
		return 0
	return models[cell_index(cell)]

func set_model(cell: Vector3i, model_id: int) -> void:
	if is_inside(cell):
		models[cell_index(cell)] = model_id

## Vytvoří prázdný level daných rozměrů (vše EMPTY).
static func create_empty(p_size: Vector3i) -> LevelData:
	var level := LevelData.new()
	level.size = p_size
	var n := p_size.x * p_size.y * p_size.z
	level.blocks.resize(n)
	level.blocks.fill(GridTypes.BlockType.EMPTY)
	level.orientations.resize(n)
	level.orientations.fill(GridTypes.Direction.NORTH)
	level.models.resize(n)
	level.models.fill(0)
	return level

## Hluboká kopie — editor si drží originál a náhled hraje nad kopií (§16.1).
func duplicate_level() -> LevelData:
	var copy := LevelData.new()
	copy.format_version = format_version
	copy.size = size
	copy.blocks = blocks.duplicate()
	copy.models = models.duplicate()
	copy.orientations = orientations.duplicate()
	copy.key_position = key_position
	copy.level_name = level_name
	copy.author = author
	copy.created_unix = created_unix
	for it in items:
		copy.items.append(it.duplicate_placement())
	for r in robots:
		copy.robots.append(r.duplicate_placement())
	for res in reservoirs:
		copy.reservoirs.append(res.duplicate_def())
	for d in devices:
		copy.devices.append(d.duplicate_def())
	for p in platforms:
		copy.platforms.append(p.duplicate_def())
	for p in pumps:
		copy.pumps.append(p.duplicate_def())
	return copy

func item_at(cell: Vector3i) -> int:
	for it in items:
		if it.cell == cell:
			return it.item_type
	return GridTypes.NO_ITEM

func robot_at(cell: Vector3i) -> int:
	for i in robots.size():
		if robots[i].cell == cell:
			return i
	return -1
