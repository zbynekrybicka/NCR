class_name DropItem
extends Action

## Odložení předmětu za sebe — sdílená akce 2 pro Seta, Neta, Yea a Ila
## (§7.6, design dokument §2.1.3). Stejná kontrola místa dopadu jako u
## Hanova vysypání korby, ale bez omezení na plnou nádrž: předmět nemá
## vlastní objem, kapacitu nádrže nezabírá.

var preferred_item: int = -1

func _init(p_preferred_item: int = -1) -> void:
	preferred_item = p_preferred_item

func validate(world: WorldState, robot_index: int) -> Validation:
	var item := ActionHelpers.item_to_drop(world, robot_index, preferred_item)
	if item == GridTypes.NO_ITEM:
		return Validation.reject("robot nic nenese")
	if not ActionHelpers.has_free_space_behind(world, robot_index):
		return Validation.reject("za robotem není volný prostor")

	var landing := ActionHelpers.landing_cell_for_drop(world,
			ActionHelpers.behind_cell(world, robot_index))
	if landing == RobotState.NO_CELL:
		return Validation.reject("předmět nemá kam dopadnout")
	if not ActionHelpers.no_robot_at(world, landing):
		return Validation.reject("na místě dopadu stojí robot")
	if world.has_item_at(landing):
		return Validation.reject("na místě dopadu už předmět leží")
	return Validation.accept({"item": item, "landing": landing})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var item: int = validation.data["item"]
	var landing: Vector3i = validation.data["landing"]
	robot.remove_item(item)
	world.put_item_at(landing, item)
	# Dopad do vody je povolený bez další kontroly a hladinu nezvyšuje —
	# předmět nemá vlastní objem (design dokument §2.1.3).
	out_events.append(Event.item_dropped(robot_index, item, landing))
