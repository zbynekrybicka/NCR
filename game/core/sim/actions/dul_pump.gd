class_name DulPump
extends Action

## Dul, Akce 1 — Načerpání vody (§7.6, design dokument §1.1.2).
## Ponořený bez omezení; ze břehu jen z nádrže zaplněné na víc než 50 %.

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.DUL:
		return Validation.reject("čerpat umí jen Dul")
	if robot.hopper_full:
		return Validation.reject("cisterna je plná")

	# ponořený
	if world.water_depth_at(robot.cell) != GridTypes.WaterDepth.DRY:
		var here_index := world.reservoir_at(robot.cell)
		if not WaterSystem.lowering_water_is_possible(world, here_index,
				GridTypes.UNITS_PER_CUBE):
			return Validation.reject("v nádrži není dost vody")
		return Validation.accept({"reservoir": here_index})

	# ze břehu — nádrž leží buď v rovině robota, nebo (běžný břeh) o patro níž;
	# jak vysoko v ní sahá hladina, neřeší poloha buňky, ale poměr zaplnění.
	var ahead := ActionHelpers.ahead_cell(world, robot_index)
	var ahead_index := ActionHelpers.reservoir_within_reach(world, ahead)
	if ahead_index == -1:
		return Validation.reject("před robotem není nádrž")
	var res: ReservoirState = world.reservoirs[ahead_index]
	if not WaterSystem.fill_ratio_over_half(res):
		return Validation.reject("nádrž je zaplněná na 50 % nebo míň")
	if not WaterSystem.lowering_water_is_possible(world, ahead_index, GridTypes.UNITS_PER_CUBE):
		return Validation.reject("v nádrži není dost vody")
	return Validation.accept({"reservoir": ahead_index})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var reservoir_index: int = validation.data["reservoir"]
	# Neomezená nádrž objem nemění (§13.3), čerpání i tak uspěje.
	WaterSystem.change_volume(world, reservoir_index, -GridTypes.UNITS_PER_CUBE, out_events)
	robot.hopper_full = true
