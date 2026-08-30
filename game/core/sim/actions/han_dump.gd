class_name HanDump
extends Action

## Han, Akce 2 — Vysypání korby (§7.6, design dokument §1.1.1).
## Vysypává se výhradně dozadu; místo dopadu se hledá předem a kontroluje se,
## že tam nestojí robot a že se kostka vejde do nádrže.

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.HAN:
		return Validation.reject("korbu má jen Han")
	if not robot.hopper_full:
		return Validation.reject("korba je prázdná")
	if not ActionHelpers.has_free_space_behind(world, robot_index):
		return Validation.reject("za robotem není volný prostor")

	var landing := ActionHelpers.landing_cell_for_drop(world,
			ActionHelpers.behind_cell(world, robot_index))
	if landing == RobotState.NO_CELL:
		return Validation.reject("kostka nemá kam dopadnout")
	if not ActionHelpers.no_robot_at(world, landing):
		return Validation.reject("na místě dopadu stojí robot")

	var reservoir_index := world.reservoir_at(landing)
	var into_water := reservoir_index != -1 \
			and world.water_depth_at(landing) != GridTypes.WaterDepth.DRY
	if into_water:
		if not WaterSystem.raising_water_is_safe(world, reservoir_index,
				GridTypes.UNITS_PER_CUBE):
			return Validation.reject("hladina by stoupla nad bezpečnou mez")
	return Validation.accept({
		"landing": landing,
		"reservoir": reservoir_index if into_water else -1,
	})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var landing: Vector3i = validation.data["landing"]
	var reservoir_index: int = validation.data["reservoir"]

	world.set_block(landing, GridTypes.BlockType.DIRT)
	robot.hopper_full = false
	out_events.append(Event.block_placed(landing, GridTypes.BlockType.DIRT,
			ActionHelpers.behind_cell(world, robot_index)))
	if reservoir_index != -1:
		# §9.3: dopad do vody přidává objem a zároveň buňka ztrácí kapacitu
		# (tu odečte set_block sám). Kapacita i objem viz poznámka k rozporu
		# s design dokumentem §1.1.1 v hlášení k implementaci.
		WaterSystem.change_volume(world, reservoir_index, GridTypes.UNITS_PER_CUBE, out_events)
