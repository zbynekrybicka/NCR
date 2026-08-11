class_name TestItems
extends TestSuite

## §12 — sbírání vstupem na buňku, plný inventář jako překážka, kdo co smí
## sbírat, Da jen shora.

func test_pickup_on_entry() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".Ef.") \
		.simulate()
	var result := step(sim)
	t.is_true(result.accepted, "Set na kanystr vstoupí")
	t.equal(sim.world.robots[0].inventory.size(), 1, "a rovnou ho sebere")
	t.is_false(sim.world.has_item_at(Vector3i(2, 1, 0)), "na zemi už neleží")
	t.is_true(result.has_event(Event.EventType.ITEM_PICKED_UP), "událost sebrání")

func test_item_blocks_robots_that_may_not_carry_it() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".Hf.") \
		.simulate()
	var result := step(sim)
	t.is_false(result.accepted, "pro Hana je kanystr překážka")
	t.equal(robot_cell(sim), Vector3i(1, 1, 0), "zůstal stát")

func test_full_inventory_makes_item_an_obstacle() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".Ef.") \
		.simulate()
	var robot: RobotState = sim.world.robots[0]
	for _i in robot.inventory_capacity():
		robot.inventory.append(GridTypes.ItemType.FUEL)
	var result := step(sim)
	t.is_false(result.accepted, "s plným inventářem je předmět překážka")

func test_da_picks_up_only_from_above() -> void:
	var side := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".Af.") \
		.simulate()
	t.is_false(step(side).accepted, "ze strany je předmět pro Da překážka")

	var above := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..f.") \
		.layer(2, "..A.") \
		.simulate()
	var result := submit(above, Command.CommandType.STEP_DOWN)
	t.is_true(result.accepted, "shora na předmět naletět může")
	t.equal(above.world.robots[0].inventory.size(), 1, "a sebere ho")

func test_drop_item_behind() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..E.") \
		.simulate()
	sim.world.robots[0].inventory.append(GridTypes.ItemType.FUEL)
	var result := action_2(sim)
	t.is_true(result.accepted, "kanystr lze odložit za sebe")
	t.equal(sim.world.item_at(Vector3i(1, 1, 0)), GridTypes.ItemType.FUEL,
			"leží za robotem")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "a v inventáři není")

func test_drop_needs_space_behind() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".#E.") \
		.simulate()
	sim.world.robots[0].inventory.append(GridTypes.ItemType.FUEL)
	var result := action_2(sim)
	t.is_false(result.accepted, "zády u zdi odložit nelze")

func test_drop_with_empty_inventory() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..N.") \
		.simulate()
	t.is_false(action_2(sim).accepted, "prázdný inventář nemá co odložit")
