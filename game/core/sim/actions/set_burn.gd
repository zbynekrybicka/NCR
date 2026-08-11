class_name SetBurn
extends Action

## Set, Akce 1 — Zapálení dřeva / roztavení ledu (§7.6, design dokument §1.1.3).
## Dřevo: priorita vodorovně → šikmo → svisle. Led: jen šikmo dolů před, s
## kontrolou plovoucí kry. Palivo se spotřebuje jen při úspěchu.

enum BurnTarget { AHEAD, AHEAD_BELOW, ABOVE, ICE_AHEAD_BELOW }

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.SET:
		return Validation.reject("zapalovat umí jen Set")
	if not robot.has_item(GridTypes.ItemType.FUEL):
		return Validation.reject("chybí kanystr s palivem")

	var probe := GridProbe.new(world, robot.cell, robot.facing, robot_index)

	# dřevo — priorita vodorovně, šikmo, svisle
	var wood_candidates := [
		[probe.cell_ahead(), BurnTarget.AHEAD],
		[probe.cell_ahead_below(), BurnTarget.AHEAD_BELOW],
		[probe.cell_above(), BurnTarget.ABOVE],
	]
	for candidate in wood_candidates:
		var cell: Vector3i = candidate[0]
		if world.block_at(cell) != GridTypes.BlockType.WOOD:
			continue
		if not ActionHelpers.no_robot_below(world, cell, robot_index):
			return Validation.reject("pod dřevem stojí robot")
		return Validation.accept({"target": cell, "which": candidate[1]})

	# led — jen šikmo dolů před
	var ice_cell := probe.cell_ahead_below()
	if world.block_at(ice_cell) == GridTypes.BlockType.ICE:
		if WaterSystem.would_leave_floating_ice_raft(world, ice_cell):
			return Validation.reject("roztavením by vznikla plovoucí kra")
		var reservoir_index := world.reservoir_at(ice_cell)
		if reservoir_index == -1:
			return Validation.reject("led není součástí nádrže")
		return Validation.accept({
			"target": ice_cell,
			"which": BurnTarget.ICE_AHEAD_BELOW,
			"reservoir": reservoir_index,
		})

	return Validation.reject("v dosahu není co spálit ani roztavit")

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var target: Vector3i = validation.data["target"]
	var which: int = validation.data["which"]
	robot.remove_item(GridTypes.ItemType.FUEL)

	if which == BurnTarget.ICE_AHEAD_BELOW:
		var reservoir_index: int = validation.data["reservoir"]
		# Kapacita +2 obstará set_block; objem +2 vrací vodu zpátky, takže se
		# hladina zbytku nádrže nepohne (§9.3 pozn. 1).
		world.set_block(target, GridTypes.BlockType.EMPTY)
		out_events.append(Event.block_removed(target, GridTypes.BlockType.ICE))
		WaterSystem.change_volume(world, reservoir_index, GridTypes.UNITS_PER_CUBE, out_events)
		out_events.append(Event.ice_melted(target, reservoir_index))
		return

	world.set_block(target, GridTypes.BlockType.EMPTY)
	out_events.append(Event.block_removed(target, GridTypes.BlockType.WOOD))
