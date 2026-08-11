class_name TestSuite
extends RefCounted

## Základ testovací sady. Runner zavolá všechny metody začínající `test_`.

var t: TestRunner

func setup() -> void:
	pass

func teardown() -> void:
	pass

## Odešle příkaz a rovnou ověří invarianty I1–I8 (§18, úroveň 4).
func submit(sim: Simulation, command_type: int, target_index: int = -1) -> Command.Result:
	var result := sim.submit_command(Command.new(command_type, target_index))
	var problems := sim.world.check_invariants()
	t.check(problems.is_empty(), "invarianty po příkazu %s: %s"
			% [Command.CommandType.keys()[command_type], ", ".join(problems)])
	return result

func step(sim: Simulation) -> Command.Result:
	return submit(sim, Command.CommandType.STEP)

func action_1(sim: Simulation) -> Command.Result:
	return submit(sim, Command.CommandType.ACTION_1)

func action_2(sim: Simulation) -> Command.Result:
	return submit(sim, Command.CommandType.ACTION_2)

func robot_cell(sim: Simulation, index: int = -1) -> Vector3i:
	var i := index if index >= 0 else sim.world.active_robot_index
	return sim.world.robots[i].cell
