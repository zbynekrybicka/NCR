class_name BTNodes
extends RefCounted

## Knihovna uzlů a registr pojmenovaných predikátů (§7.4).
## Predikáty jsou čisté dotazy na sondu — nikdy nemutují stav (P5).

const NODE_TYPES := [
	"selector", "sequence", "inverter", "condition",
	"emit", "emit_continue", "succeed", "fail",
]

const PREDICATES := [
	"ahead_is_solid",
	"ahead_is_ice",
	"ahead_is_water",
	"ahead_has_item",
	"ahead_is_passable",
	"ahead_above_is_passable",
	"above_is_passable",
	"below_is_passable",
	"ahead_below_is_solid",
	"ahead_below_is_ice",
	"ahead_below_is_dirt",
	"ahead_below_free_for_robot",
	"ahead_is_ramp_facing_me",
	"ahead_below_is_ramp_facing_away",
	"ahead_water_is_deep",
	"below_is_solid",
	"behind_is_solid",
	"behind_is_ice",
	"behind_below_is_solid",
	"behind_below_is_ice",
	"here_is_water",
	"carrying_at_most",
	"mode_in",
]

static func has_predicate(name: String) -> bool:
	return PREDICATES.has(name)

static func is_known_node_type(type_name: String) -> bool:
	return NODE_TYPES.has(type_name)

## Vyhodnotí pojmenovaný predikát. `arg` je volitelný parametr ze stromu.
static func evaluate(name: String, ctx: BTContext, arg: Variant = null) -> bool:
	var probe := ctx.probe
	match name:
		"ahead_is_solid":
			return GridTypes.is_solid(probe.ahead())
		"ahead_is_ice":
			return probe.ahead() == GridTypes.BlockType.ICE
		"ahead_is_water":
			return probe.world.water_depth_at(probe.cell_ahead()) != GridTypes.WaterDepth.DRY
		"ahead_has_item":
			return probe.world.has_item_at(probe.cell_ahead())
		"ahead_is_passable":
			return can_enter(probe, probe.cell_ahead())
		"ahead_above_is_passable":
			return can_enter(probe, probe.cell_ahead_above())
		"above_is_passable":
			return can_enter(probe, probe.cell_above())
		"below_is_passable":
			return can_enter(probe, probe.cell_below())
		"ahead_below_is_solid":
			return GridTypes.is_solid(probe.ahead_below())
		"ahead_below_is_ice":
			return probe.ahead_below() == GridTypes.BlockType.ICE
		"ahead_below_is_dirt":
			return probe.ahead_below() == GridTypes.BlockType.DIRT
		"ahead_below_free_for_robot":
			return cell_free_for_robot(probe, probe.cell_ahead_below())
		"ahead_is_ramp_facing_me":
			# Šikmina před robotem stoupá ve směru jeho chůze → vyjde na ni.
			return probe.world.is_ramp_rising_toward(probe.cell_ahead(), probe.facing)
		"ahead_below_is_ramp_facing_away":
			# Šikmina šikmo dolů před robotem stoupá zpět k němu → sestup.
			return probe.world.is_ramp_rising_toward(probe.cell_ahead_below(),
					GridTypes.turn_around(probe.facing))
		"ahead_water_is_deep":
			return probe.world.water_depth_at(probe.cell_ahead()) == GridTypes.WaterDepth.DEEP
		"below_is_solid":
			return GridTypes.is_solid(probe.below())
		"behind_is_solid":
			return GridTypes.is_solid(probe.behind())
		"behind_is_ice":
			return probe.behind() == GridTypes.BlockType.ICE
		"behind_below_is_solid":
			# Hrana, ze které Net přelezl přes okraj — při prvním kroku
			# sešplhání je stěna teprve šikmo za ním, ne přímo za ním.
			return GridTypes.is_solid(
					probe.world.block_at(probe.cell_behind() + GridTypes.DOWN_VECTOR))
		"behind_below_is_ice":
			return probe.world.block_at(probe.cell_behind() + GridTypes.DOWN_VECTOR) \
					== GridTypes.BlockType.ICE
		"here_is_water":
			return probe.world.water_depth_at(probe.cell) != GridTypes.WaterDepth.DRY
		"carrying_at_most":
			var robot := probe.robot()
			if robot == null:
				return true
			return robot.inventory.size() <= int(arg)
		"mode_in":
			var modes: Array = arg if arg is Array else [arg]
			return modes.has(ctx.mode)
	push_error("Neznámý predikát ve stromě: %s" % name)
	return false

# ── Sdílené dotazy (§7.6.0) ────────────────────────────────────────────────

## `ahead_is_passable` v obecné podobě: může robot vstoupit do dané buňky?
## Řeší pevný blok, jiného robota, předmět (§12), vodu (§9.5) i zamčený cíl.
static func can_enter(probe: GridProbe, target: Vector3i) -> bool:
	var robot := probe.robot()
	var block := probe.world.block_at(target)

	if block == GridTypes.BlockType.OUTSIDE:
		return false
	if block == GridTypes.BlockType.TARGET:
		return target_is_open(probe.world, probe.robot_index)
	if GridTypes.is_solid(block):
		return false
	if not cell_free_for_robot(probe, target):
		return false

	# Předmět je překážka, pokud ho robot nesmí nebo nemá kam sebrat (§12).
	var item := probe.world.item_at(target)
	if item != GridTypes.NO_ITEM and robot != null and not robot.can_take(item):
		return false
	return true

## Buňka je volná pro robota z hlediska obsazenosti a hloubky vody.
static func cell_free_for_robot(probe: GridProbe, target: Vector3i) -> bool:
	var robot := probe.robot()
	if not probe.world.is_inside(target):
		return false
	if probe.robot_at_cell(target) != -1:
		return false
	if robot == null:
		return true
	var depth := probe.world.water_depth_at(target)
	if depth != GridTypes.WaterDepth.DRY and not GridTypes.can_enter_water(robot.kind):
		return false
	if depth == GridTypes.WaterDepth.DEEP and not GridTypes.can_enter_deep_water(robot.kind):
		return false
	return true

## Cíl je průchodný, když je odemčený, nebo jím prochází nositel klíče (§14).
static func target_is_open(world: WorldState, robot_index: int) -> bool:
	if world.target_unlocked:
		return true
	return world.key_holder == robot_index and robot_index != -1
