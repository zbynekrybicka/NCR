class_name ActionHelpers
extends RefCounted

## Sdílené validační predikáty akcí (§11). Jedna implementace, používá je víc
## akcí. Žádný z nich nemutuje stav.

static func behind_cell(world: WorldState, robot_index: int) -> Vector3i:
	var robot: RobotState = world.robots[robot_index]
	return robot.cell - GridTypes.dir_vector(robot.facing)

static func ahead_cell(world: WorldState, robot_index: int) -> Vector3i:
	var robot: RobotState = world.robots[robot_index]
	return robot.cell + GridTypes.dir_vector(robot.facing)

## Han a2, Set/Net/Yeo/Il a2 — robot nesmí stát zády přímo u zdi.
static func has_free_space_behind(world: WorldState, robot_index: int) -> bool:
	var cell := behind_cell(world, robot_index)
	if not world.is_inside(cell):
		return false
	return not world.is_solid_at(cell)

## Han a1, Set a1 — přímo pod odebíranou kostkou nesmí stát JINÝ robot
## (design dokument §1.1.1, §1.1.3). Sám sebe robot neblokuje.
static func no_robot_below(world: WorldState, cell: Vector3i, ignore_index: int = -1) -> bool:
	var found := world.robot_at(cell + GridTypes.DOWN_VECTOR)
	return found == -1 or found == ignore_index

static func no_robot_at(world: WorldState, cell: Vector3i, ignore_index: int = -1) -> bool:
	var found := world.robot_at(cell)
	return found == -1 or found == ignore_index

## Kam dopadne kostka/předmět (§11) — delegace na gravitaci, aby platila
## stejná pravidla dopadu jako při usazování.
static func landing_cell_for_drop(world: WorldState, start: Vector3i) -> Vector3i:
	return Gravity.landing_cell_for_drop(world, start)

## Dul a1/a2 — nádrž, na kterou Dul ze břehu dosáhne hadicí ve směru `cell`.
## Robot stojící na břehu má nohy o patro výš než hladina (buňka v jeho rovině
## je vzduch nad nádrží, sama členem nádrže není — voda by z ní přetekla na
## břeh, takže ji §9.1 vyloučí z dutiny). Hledá se proto nejdřív v rovině
## robota a pak o patro níž. Přes pevný blok (včetně ledu) hadice nedosáhne.
static func reservoir_within_reach(world: WorldState, cell: Vector3i) -> int:
	var probes: Array[Vector3i] = [cell, cell + GridTypes.DOWN_VECTOR]
	for probe in probes:
		if not world.is_inside(probe) or world.is_solid_at(probe):
			return -1
		var index := world.reservoir_at(probe)
		if index != -1:
			return index
	return -1

static func has_item(world: WorldState, robot_index: int, item: int) -> bool:
	var robot: RobotState = world.robots[robot_index]
	return robot.has_item(item)

static func inventory_has_room(world: WorldState, robot_index: int) -> bool:
	var robot: RobotState = world.robots[robot_index]
	return robot.has_inventory_room()

## Yeo a1 — pevný podklad, nebo jiná kostka ledu.
static func standing_on_solid_or_ice(world: WorldState, robot_index: int) -> bool:
	var robot: RobotState = world.robots[robot_index]
	return world.has_support_below(robot.cell)

## Vybere předmět k odložení: preferovaný typ, jinak poslední v inventáři.
static func item_to_drop(world: WorldState, robot_index: int, preferred: int) -> int:
	var robot: RobotState = world.robots[robot_index]
	if robot.inventory.is_empty():
		return GridTypes.NO_ITEM
	if preferred != GridTypes.NO_ITEM and robot.has_item(preferred):
		return preferred
	return robot.inventory[robot.inventory.size() - 1]
