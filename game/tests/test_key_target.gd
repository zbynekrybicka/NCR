class_name TestKeyTarget
extends TestSuite

## §14 — klíč odemyká cíl, robot v cíli mizí ze sekvence, level končí, až
## jsou v cíli všichni.

func _level() -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "#####\n#####") \
		.layer(1, ".H.+T\n.N...") \
		.simulate()

func test_target_is_locked_without_the_key() -> void:
	var sim := _level()
	submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1)   # Net, bez klíče
	step(sim)
	step(sim)
	step(sim)
	t.equal(robot_cell(sim, 1), Vector3i(4, 1, 1), "Net došel pod cíl")
	submit(sim, Command.CommandType.TURN_LEFT)
	var result := step(sim)
	t.is_false(result.accepted, "zamčeným cílem se projít nedá")
	t.is_false(sim.world.target_unlocked, "a nic se neodemklo")

func test_key_pickup_and_unlock() -> void:
	var sim := _level()
	step(sim)
	var picked := step(sim)
	t.equal(sim.world.key_holder, 0, "Han sebral klíč vstupem na jeho buňku")
	t.is_true(picked.has_event(Event.EventType.KEY_PICKED_UP), "událost sebrání klíče")

	var entered := step(sim)
	t.is_true(entered.accepted, "nositel klíče cílem projde")
	t.is_true(sim.world.target_unlocked, "a odemkne ho pro ostatní")
	t.is_true(sim.world.robots[0].in_target, "Han je v cíli")
	t.is_true(entered.has_event(Event.EventType.ROBOT_ENTERED_TARGET), "událost vstupu")
	t.is_false(sim.world.robot_sequence.has(0), "vypadl ze sekvence přepínání")
	t.equal(sim.world.active_robot_index, 1, "hra rovnou přepnula na dalšího")
	t.is_false(entered.has_event(Event.EventType.LEVEL_COMPLETED),
			"level ještě není hotový")

func test_level_completed_when_everyone_is_in() -> void:
	var sim := _level()
	step(sim)
	step(sim)
	step(sim)   # Han vejde do cíle, aktivním se stává Net
	t.equal(sim.world.active_robot_index, 1, "aktivní je Net")
	step(sim)
	step(sim)
	step(sim)   # Net dojde pod cíl
	t.equal(robot_cell(sim, 1), Vector3i(4, 1, 1), "Net je pod cílem")
	submit(sim, Command.CommandType.TURN_LEFT)
	var result := step(sim)
	t.is_true(result.accepted, "odemčeným cílem projdou všichni")
	t.is_true(result.has_event(Event.EventType.LEVEL_COMPLETED), "level je dokončený")
	t.is_true(sim.is_level_completed(), "a simulace to potvrzuje")

func test_restart_rebuilds_the_world() -> void:
	var sim := _level()
	step(sim)
	step(sim)
	t.equal(sim.world.key_holder, 0, "klíč je sebraný")
	var result := sim.submit_command(Command.new(Command.CommandType.RESTART_LEVEL))
	t.is_true(result.accepted, "restart projde vždy")
	t.equal(sim.world.key_holder, -1, "klíč je zase na zemi")
	t.equal(sim.world.robots[0].cell, Vector3i(1, 1, 0), "roboti jsou na startu")

func test_switch_robot_next_cycles() -> void:
	var sim := _level()
	t.equal(sim.next_robot_in_sequence(), 1, "za prvním je druhý")
	submit(sim, Command.CommandType.SWITCH_ROBOT_NEXT)
	t.equal(sim.world.active_robot_index, 1, "přepnulo se")
	t.equal(sim.next_robot_in_sequence(), 0, "a sekvence se cyklicky vrací")
