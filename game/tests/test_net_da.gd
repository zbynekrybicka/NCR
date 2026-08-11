class_name TestNetDa
extends TestSuite

## §7.6 (šplhání Neta, let Da), §7.7 (svislé kroky Da), §10 (is_safe_to_leave).

# ── Net ────────────────────────────────────────────────────────────────────

func _climb_level(wall_top: String = "#") -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".N#.") \
		.layer(2, "..%s." % wall_top) \
		.layer(3, "....") \
		.simulate()

func test_climb_up_and_land_on_top() -> void:
	var sim := _climb_level()
	var result := step(sim)
	t.is_true(result.accepted, "Net vyšplhá po stěně")
	t.equal(robot_cell(sim), Vector3i(2, 3, 0), "a usadí se na jejím vrcholu")
	t.equal(result.events_of(Event.EventType.ROBOT_MOVED).size(), 3,
			"celé šplhání je jeden příkaz hráče")

func test_climb_up_fails_on_ice_in_the_wall() -> void:
	var sim := _climb_level("I")
	var result := step(sim)
	t.is_false(result.accepted, "led ve stěně shodí celou nashromážděnou frontu")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "Net zůstal dole")

func test_climb_up_is_limited_to_two_items() -> void:
	var sim := _climb_level()
	var net: RobotState = sim.world.robots[0]
	net.inventory.append(GridTypes.ItemType.FUEL)
	net.inventory.append(GridTypes.ItemType.FUEL)
	t.is_true(step(sim).accepted, "se dvěma předměty Net ještě šplhá")

	var loaded := _climb_level()
	var heavy: RobotState = loaded.world.robots[0]
	for _i in 3:
		heavy.inventory.append(GridTypes.ItemType.FUEL)
	t.is_false(step(loaded).accepted, "se třemi už ne")

func test_climb_up_needs_solid_landing() -> void:
	# Stěna nikde neskončí (jde až ke stropu levelu) — není kam vylézt.
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".N#.") \
		.layer(2, "..#.") \
		.layer(3, "..#.") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "bez pevného přistání se celá fronta zahodí")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "Net zůstal dole")

func test_climb_down_the_cliff() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".#..") \
		.layer(2, ".#..") \
		.layer(3, ".N..") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "Net sešplhá po stěně dolů")
	t.equal(robot_cell(sim), Vector3i(2, 1, 0), "přistál na dně u stěny")

func test_climb_down_without_wall_fails() -> void:
	# Net stojí na osamocené kostce nad propastí — stěna, po které by slezl,
	# cestou dolů zmizí, takže se celá fronta zahodí.
	var sim := LevelBuilder.new() \
		.layer(0, "....") \
		.layer(1, "....") \
		.layer(2, ".#..") \
		.layer(3, ".N..") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "bez stěny v zádech se sešplhat nedá")
	t.equal(robot_cell(sim), Vector3i(1, 3, 0), "Net zůstal nahoře")

# ── Da ─────────────────────────────────────────────────────────────────────

func test_da_flies_forward_without_ground() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "....") \
		.layer(2, ".A..") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "Da letí i nad propastí")
	t.equal(robot_cell(sim), Vector3i(2, 2, 0), "posunul se vpřed")

func test_da_cannot_enter_water() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#A..#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 3) \
		.simulate()
	sim.world.robots[0].cell = Vector3i(1, 2, 1)
	t.is_false(submit(sim, Command.CommandType.STEP_DOWN).accepted,
			"Da do vody nesmí ani shora")

func test_da_vertical_steps() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".A..") \
		.layer(2, "....") \
		.simulate()
	t.is_true(submit(sim, Command.CommandType.STEP_UP).accepted, "Da stoupá kdykoli")
	t.equal(robot_cell(sim), Vector3i(1, 2, 0), "je o patro výš")
	t.is_true(submit(sim, Command.CommandType.STEP_DOWN).accepted, "a klesá zpátky")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "zpět na zem")

func test_da_must_land_before_switching() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".AH.") \
		.layer(2, "....") \
		.simulate()
	t.is_true(sim.is_safe_to_leave(0), "na zemi je Da v bezpečí")
	submit(sim, Command.CommandType.STEP_UP)
	t.is_false(sim.is_safe_to_leave(0), "ve vzduchu ne")
	t.is_false(submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1).accepted,
			"přepnutí z letícího Da se odmítne")
	submit(sim, Command.CommandType.STEP_DOWN)
	t.is_true(submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1).accepted,
			"po přistání přepnutí projde")

func test_da_drop_marks_cannot_land() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "....") \
		.layer(2, ".A..") \
		.simulate()
	sim.world.robots[0].inventory.append(GridTypes.ItemType.FUEL)
	var result := action_2(sim)
	t.is_true(result.accepted, "Da odhodí předmět pod sebe")
	t.equal(sim.world.item_at(Vector3i(1, 1, 0)), GridTypes.ItemType.FUEL,
			"předmět dopadl na pevný podklad")
	t.equal(robot_cell(sim), Vector3i(1, 2, 0), "Da zůstal ve vzduchu")
	t.equal(sim.world.robots[0].cannot_land_cell, Vector3i(1, 1, 0),
			"buňka pod ním je označená jako zakázaná pro přistání")
	t.is_false(submit(sim, Command.CommandType.STEP_DOWN).accepted,
			"a Da na ni nesmí přistát")

func test_da_needs_at_least_one_cube_below_to_drop() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".A..") \
		.simulate()
	sim.world.robots[0].inventory.append(GridTypes.ItemType.FUEL)
	t.is_false(action_2(sim).accepted, "těsně nad zemí odhodit nelze")
