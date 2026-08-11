class_name TestSetYeo
extends TestSuite

## §7.6 a §9.3 — priorita cílů dřeva, plovoucí kra, vznik a roztavení ledu
## a jejich vliv na hladinu.

func _with_fuel(sim: Simulation, robot_index: int = 0) -> void:
	sim.world.robots[robot_index].inventory.append(GridTypes.ItemType.FUEL)

func test_burn_wood_ahead() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".EW.") \
		.simulate()
	_with_fuel(sim)
	var result := action_1(sim)
	t.is_true(result.accepted, "dřevo před sebou Set spálí")
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.EMPTY,
			"po zničení nezůstane nic")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "palivo se spotřebovalo")

func test_burn_needs_fuel() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".EW.") \
		.simulate()
	t.is_false(action_1(sim).accepted, "bez paliva se nepálí")
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.WOOD,
			"dřevo zůstalo")

func test_burn_nothing_keeps_the_fuel() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".E..") \
		.simulate()
	_with_fuel(sim)
	t.is_false(action_1(sim).accepted, "pálení naprázdno se neprovede")
	t.equal(sim.world.robots[0].inventory.size(), 1, "a palivo zůstává")

func test_wood_priority_is_horizontal_first() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##W#") \
		.layer(1, ".EW.") \
		.simulate()
	_with_fuel(sim)
	action_1(sim)
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.EMPTY,
			"vodorovné dřevo má přednost")
	t.equal(sim.world.block_at(Vector3i(2, 0, 0)), GridTypes.BlockType.WOOD,
			"šikmé zůstalo nedotčené")

func test_wood_above() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "###") \
		.layer(1, ".E.") \
		.layer(2, ".W.") \
		.simulate()
	_with_fuel(sim)
	t.is_true(action_1(sim).accepted, "svislé dřevo nad sebou Set taky spálí")
	t.equal(sim.world.block_at(Vector3i(1, 2, 0)), GridTypes.BlockType.EMPTY, "zmizelo")

func test_melting_would_leave_a_floating_raft() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "###.") \
		.layer(1, ".#II") \
		.layer(2, ".E..") \
		.simulate()
	_with_fuel(sim)
	var result := action_1(sim)
	t.is_false(result.accepted, "roztavení nosné kostky ledu se neprovede")
	t.equal(sim.world.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.ICE, "led zůstal")
	t.equal(sim.world.robots[0].inventory.size(), 1, "a palivo taky")

func test_melting_ice_does_not_move_the_level() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##I.#\n#####") \
		.layer(2, "#####\n#E..#\n#####") \
		.reservoir(Vector3i(3, 1, 1), 2) \
		.simulate()
	_with_fuel(sim)
	var res: ReservoirState = sim.world.reservoirs[0]
	var surface_before := WaterSystem.surface(res)
	t.equal(res.total_capacity(), 8, "led kapacitu nenese")

	var result := action_1(sim)
	t.is_true(result.accepted, "led šikmo dolů před Setem lze roztavit")
	t.equal(sim.world.block_at(Vector3i(2, 1, 1)), GridTypes.BlockType.EMPTY, "led je pryč")
	t.equal(res.volume_units, 4, "objem stoupl o kostku")
	t.equal(res.total_capacity(), 10, "kapacita stoupla o stejnou kostku")
	t.equal(WaterSystem.surface(res), surface_before, "hladina se nepohnula (§9.3 pozn. 1)")
	t.is_true(result.has_event(Event.EventType.ICE_MELTED), "událost roztavení")

func test_yeo_freezes_water_ahead() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, "#####\n#Y..#\n#####") \
		.reservoir(Vector3i(2, 1, 1), 7) \
		.simulate()
	_with_fuel(sim)
	var res: ReservoirState = sim.world.reservoirs[0]
	t.equal(res.total_capacity(), 10, "pět buněk dutiny")

	var result := action_1(sim)
	t.is_true(result.accepted, "Yeo zmrazí vodu před sebou")
	t.equal(sim.world.block_at(Vector3i(2, 2, 1)), GridTypes.BlockType.ICE, "vznikla kostka ledu")
	t.equal(res.volume_units, 5, "objem klesl o kostku")
	t.equal(res.total_capacity(), 8, "a kapacita o stejnou kostku")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "palivo se spotřebovalo")

func test_yeo_needs_water_above_half() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, "#####\n#Y..#\n#####") \
		.reservoir(Vector3i(2, 1, 1), 2) \
		.simulate()
	_with_fuel(sim)
	t.is_false(action_1(sim).accepted, "nízká hladina se nezmrazí")
	t.equal(sim.world.robots[0].inventory.size(), 1, "palivo zůstává")
