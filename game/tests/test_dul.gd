class_name TestDul
extends TestSuite

## §7.6 (strom plavání), §7.7 (svislý pohyb ve vodě), §9.3 (čerpání).

func _basin(volume: int, unlimited: bool = false) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#U..#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), volume, unlimited) \
		.simulate()

func test_swim_tree_is_used_in_water() -> void:
	var sim := _basin(3)
	t.equal(BTLibrary.tree_name_for(sim.world, 0), BTLibrary.TREE_DUL_SWIM,
			"ve vodě se vybere strom plavání")
	var dry := LevelBuilder.new().layer(0, "###").layer(1, ".U.").simulate()
	t.equal(BTLibrary.tree_name_for(dry.world, 0), BTLibrary.TREE_WALK_BASE,
			"na suchu chodí sdíleným základem")

func test_swim_forward() -> void:
	var sim := _basin(3)
	var result := step(sim)
	t.is_true(result.accepted, "Dul plave vpřed")
	t.equal(robot_cell(sim), Vector3i(2, 1, 1), "posunul se o kostku")

func test_pump_while_submerged() -> void:
	var sim := _basin(3)
	var result := action_1(sim)
	t.is_true(result.accepted, "ponořený Dul čerpá bez omezení")
	t.equal(sim.world.reservoirs[0].volume_units, 1, "hladina klesla o kostku")
	t.is_true(sim.world.robots[0].hopper_full, "cisterna je plná")

func test_pump_from_shore_needs_more_than_half() -> void:
	# Dul na břehu (na zdi u nádrže), hladina přesně na polovině → nelze.
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, "#####\n#U..#\n#####") \
		.reservoir(Vector3i(2, 1, 1), 4) \
		.simulate()
	t.equal(sim.world.water_depth_at(Vector3i(1, 2, 1)), GridTypes.WaterDepth.DRY,
			"Dul stojí na suchu")
	t.is_false(action_1(sim).accepted, "z nádrže zaplněné na polovinu se ze břehu nečerpá")

func test_release_raises_the_level() -> void:
	var sim := _basin(2)
	action_1(sim)
	t.equal(sim.world.reservoirs[0].volume_units, 0, "nádrž je vyčerpaná")
	submit(sim, Command.CommandType.TURN_AROUND)
	var result := action_2(sim)
	t.is_true(result.accepted, "cisternu lze vypustit dozadu do nádrže")
	t.equal(sim.world.reservoirs[0].volume_units, 2, "hladina stoupla o kostku")
	t.is_false(sim.world.robots[0].hopper_full, "cisterna je prázdná")

func test_release_that_would_drown_another_robot() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#HU.#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 3) \
		.simulate()
	sim.world.robots[1].hopper_full = true
	submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1)
	submit(sim, Command.CommandType.TURN_AROUND)
	var result := action_2(sim)
	t.is_false(result.accepted, "vypuštění, po kterém by se Han utopil, se neprovede")
	t.equal(sim.world.reservoirs[0].volume_units, 3, "hladina zůstala beze změny")

func test_unlimited_reservoir_pumping() -> void:
	var sim := _basin(3, true)
	var result := action_1(sim)
	t.is_true(result.accepted, "z neomezené nádrže Dul čerpat smí")
	t.equal(sim.world.reservoirs[0].volume_units, 3, "hladina se ale nezmění")

func test_vertical_steps_only_in_water() -> void:
	var deep := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#U..#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 8) \
		.simulate()
	var up := submit(deep, Command.CommandType.STEP_UP)
	t.is_true(up.accepted, "ve vodě se Dul posune svisle vzhůru")
	t.equal(robot_cell(deep), Vector3i(1, 2, 1), "je o patro výš")
	var down := submit(deep, Command.CommandType.STEP_DOWN)
	t.is_true(down.accepted, "a zase se potopí")
	t.equal(robot_cell(deep), Vector3i(1, 1, 1), "zpátky na dno")

func test_vertical_step_on_land_is_rejected() -> void:
	var sim := LevelBuilder.new().layer(0, "###").layer(1, ".U.").simulate()
	t.is_false(submit(sim, Command.CommandType.STEP_UP).accepted,
			"mimo vodu se Dul svisle nepohybuje")

func test_other_robots_have_no_vertical_step() -> void:
	var sim := LevelBuilder.new().layer(0, "###").layer(1, ".H.").layer(2, "...").simulate()
	t.is_false(submit(sim, Command.CommandType.STEP_UP).accepted,
			"Han svislý pohyb nemá")
