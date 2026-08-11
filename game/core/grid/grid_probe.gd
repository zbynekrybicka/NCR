class_name GridProbe
extends RefCounted

## Dotazování mřížky (§7.2) — náhrada raycastů z design dokumentu (P4).
## Sonda nese pozici a orientaci; strom kroku čte svět výhradně přes ni.
##
## Lokální rámec: +X vpravo, +Y nahoru, -Z vpřed vzhledem k `facing`.

var world: WorldState
var cell: Vector3i
var facing: int
var robot_index: int

func _init(p_world: WorldState, p_cell: Vector3i, p_facing: int, p_robot_index: int = -1) -> void:
	world = p_world
	cell = p_cell
	facing = p_facing
	robot_index = p_robot_index

func robot() -> RobotState:
	if robot_index < 0 or robot_index >= world.robots.size():
		return null
	return world.robots[robot_index]

# ── Převod souřadnic ───────────────────────────────────────────────────────

func forward_vector() -> Vector3i:
	return GridTypes.dir_vector(facing)

func right_vector() -> Vector3i:
	return GridTypes.dir_vector(GridTypes.turn_right(facing))

func global_of(offset: Vector3i) -> Vector3i:
	return cell + right_vector() * offset.x \
		+ GridTypes.UP_VECTOR * offset.y \
		+ forward_vector() * (-offset.z)

# ── Buňky v okolí ──────────────────────────────────────────────────────────

func cell_ahead(n: int = 1) -> Vector3i:
	return cell + forward_vector() * n

func cell_behind(n: int = 1) -> Vector3i:
	return cell - forward_vector() * n

func cell_below(n: int = 1) -> Vector3i:
	return cell + GridTypes.DOWN_VECTOR * n

func cell_above(n: int = 1) -> Vector3i:
	return cell + GridTypes.UP_VECTOR * n

func cell_ahead_below() -> Vector3i:
	return cell_ahead() + GridTypes.DOWN_VECTOR

func cell_ahead_above() -> Vector3i:
	return cell_ahead() + GridTypes.UP_VECTOR

# ── Obsah buněk ────────────────────────────────────────────────────────────

func block_at(offset: Vector3i) -> int:
	return world.block_at(global_of(offset))

func ahead(n: int = 1) -> int:
	return world.block_at(cell_ahead(n))

func behind(n: int = 1) -> int:
	return world.block_at(cell_behind(n))

func below(n: int = 1) -> int:
	return world.block_at(cell_below(n))

func above(n: int = 1) -> int:
	return world.block_at(cell_above(n))

func ahead_below() -> int:
	return world.block_at(cell_ahead_below())

func ahead_above() -> int:
	return world.block_at(cell_ahead_above())

func here() -> int:
	return world.block_at(cell)

func robot_at(offset: Vector3i) -> int:
	return world.robot_at(global_of(offset))

func robot_at_cell(target: Vector3i) -> int:
	var index := world.robot_at(target)
	if index == robot_index:
		return -1 # sonda vlastního robota nevidí jako překážku
	return index

func item_at(offset: Vector3i) -> int:
	return world.item_at(global_of(offset))

func water_depth_at(offset: Vector3i) -> int:
	return world.water_depth_at(global_of(offset))

func water_depth_here() -> int:
	return world.water_depth_at(cell)

func is_outside(offset: Vector3i) -> bool:
	return not world.is_inside(global_of(offset))

# ── Posun sondy (RUNNING větve stromu, §7.3) ───────────────────────────────

func advance(substep: int) -> void:
	cell += GridTypes.substep_delta(substep, facing)

func duplicate_probe() -> GridProbe:
	return GridProbe.new(world, cell, facing, robot_index)
