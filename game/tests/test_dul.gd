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

func test_dul_has_one_tree_for_land_and_water() -> void:
	# Jeden strom na obojí: krok umí prostředí uprostřed změnit (skluz po ledu
	# do vody, výlez z vody na led), takže výběr podle výchozího stavu nestačí.
	var sim := _basin(3)
	t.equal(BTLibrary.tree_name_for(sim.world, 0), BTLibrary.TREE_DUL,
			"ve vodě rozhoduje Dulův strom")
	var dry := LevelBuilder.new().layer(0, "###").layer(1, ".U.").simulate()
	t.equal(BTLibrary.tree_name_for(dry.world, 0), BTLibrary.TREE_DUL,
			"a na suchu taky")
	var han := LevelBuilder.new().layer(0, "###").layer(1, ".H.").simulate()
	t.equal(BTLibrary.tree_name_for(han.world, 0), BTLibrary.TREE_WALK_BASE,
			"ostatním zůstal sdílený základ chůze")

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

# ── Čerpání a vypouštění ze břehu, kde hladina leží o patro níž ────────────
#
# Běžný břeh: nádrž je jáma v terénu (patro 1), Dul stojí na její hraně
# v patře 2. Patro 2 je otevřené k okraji levelu, takže do nádrže nepatří
# (§9.1) — nádrž je jen dno o kapacitě 4 jednotky.

func _bank(volume: int, direction: int = GridTypes.Direction.EAST) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, ".....\n.U...\n.....") \
		.facing(GridTypes.RobotKind.DUL, direction) \
		.reservoir(Vector3i(2, 1, 1), volume) \
		.simulate()

func test_pump_from_the_bank_with_the_surface_a_storey_below() -> void:
	var sim := _bank(3) # 3 ze 4 jednotek, tedy víc než 50 %
	t.equal(sim.world.reservoir_at(Vector3i(1, 2, 1)), -1,
			"Dul stojí na břehu, mimo nádrž")
	t.equal(sim.world.water_depth_at(Vector3i(2, 2, 1)), GridTypes.WaterDepth.DRY,
			"v jeho rovině před ním voda není — hladina je o patro níž")
	t.is_true(action_1(sim).accepted, "ze břehu Dul načerpá i hladinu o patro níž")
	t.equal(sim.world.reservoirs[0].volume_units, 1, "hladina klesla o kostku")
	t.is_true(sim.world.robots[0].hopper_full, "cisterna je plná")

func test_pump_from_the_bank_still_needs_more_than_half() -> void:
	var sim := _bank(2) # přesně polovina kapacity
	t.is_false(action_1(sim).accepted, "poloprázdná nádrž se ze břehu nečerpá")
	t.equal(sim.world.reservoirs[0].volume_units, 2, "hladina zůstala beze změny")

func test_release_from_the_bank_into_the_pit_below() -> void:
	var sim := _bank(0, GridTypes.Direction.WEST) # vypouští se dozadu, tedy na východ
	sim.world.robots[0].hopper_full = true
	t.is_true(action_2(sim).accepted, "ze břehu Dul vypustí cisternu do jámy pod sebou")
	t.equal(sim.world.reservoirs[0].volume_units, 2, "hladina stoupla o kostku")
	t.is_false(sim.world.robots[0].hopper_full, "cisterna je prázdná")

func test_release_from_the_bank_needs_a_reservoir_behind() -> void:
	# Zrcadlo: Dul kouká do jámy, takže za ním je jen suchý břeh.
	var sim := _bank(0)
	sim.world.robots[0].hopper_full = true
	t.is_false(action_2(sim).accepted, "na suchý břeh se cisterna nevypouští")

func test_no_pumping_through_a_solid_block() -> void:
	# Nádrž je zakrytá — před Dulem je zeď a voda až pod ní.
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, ".....\n.U##.\n.....") \
		.reservoir(Vector3i(2, 1, 1), 4) \
		.simulate()
	t.is_false(action_1(sim).accepted, "skrz pevný blok hadice nedosáhne")

# ── Vstup do vody ze břehu (design dok. §1.1.2 + §2.1.4) ───────────────────
#
# Nádrž o dvou patrech: dno má kapacitu 4 jednotky (buňky 2 a 3 v patře 1),
# horní patro 6 (buňky 1–3 v patře 2). Dul stojí na břehu v (1,2,1), tedy na
# rovině y = 2, a dívá se na východ do nádrže.

func _shore(volume: int, robot: String = "U") -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##..#\n#####") \
		.layer(2, "#####\n#%s..#\n#####" % robot) \
		.reservoir(Vector3i(2, 1, 1), volume) \
		.simulate()

func test_board_water_when_level_with_the_shore() -> void:
	var sim := _shore(4) # dno plné, hladina přesně v rovině břehu
	t.equal(sim.world.water_depth_at(Vector3i(1, 2, 1)), GridTypes.WaterDepth.DRY,
			"Dul stojí na suchu")
	t.is_true(step(sim).accepted, "do hladiny v rovině břehu Dul vstoupí")
	t.equal(robot_cell(sim), Vector3i(2, 1, 1), "a usadí se ve vodě pod břehem")

func test_board_water_within_half_a_cube() -> void:
	var sim := _shore(3) # hladině chybí 1/4 kostky — méně než polovina
	t.is_true(step(sim).accepted, "hladina níž o méně než půl kostky vstup dovolí")
	t.equal(robot_cell(sim), Vector3i(2, 1, 1), "Dul skončí ve vodě")

func test_board_water_rejected_when_level_too_low() -> void:
	var sim := _shore(2) # hladině chybí přesně půl kostky — už ne „méně než"
	t.is_false(step(sim).accepted, "na hladinu o půl kostky níž se ze břehu nevstupuje")
	t.equal(robot_cell(sim), Vector3i(1, 2, 1), "Dul zůstal na břehu")

func test_only_dul_boards_water_from_the_shore() -> void:
	var sim := _shore(4, "H")
	t.is_false(step(sim).accepted, "Han ze břehu do nádrže nevstoupí")
	t.equal(robot_cell(sim), Vector3i(1, 2, 1), "zůstal stát")

# ── Vylezení z vody na břeh (design dok. §1.1.2) ───────────────────────────
#
# Zrcadlo předchozí sady: Dul plave v (2,1,1), na západ od něj je zeď břehu
# (1,1,1) a nad ní volná buňka (1,2,1). Vyleze o patro výš, tedy dílčím
# krokem +1.

func _in_basin_facing_shore(volume: int) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##U.#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.facing(GridTypes.RobotKind.DUL, GridTypes.Direction.WEST) \
		.reservoir(Vector3i(2, 1, 1), volume) \
		.simulate()

func test_climb_out_onto_the_shore() -> void:
	var sim := _in_basin_facing_shore(3) # hladině chybí 1/4 kostky k hraně břehu
	t.equal(sim.world.water_depth_at(Vector3i(2, 1, 1)), GridTypes.WaterDepth.DEEP,
			"voda mu sahá výš než do poloviny kostky")
	t.is_true(step(sim).accepted, "přes zeď před sebou vyleze na břeh")
	t.equal(robot_cell(sim), Vector3i(1, 2, 1), "stojí na hraně břehu")

func test_climb_out_rejected_when_level_too_low() -> void:
	var sim := _in_basin_facing_shore(2) # hladina přesně půl kostky pod hranou
	t.equal(sim.world.water_depth_at(Vector3i(2, 1, 1)), GridTypes.WaterDepth.SHALLOW,
			"voda sahá přesně do poloviny kostky")
	t.is_false(step(sim).accepted, "z takové hladiny se na břeh nevyleze")
	t.equal(robot_cell(sim), Vector3i(2, 1, 1), "Dul zůstal ve vodě")

func test_climb_out_needs_free_cell_above_the_shore() -> void:
	# Břeh přerostlý zdí — nahoře není kam vylézt.
	var sim := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n##U.#\n#####") \
		.layer(2, "#####\n##..#\n#####") \
		.facing(GridTypes.RobotKind.DUL, GridTypes.Direction.WEST) \
		.reservoir(Vector3i(2, 1, 1), 3) \
		.simulate()
	t.is_false(step(sim).accepted, "do zdi nad břehem Dul nevyleze")
	t.equal(robot_cell(sim), Vector3i(2, 1, 1), "zůstal ve vodě")

# ── Led na rozhraní s vodou (design dok. §1.1.2) ───────────────────────────

## Ledová cesta v patře 1 (buňky 1 a 2) končí u vody (buňky 3 a 4). Led má
## nulovou kapacitu, patro 1 tedy pojme 4 jednotky. Dul stojí na ledu v (1,2,1).
func _ice_path_to_water(volume: int) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "######\n######\n######") \
		.layer(1, "######\n#II..#\n######") \
		.layer(2, "######\n#U...#\n######") \
		.reservoir(Vector3i(3, 1, 1), volume) \
		.simulate()

func test_slide_on_ice_ends_in_the_water() -> void:
	var sim := _ice_path_to_water(4) # hladina přesně v rovině ledu
	t.equal(sim.world.water_depth_at(Vector3i(1, 2, 1)), GridTypes.WaterDepth.DRY,
			"Dul stojí na ledu, ne ve vodě")
	t.is_true(step(sim).accepted, "skluz končící ve vodě se provede")
	t.equal(robot_cell(sim), Vector3i(3, 1, 1), "dosklouzal a usadil se ve vodě")

func test_slide_on_ice_into_too_low_water_is_rejected() -> void:
	var sim := _ice_path_to_water(2) # hladina půl kostky pod rovinou ledu
	t.is_false(step(sim).accepted, "na hladinu půl kostky níž se nesklouzne")
	t.equal(robot_cell(sim), Vector3i(1, 2, 1), "Dul zůstal stát")

func test_climb_out_onto_ice_slides_to_the_end() -> void:
	# Dul plave v (1,1,1), vedle je ledová kra s horní hranou v rovině hladiny.
	# Vyleze na ni o patro výš a klouže až tam, kde led končí — do vody.
	var sim := LevelBuilder.new() \
		.layer(0, "######\n######\n######") \
		.layer(1, "######\n#UII.#\n######") \
		.layer(2, "######\n#....#\n######") \
		.reservoir(Vector3i(1, 1, 1), 4) \
		.simulate()
	t.equal(sim.world.water_depth_at(Vector3i(1, 1, 1)), GridTypes.WaterDepth.DEEP,
			"Dul plave, hladina je v rovině horní hrany ledu")
	t.is_true(step(sim).accepted, "vyleze na led a sklouže se")
	t.equal(robot_cell(sim), Vector3i(4, 1, 1), "na konci ledu spadl zpátky do vody")

func test_climb_out_onto_ice_ends_on_solid_ground() -> void:
	# Totéž, ale ledová cesta končí na zdi — Dul na ní zůstane stát.
	var sim := LevelBuilder.new() \
		.layer(0, "######\n######\n######") \
		.layer(1, "######\n#UII##\n######") \
		.layer(2, "######\n#....#\n######") \
		.reservoir(Vector3i(1, 1, 1), 2) \
		.simulate()
	t.is_true(step(sim).accepted, "skluz končící na pevné zemi se provede")
	t.equal(robot_cell(sim), Vector3i(4, 2, 1), "Dul stojí na zdi za ledem")

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
