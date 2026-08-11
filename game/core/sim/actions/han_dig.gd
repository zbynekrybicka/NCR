class_name HanDig
extends Action

## Han, Akce 1 — Nahrábnutí (§7.6, design dokument §1.1.1).
## Tři možné cíle podle polohy vůči Hanovi, priorita stejná jako pořadí
## větví ve sdílené chůzi: před / pod / šikmo dolů před.

enum DigTarget { AHEAD, BELOW, AHEAD_BELOW }

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.HAN:
		return Validation.reject("nahrábnout umí jen Han")
	if robot.hopper_full:
		return Validation.reject("korba je plná")

	var probe := GridProbe.new(world, robot.cell, robot.facing, robot_index)

	# před
	var ahead := probe.cell_ahead()
	if world.block_at(ahead) == GridTypes.BlockType.DIRT:
		if not ActionHelpers.no_robot_below(world, ahead, robot_index):
			return Validation.reject("pod hlínou stojí robot")
		return Validation.accept({"target": ahead, "which": DigTarget.AHEAD})

	# pod
	var below := probe.cell_below()
	if world.block_at(below) == GridTypes.BlockType.DIRT:
		if not ActionHelpers.no_robot_below(world, below, robot_index):
			return Validation.reject("pod hlínou stojí robot")
		return Validation.accept({"target": below, "which": DigTarget.BELOW})

	# šikmo dolů před — hlavní/běžný případ
	var ahead_below := probe.cell_ahead_below()
	if BTNodes.can_enter(probe, ahead) \
			and world.block_at(ahead_below) == GridTypes.BlockType.DIRT:
		if not ActionHelpers.no_robot_below(world, ahead_below, robot_index):
			return Validation.reject("pod hlínou stojí robot")
		return Validation.accept({"target": ahead_below, "which": DigTarget.AHEAD_BELOW})

	return Validation.reject("v dosahu není hlína")

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var target: Vector3i = validation.data["target"]
	world.set_block(target, GridTypes.BlockType.EMPTY)
	robot.hopper_full = true
	out_events.append(Event.block_removed(target, GridTypes.BlockType.DIRT))
	# Gravitační usazení (§8) i případný pokles hladiny (§9.3 pozn. 2) proběhne
	# v dosazovací fázi příkazu — žádný zvláštní kód tu není potřeba.
