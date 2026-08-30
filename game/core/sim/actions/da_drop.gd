class_name DaDrop
extends Action

## Da, Akce 2 — Odhození předmětu pod sebe (§7.6, design dokument §1.1.5).
## Odhození jde jen dolů, minimálně o jednu kostku, a na místo dopadu pak
## Da nesmí přistát bez opětovného sebrání předmětu.

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.DA:
		return Validation.reject("takhle odhazuje jen Da")
	if robot.inventory.is_empty():
		return Validation.reject("Da nic nenese")

	var below := robot.cell + GridTypes.DOWN_VECTOR
	if not world.is_inside(below) or world.is_solid_at(below):
		return Validation.reject("pod Da není volný prostor")

	var landing := ActionHelpers.landing_cell_for_drop(world, below)
	if landing == RobotState.NO_CELL:
		return Validation.reject("předmět nemá kam dopadnout")
	if not ActionHelpers.no_robot_at(world, landing):
		return Validation.reject("na místě dopadu stojí robot")
	if world.has_item_at(landing):
		return Validation.reject("na místě dopadu už předmět leží")
	return Validation.accept({"item": robot.inventory[0], "landing": landing})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var item: int = validation.data["item"]
	var landing: Vector3i = validation.data["landing"]
	robot.remove_item(item)
	world.put_item_at(landing, item)
	# Da zůstává na svém místě ve vzduchu a na buňku pod sebou už nesmí
	# přistát, dokud předmět zase nesebere (§7.6, §7.7).
	robot.cannot_land_cell = robot.cell + GridTypes.DOWN_VECTOR
	out_events.append(Event.item_dropped(robot_index, item, landing,
			robot.cannot_land_cell))
