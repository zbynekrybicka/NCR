class_name DulRelease
extends Action

## Dul, Akce 2 — Vypuštění cisterny (§7.6, design dokument §1.1.2).
## Vypouští se dozadu, ze břehu i přímo do nádrže, s kontrolou utonutí.

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.DUL:
		return Validation.reject("cisternu má jen Dul")
	if not robot.hopper_full:
		return Validation.reject("cisterna je prázdná")

	# Za robotem: nádrž v jeho rovině (stojí v ní, nebo je zeď nádrže vysoká),
	# nebo o patro níž — to je běžný břeh (viz reservoir_within_reach).
	var behind := ActionHelpers.behind_cell(world, robot_index)
	var reservoir_index := ActionHelpers.reservoir_within_reach(world, behind)
	if reservoir_index == -1:
		return Validation.reject("za robotem není nádrž")
	if not WaterSystem.raising_water_is_safe(world, reservoir_index, GridTypes.UNITS_PER_CUBE):
		return Validation.reject("hladina by stoupla nad bezpečnou mez")
	return Validation.accept({"reservoir": reservoir_index})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var reservoir_index: int = validation.data["reservoir"]
	WaterSystem.change_volume(world, reservoir_index, GridTypes.UNITS_PER_CUBE, out_events)
	robot.hopper_full = false
