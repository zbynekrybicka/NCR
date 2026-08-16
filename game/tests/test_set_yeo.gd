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

# ── Zmrazování ze břehu (design dok. §1.1.6 „ze břehu i z mělké vody") ─────
#
# Stejná geometrie jako u Dulova čerpání ze břehu: nádrž je jáma v terénu
# (patro 1), Yeo stojí na její hraně v patře 2. Patro 2 je otevřené k okraji
# levelu, takže do nádrže nepatří (§9.1) — nádrž je jen dno o kapacitě 4.

func _bank(volume: int) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, ".....\n.Y...\n.....") \
		.reservoir(Vector3i(2, 1, 1), volume) \
		.simulate()

func test_yeo_freezes_from_the_bank_a_storey_below() -> void:
	var sim := _bank(3) # 3 ze 4 jednotek, tedy víc než 50 %
	_with_fuel(sim)
	t.equal(sim.world.water_depth_at(Vector3i(2, 2, 1)), GridTypes.WaterDepth.DRY,
			"v rovině Yeoa před ním voda není — hladina je o patro níž")

	var result := action_1(sim)
	t.is_true(result.accepted, "ze břehu Yeo zmrazí i hladinu o patro níž")
	t.equal(sim.world.block_at(Vector3i(2, 1, 1)), GridTypes.BlockType.ICE,
			"led vznikl v buňce s vodou, ne ve vzduchu nad ní")
	t.equal(sim.world.reservoirs[0].volume_units, 1, "objem klesl o kostku")
	t.equal(sim.world.reservoirs[0].total_capacity(), 2, "a kapacita o stejnou kostku")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "palivo se spotřebovalo")

func test_yeo_walks_onto_the_ice_made_from_the_bank() -> void:
	var sim := _bank(3)
	_with_fuel(sim)
	action_1(sim)
	t.is_true(step(sim).accepted, "po vlastním ledu Yeo přejde z břehu dál")
	t.equal(robot_cell(sim), Vector3i(2, 2, 1), "stojí nad zmrazenou buňkou")

func test_yeo_from_the_bank_still_needs_more_than_half() -> void:
	var sim := _bank(2) # přesně polovina kapacity
	_with_fuel(sim)
	t.is_false(action_1(sim).accepted, "poloprázdná nádrž se ze břehu nezmrazí")
	t.equal(sim.world.reservoirs[0].volume_units, 2, "hladina zůstala beze změny")
	t.equal(sim.world.robots[0].inventory.size(), 1, "palivo zůstává")

func test_yeo_does_not_freeze_through_a_solid_block() -> void:
	# Nádrž je zakrytá — před Yeoem je zeď a voda až pod ní.
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, ".....\n.Y##.\n.....") \
		.reservoir(Vector3i(2, 1, 1), 4) \
		.simulate()
	_with_fuel(sim)
	t.is_false(action_1(sim).accepted, "skrz pevný blok chlad nedosáhne")
	t.equal(sim.world.robots[0].inventory.size(), 1, "palivo zůstává")
