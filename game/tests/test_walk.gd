class_name TestWalk
extends TestSuite

## §7.6.0 — sdílený základ chůze: rovná chůze, obě šikminy, skluz po ledu
## a FAIL nad propastí na konci ledu.

func test_straight_step() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H..") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "krok po rovině prošel")
	t.equal(robot_cell(sim), Vector3i(2, 1, 0), "robot se posunul o jednu kostku")
	t.equal(result.events.size(), 1, "jedna událost pohybu")

func test_step_into_wall_is_rejected() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H#.") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "do zdi se nedá vejít")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "robot zůstal na místě")
	t.is_true(result.has_event(Event.EventType.COMMAND_REJECTED), "vznikla událost odmítnutí")

func test_step_over_abyss_is_rejected() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##.#") \
		.layer(1, ".H..") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "do propasti se nekráčí")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "robot zůstal na místě")

func test_ramp_up_and_down() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "######") \
		.layer(1, ".H.>##") \
		.layer(2, "......") \
		.simulate()
	step(sim)
	t.equal(robot_cell(sim), Vector3i(2, 1, 0), "krok k šikmině")
	step(sim)
	t.equal(robot_cell(sim), Vector3i(3, 2, 0), "výstup po šikmině (dílčí krok 1)")
	step(sim)
	t.equal(robot_cell(sim), Vector3i(4, 2, 0), "krok na plošinu nad zdí")

	submit(sim, Command.CommandType.TURN_AROUND)
	step(sim)
	t.equal(robot_cell(sim), Vector3i(3, 1, 0), "sestup po šikmině (dílčí krok -1)")
	step(sim)
	t.equal(robot_cell(sim), Vector3i(2, 1, 0), "a zpět na rovinu")

func test_ice_slide_is_one_command() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##II#.") \
		.layer(1, ".H....") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "vstup na led prošel")
	t.equal(robot_cell(sim), Vector3i(4, 1, 0), "robot sklouzal celou plochu jedním příkazem")
	t.equal(result.events_of(Event.EventType.ROBOT_MOVED).size(), 3,
			"tři dílčí kroky v jednom příkazu hráče")

func test_ice_slide_ending_over_abyss_fails() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##II..") \
		.layer(1, ".H....") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "kontrola proběhne dopředu, ne až po sklouznutí")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "robot na led vůbec nevstoupil")

func test_ice_slide_stops_at_obstacle() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##II##") \
		.layer(1, ".H..#.") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "skluz končí o překážku")
	t.equal(robot_cell(sim), Vector3i(3, 1, 0), "robot dojel až ke zdi")

func test_yeo_walks_on_ice_without_sliding() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##II#.") \
		.layer(1, ".Y....") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "Yeo na led vstoupí")
	t.equal(robot_cell(sim), Vector3i(2, 1, 0), "a zůstane stát hned na první kostce")

func test_turning_is_always_allowed() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##") \
		.layer(1, "H#") \
		.simulate()
	var result := submit(sim, Command.CommandType.TURN_LEFT)
	t.is_true(result.accepted, "otáčet se mohou všichni neomezeně")
	t.equal(sim.world.robots[0].facing, GridTypes.Direction.NORTH, "z východu vlevo je sever")
	submit(sim, Command.CommandType.TURN_AROUND)
	t.equal(sim.world.robots[0].facing, GridTypes.Direction.SOUTH, "a čelem vzad jih")
