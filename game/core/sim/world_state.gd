class_name WorldState
extends RefCounted

## Běhový stav světa (§5.3). Vše, co se za hru mění.
## Restart levelu = zahodit WorldState a postavit ho znovu z LevelData (§14).

var size: Vector3i = Vector3i.ZERO
var blocks: PackedByteArray = PackedByteArray()
## Orientace bloků (§5.2). Doplněno proti §5.3: běhový stav ji potřebuje,
## protože strom kroku se ptá na natočení šikmin (`ahead_is_ramp_facing_me`).
var orientations: PackedByteArray = PackedByteArray()
var robots: Array = []                       # RobotState
var active_robot_index: int = 0              # index do `robots`
var robot_sequence: Array = []               # pořadí přepínání (indexy robotů)
var items_on_ground: Dictionary = {}         # Vector3i -> ItemType
var key_holder: int = -1                     # index robota, nebo -1
var key_position: Vector3i = Vector3i.ZERO   # platné, když key_holder == -1
var target_unlocked: bool = false
var reservoirs: Array = []                   # ReservoirState
var cell_to_reservoir: PackedInt32Array = PackedInt32Array()
var devices: Array = []                      # DeviceState
var platforms: Array = []                    # PlatformState
var pumps: Array = []                        # PumpState
var finished_robots: Array = []              # roboti, kteří prošli cílem

# ── Stavba ze statických dat ───────────────────────────────────────────────

static func from_level(level: LevelData) -> WorldState:
	var world := WorldState.new()
	world.size = level.size
	world.blocks = level.blocks.duplicate()
	world.orientations = level.orientations.duplicate()
	world.key_position = level.key_position
	world.key_holder = -1
	world.target_unlocked = false

	for placement in level.robots:
		var robot := RobotState.new()
		robot.kind = placement.kind
		robot.cell = placement.cell
		robot.facing = placement.facing
		world.robots.append(robot)

	# robot_sequence = indexy robotů seřazené podle sequence_index (§5.2)
	var order: Array = []
	for i in level.robots.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return level.robots[a].sequence_index < level.robots[b].sequence_index)
	world.robot_sequence = order
	world.active_robot_index = order[0] if not order.is_empty() else -1

	for item in level.items:
		world.items_on_ground[item.cell] = item.item_type

	WaterSystem.identify_reservoirs(world, level.reservoirs)

	for def in level.devices:
		var device := DeviceState.new()
		device.kind = def.kind
		device.control_mode = def.control_mode
		device.cell = def.cell
		device.access_direction = def.access_direction
		device.is_broken = def.is_broken
		world.devices.append(device)

	for def in level.platforms:
		var platform := PlatformState.new()
		platform.cells = def.cells.duplicate()
		platform.pose_a = def.pose_a
		platform.pose_b = def.pose_b
		platform.current_pose = 0
		platform.weight_limit = def.weight_limit
		platform.linked_cabinets = def.linked_cabinets.duplicate()
		platform.linked_control_units = def.linked_control_units.duplicate()
		world.platforms.append(platform)

	for def in level.pumps:
		var pump := PumpState.new()
		pump.reservoir_a = def.reservoir_a
		pump.reservoir_b = def.reservoir_b
		pump.bidirectional = def.bidirectional
		pump.default_direction = def.default_direction
		pump.current_direction = def.default_direction
		pump.linked_cabinets = def.linked_cabinets.duplicate()
		pump.linked_control_unit = def.linked_control_unit
		world.pumps.append(pump)

	return world

# ── Mřížka (§4) ────────────────────────────────────────────────────────────

func cell_count() -> int:
	return size.x * size.y * size.z

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

## Jediná cesta, jak měnit bloky — udržuje kapacitu zasažené nádrže aktuální
## (§20.5 M8: layer_capacity se mění za běhu).
func set_block(cell: Vector3i, block: int) -> void:
	if not is_inside(cell):
		return
	blocks[cell_index(cell)] = block
	var reservoir_index := reservoir_at(cell)
	if reservoir_index != -1:
		WaterSystem.recompute_capacity(self, reservoir_index)

func is_solid_at(cell: Vector3i) -> bool:
	return GridTypes.is_solid(block_at(cell))

func orientation_at(cell: Vector3i) -> int:
	if not is_inside(cell) or orientations.is_empty():
		return GridTypes.Direction.NORTH
	return orientations[cell_index(cell)]

func set_orientation(cell: Vector3i, dir: int) -> void:
	if is_inside(cell) and not orientations.is_empty():
		orientations[cell_index(cell)] = dir

## Šikmina na `cell` stoupá ve směru `dir` (nízká strana je na straně -dir).
func is_ramp_rising_toward(cell: Vector3i, dir: int) -> bool:
	return block_at(cell) == GridTypes.BlockType.RAMP and orientation_at(cell) == dir

## Buňka leží na šikmině — buď je to přímo buňka šikminy (tam robot dojede při
## sestupu), nebo buňka nad ní (tam vyjde při výstupu; validátor sem taky nic
## nepustí, viz V6). V obou případech je robot na ploše šikminy a nesmí tam
## zůstat stát (design dok. §2.1.4 „nelze na ní setrvat").
func is_on_ramp(cell: Vector3i) -> bool:
	return block_at(cell) == GridTypes.BlockType.RAMP \
			or block_at(cell + GridTypes.DOWN_VECTOR) == GridTypes.BlockType.RAMP

# ── Roboti ─────────────────────────────────────────────────────────────────

func robot_at(cell: Vector3i) -> int:
	for i in robots.size():
		var robot: RobotState = robots[i]
		if robot.in_target:
			continue
		if robot.cell == cell:
			return i
	return -1

func active_robot() -> RobotState:
	if active_robot_index < 0 or active_robot_index >= robots.size():
		return null
	return robots[active_robot_index]

func robot(index: int) -> RobotState:
	return robots[index]

## Robot stojí na pevném podkladu (i šikmina je pevný podklad, §5.1).
func has_support_below(cell: Vector3i) -> bool:
	return is_solid_at(cell + GridTypes.DOWN_VECTOR)

# ── Předměty a klíč ────────────────────────────────────────────────────────

func item_at(cell: Vector3i) -> int:
	return int(items_on_ground.get(cell, GridTypes.NO_ITEM))

func has_item_at(cell: Vector3i) -> bool:
	return items_on_ground.has(cell)

func take_item_at(cell: Vector3i) -> int:
	var item := item_at(cell)
	if item != GridTypes.NO_ITEM:
		items_on_ground.erase(cell)
	return item

func put_item_at(cell: Vector3i, item: int) -> void:
	items_on_ground[cell] = item

func key_is_at(cell: Vector3i) -> bool:
	return key_holder == -1 and key_position == cell

# ── Voda ───────────────────────────────────────────────────────────────────

func reservoir_at(cell: Vector3i) -> int:
	if not is_inside(cell):
		return -1
	if cell_to_reservoir.is_empty():
		return -1
	return cell_to_reservoir[cell_index(cell)]

func water_depth_at(cell: Vector3i) -> int:
	return WaterSystem.depth_at(self, cell)

# ── Zařízení ───────────────────────────────────────────────────────────────

func device_at(cell: Vector3i) -> int:
	for i in devices.size():
		if devices[i].cell == cell:
			return i
	return -1

func platform_at(cell: Vector3i) -> int:
	for i in platforms.size():
		if platforms[i].occupied_cells().has(cell):
			return i
	return -1

# ── Cíl a sekvence ─────────────────────────────────────────────────────────

func target_cells() -> Array:
	var out: Array = []
	for index in cell_count():
		if blocks[index] == GridTypes.BlockType.TARGET:
			out.append(index_to_cell(index))
	return out

func active_robots_remaining() -> int:
	return robots.size() - finished_robots.size()

# ── Invarianty I1–I8 (§5.3) ────────────────────────────────────────────────

## Vrátí seznam porušených invariantů (prázdný = vše v pořádku).
func check_invariants() -> Array:
	var problems: Array = []
	var occupied := {}
	for i in robots.size():
		var robot: RobotState = robots[i]
		if robot.in_target:
			continue
		var label := "robot %d (%s)" % [i, robot.name_of()]

		# I1 — uvnitř levelu
		if not is_inside(robot.cell):
			problems.append("I1: %s je mimo level na %s" % [label, robot.cell])
			continue

		# I2 — nejvýš jeden robot v buňce
		if occupied.has(robot.cell):
			problems.append("I2: %s sdílí buňku %s" % [label, robot.cell])
		occupied[robot.cell] = i

		# I3 — robot nestojí v solid bloku (šikmina je průchodný přechod)
		var here := block_at(robot.cell)
		if GridTypes.is_solid(here) and here != GridTypes.BlockType.RAMP:
			problems.append("I3: %s stojí v pevném bloku %d" % [label, here])

		# I4 — hloubka vody ≤ 1/2 kostky u všech kromě Dula
		if robot.kind != GridTypes.RobotKind.DUL:
			if water_depth_at(robot.cell) == GridTypes.WaterDepth.DEEP:
				problems.append("I4: %s je v hluboké vodě" % label)

		# I5 — pevný podklad (kromě Da a Dula ve vodě)
		if robot.kind != GridTypes.RobotKind.DA:
			var in_water := water_depth_at(robot.cell) != GridTypes.WaterDepth.DRY
			var swimming := robot.kind == GridTypes.RobotKind.DUL and in_water
			var on_ramp := here == GridTypes.BlockType.RAMP
			if not swimming and not on_ramp and not has_support_below(robot.cell):
				problems.append("I5: %s nemá pevný podklad" % label)

		# I6 — korba/cisterna jen u Hana a Dula
		if robot.hopper_full and robot.kind != GridTypes.RobotKind.HAN \
				and robot.kind != GridTypes.RobotKind.DUL:
			problems.append("I6: %s má plnou korbu" % label)

		# I7 — kapacita inventáře
		if robot.inventory.size() > robot.inventory_capacity():
			problems.append("I7: %s překročil kapacitu inventáře" % label)

	# I8 — právě jeden klíč
	if key_holder == -1:
		if not is_inside(key_position):
			problems.append("I8: klíč není u robota ani na platné pozici")
	elif key_holder < 0 or key_holder >= robots.size():
		problems.append("I8: key_holder odkazuje na neexistujícího robota")

	return problems
