class_name YeoFreeze
extends Action

## Yeo, Akce 1 — Vytvoření ledové kostky (§7.6, design dokument §1.1.6).
## Žádné bezpečnostní omezení kromě „mít co zmrazit" — vznik ledu nikdy nic
## neodpojuje od podkladu.

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.YEO:
		return Validation.reject("mrazit umí jen Yeo")
	if not robot.has_item(GridTypes.ItemType.FUEL):
		return Validation.reject("chybí kanystr s palivem")
	if not ActionHelpers.standing_on_solid_or_ice(world, robot_index):
		return Validation.reject("Yeo nestojí na pevném podkladu ani na ledu")

	var ahead := ActionHelpers.ahead_cell(world, robot_index)
	var reservoir_index := world.reservoir_at(ahead)
	if reservoir_index == -1 or world.water_depth_at(ahead) == GridTypes.WaterDepth.DRY:
		return Validation.reject("před robotem není voda")
	var res: ReservoirState = world.reservoirs[reservoir_index]
	if not WaterSystem.fill_ratio_over_half(res):
		return Validation.reject("hladina není vyšší než do poloviny kostky")
	return Validation.accept({"target": ahead, "reservoir": reservoir_index})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var target: Vector3i = validation.data["target"]
	var reservoir_index: int = validation.data["reservoir"]
	robot.remove_item(GridTypes.ItemType.FUEL)
	# Kapacita -2 obstará set_block, objem -2 tady: kapacita i objem klesnou
	# 1:1, takže hladina zbytku vody zůstane přesně na místě (§9.3 pozn. 1).
	world.set_block(target, GridTypes.BlockType.ICE)
	out_events.append(Event.block_placed(target, GridTypes.BlockType.ICE))
	WaterSystem.change_volume(world, reservoir_index, -GridTypes.UNITS_PER_CUBE, out_events)
