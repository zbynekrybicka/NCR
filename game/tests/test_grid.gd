class_name TestGrid
extends TestSuite

## §4 (souřadný systém, iterační pořadí) a §5.1 (tabulky vlastností bloků).

func test_cell_index_order() -> void:
	var level := LevelData.create_empty(Vector3i(3, 2, 4))
	# X nejrychleji, pak Z, pak Y
	t.equal(level.cell_index(Vector3i(0, 0, 0)), 0, "počátek")
	t.equal(level.cell_index(Vector3i(1, 0, 0)), 1, "posun po X")
	t.equal(level.cell_index(Vector3i(0, 0, 1)), 3, "posun po Z je x_len")
	t.equal(level.cell_index(Vector3i(0, 1, 0)), 12, "posun po Y je x_len * z_width")
	t.equal(level.cell_count(), 24, "počet buněk")

func test_index_round_trip() -> void:
	var level := LevelData.create_empty(Vector3i(3, 2, 4))
	for index in level.cell_count():
		t.equal(level.cell_index(level.index_to_cell(index)), index,
				"index → buňka → index (%d)" % index)

func test_outside_is_solid_boundary() -> void:
	var level := LevelData.create_empty(Vector3i(2, 2, 2))
	t.equal(level.block_at(Vector3i(-1, 0, 0)), GridTypes.BlockType.OUTSIDE,
			"mimo level je okraj")
	t.is_true(GridTypes.is_solid(GridTypes.BlockType.OUTSIDE), "okraj je neprůchodný")

func test_directions() -> void:
	t.equal(GridTypes.turn_left(GridTypes.Direction.NORTH), GridTypes.Direction.WEST,
			"vlevo ze severu")
	t.equal(GridTypes.turn_right(GridTypes.Direction.NORTH), GridTypes.Direction.EAST,
			"vpravo ze severu")
	t.equal(GridTypes.turn_around(GridTypes.Direction.NORTH), GridTypes.Direction.SOUTH,
			"čelem vzad ze severu")
	t.equal(GridTypes.dir_vector(GridTypes.Direction.NORTH), Vector3i(0, 0, -1),
			"sever je -Z (Godot forward)")

func test_substep_deltas() -> void:
	var east := GridTypes.Direction.EAST
	t.equal(GridTypes.substep_delta(GridTypes.Substep.FORWARD, east), Vector3i(1, 0, 0),
			"krok vpřed")
	t.equal(GridTypes.substep_delta(GridTypes.Substep.UP_RAMP, east), Vector3i(1, 1, 0),
			"šikmina nahoru")
	t.equal(GridTypes.substep_delta(GridTypes.Substep.DOWN_RAMP, east), Vector3i(1, -1, 0),
			"šikmina dolů")
	t.equal(GridTypes.substep_delta(GridTypes.Substep.UP_VERTICAL, east), Vector3i(0, 1, 0),
			"svisle nahoru")
	t.equal(GridTypes.substep_delta(GridTypes.Substep.DOWN_VERTICAL, east), Vector3i(0, -1, 0),
			"svisle dolů")

func test_block_tables() -> void:
	t.is_true(GridTypes.is_solid(GridTypes.BlockType.ICE), "led je pevný")
	t.is_false(GridTypes.falls(GridTypes.BlockType.ICE), "led nikdy nepadá")
	t.is_true(GridTypes.falls(GridTypes.BlockType.STONE), "kámen padá")
	t.is_true(GridTypes.is_diggable(GridTypes.BlockType.DIRT), "hlínu lze kopat")
	t.is_false(GridTypes.is_diggable(GridTypes.BlockType.STONE), "kámen kopat nelze")
	t.is_true(GridTypes.is_burnable(GridTypes.BlockType.WOOD), "dřevo hoří")
	t.equal(GridTypes.capacity_units(GridTypes.BlockType.EMPTY), 2, "prázdná buňka = 2 jednotky")
	t.equal(GridTypes.capacity_units(GridTypes.BlockType.RAMP), 1, "šikmina = půl kostky")
	t.equal(GridTypes.capacity_units(GridTypes.BlockType.ICE), 0, "led nepojme vodu")

func test_robot_tables() -> void:
	t.equal(GridTypes.robot_mass(GridTypes.RobotKind.DA), 1, "Da váží 1")
	t.equal(GridTypes.robot_mass(GridTypes.RobotKind.HAN), 2, "Han váží 2")
	t.equal(GridTypes.inventory_capacity(GridTypes.RobotKind.DA), 1, "Da unese jeden předmět")
	t.equal(GridTypes.inventory_capacity(GridTypes.RobotKind.NET), 4, "ostatní čtyři")
	t.is_true(GridTypes.can_pick_up(GridTypes.RobotKind.SET, GridTypes.ItemType.FUEL),
			"Set sbírá palivo")
	t.is_false(GridTypes.can_pick_up(GridTypes.RobotKind.HAN, GridTypes.ItemType.FUEL),
			"Han palivo nesbírá")
	t.is_true(GridTypes.can_pick_up(GridTypes.RobotKind.IL, GridTypes.ItemType.SERVICE_KIT),
			"Il sbírá service kit")
	t.is_false(GridTypes.can_enter_water(GridTypes.RobotKind.DA), "Da do vody nesmí")
	t.is_true(GridTypes.can_enter_deep_water(GridTypes.RobotKind.DUL),
			"do hluboké vody smí jen Dul")

func test_level_builder() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "####\n####") \
		.layer(1, ".H>.\n....") \
		.build()
	t.equal(level.size, Vector3i(4, 2, 2), "rozměry z textu")
	t.equal(level.block_at(Vector3i(0, 0, 0)), GridTypes.BlockType.WALL, "podlaha")
	t.equal(level.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.RAMP, "šikmina")
	t.equal(level.orientation_at(Vector3i(2, 1, 0)), GridTypes.Direction.EAST,
			"orientace šikminy")
	t.equal(level.robots.size(), 1, "jeden robot")
	t.equal(level.robots[0].cell, Vector3i(1, 1, 0), "pozice robota")
	t.equal(level.robots[0].kind, GridTypes.RobotKind.HAN, "druh robota")
