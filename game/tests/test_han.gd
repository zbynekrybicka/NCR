class_name TestHan
extends TestSuite

## §7.6 a §11 — tři cíle nahrábnutí a jejich priorita, robot pod kostkou
## blokuje akci, hledání místa dopadu při vysypání korby.

func test_dig_ahead() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".HD.") \
		.simulate()
	var result := action_1(sim)
	t.is_true(result.accepted, "hlínu přímo před sebou lze nahrábnout")
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.EMPTY, "kostka zmizela")
	t.is_true(sim.world.robots[0].hopper_full, "korba je plná")
	t.is_true(result.has_event(Event.EventType.BLOCK_REMOVED), "vznikla událost odebrání")

func test_dig_ahead_below_is_the_common_case() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##D#") \
		.layer(1, ".H..") \
		.simulate()
	var result := action_1(sim)
	t.is_true(result.accepted, "hlína šikmo dolů před robotem")
	t.equal(sim.world.block_at(Vector3i(2, 0, 0)), GridTypes.BlockType.EMPTY, "kostka zmizela")

func test_dig_below_lowers_han() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "###") \
		.layer(1, ".D.") \
		.layer(2, ".H.") \
		.simulate()
	var result := action_1(sim)
	t.is_true(result.accepted, "hlínu pod sebou lze vykopat")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "Han se dostal na nižší úroveň")

func test_dig_needs_empty_hopper() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".HD.") \
		.simulate()
	sim.world.robots[0].hopper_full = true
	var result := action_1(sim)
	t.is_false(result.accepted, "s plnou korbou hrabat nelze")
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.DIRT, "kostka zůstala")

func test_dig_is_blocked_by_robot_below_the_cube() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".HD.") \
		.simulate()
	# Robot přímo pod odebíranou kostkou akci zablokuje (§7.6). Druhého robota
	# do té buňky posadíme napřímo — jinak by tam sama nevznikla stabilní.
	var net := RobotState.new()
	net.kind = GridTypes.RobotKind.NET
	net.cell = Vector3i(2, 0, 0)
	sim.world.robots.append(net)
	var validation := HanDig.new().validate(sim.world, 0)
	t.is_false(validation.ok, "nahrábnutí se neprovede")

func test_dig_finds_nothing() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H..") \
		.simulate()
	var result := action_1(sim)
	t.is_false(result.accepted, "bez hlíny v dosahu se akce neprovede")
	t.is_false(sim.world.robots[0].hopper_full, "a korba zůstane prázdná")

func test_dump_behind() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..H.") \
		.simulate()
	sim.world.robots[0].hopper_full = true
	var result := action_2(sim)
	t.is_true(result.accepted, "korbu lze vysypat za sebe")
	t.equal(sim.world.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.DIRT,
			"vznikla hliněná kostka")
	t.is_false(sim.world.robots[0].hopper_full, "korba je prázdná")

func test_dump_needs_space_behind() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".#H.") \
		.simulate()
	sim.world.robots[0].hopper_full = true
	var result := action_2(sim)
	t.is_false(result.accepted, "zády u zdi vysypat nelze")

func test_dump_falls_to_the_first_solid_ground() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..#.") \
		.layer(2, "..H.") \
		.simulate()
	sim.world.robots[0].hopper_full = true
	var result := action_2(sim)
	t.is_true(result.accepted, "nad propastí kostka spadne dolů")
	t.equal(sim.world.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.DIRT,
			"kostka dopadla až na první pevný podklad")

func test_dump_onto_robot_is_rejected() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".NH.") \
		.simulate()
	sim.world.robots[1].hopper_full = true
	submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1)
	var result := action_2(sim)
	t.is_false(result.accepted, "na jiného robota se vysypat nesmí")

func test_dump_into_water_raises_the_level() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "######\n######\n######") \
		.layer(1, "######\n##...#\n######") \
		.layer(2, "......\n.H....\n......") \
		.facing(GridTypes.RobotKind.HAN, GridTypes.Direction.WEST) \
		.reservoir(Vector3i(2, 1, 1), 2) \
		.simulate()
	sim.world.robots[0].hopper_full = true
	t.equal(sim.world.reservoirs[0].total_capacity(), 6, "nádrž má tři buňky")
	var result := action_2(sim)
	t.is_true(result.accepted, "do nádrže s místem lze vyklopit")
	t.equal(sim.world.block_at(Vector3i(2, 1, 1)), GridTypes.BlockType.DIRT,
			"kostka dopadla do vody")
	t.equal(sim.world.reservoirs[0].volume_units, 4, "objem stoupl o kostku (§9.3)")
	t.is_true(result.has_event(Event.EventType.WATER_VOLUME_CHANGED),
			"změna hladiny se ohlásila")
	# Kostka dopadla přímo na kotevní buňku nádrže — zbytek dutiny musí
	# zůstat platnou nádrží i po _settle()/reidentify (nahlášený bug: voda
	# celé nádrže "zmizela", protože kotva přestala držet vodu).
	t.equal(sim.world.reservoirs[0].cells.size(), 2, "nádrži zbyly dvě buňky")
	t.equal(sim.world.reservoir_at(Vector3i(3, 1, 1)), 0, "sousední buňka pořád patří do nádrže")
	t.is_true(sim.world.water_depth_at(Vector3i(3, 1, 1)) != GridTypes.WaterDepth.DRY,
			"voda ve zbytku nádrže zůstala, nezmizela")

func test_dump_that_would_drown_a_robot_is_rejected() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H..#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 3) \
		.simulate()
	sim.world.robots[0].hopper_full = true
	submit(sim, Command.CommandType.TURN_AROUND)
	var result := action_2(sim)
	t.is_false(result.accepted, "vysypání, které by zvedlo hladinu nad pás, se neprovede")
	t.equal(sim.world.reservoirs[0].volume_units, 3, "hladina zůstala")
