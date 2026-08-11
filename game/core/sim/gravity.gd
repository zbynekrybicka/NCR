class_name Gravity
extends RefCounted

## Gravitace a usazování (§8). Po každé změně, která uvolní prostor pod
## blokem, předmětem nebo robotem, se svět usadí až do ustálení.
##
## Průchod odspodu nahoru (rostoucí Y, pak Z, pak X — což je přesně pořadí
## indexů buněk, §4) zaručuje, že sloupec spadne v jednom průchodu jako celek.

static func settle(world: WorldState, out_events: Array) -> void:
	for _iteration in GridTypes.MAX_SETTLE_ITERATIONS:
		var changed := false
		if _settle_blocks(world, out_events):
			changed = true
		if _settle_items(world):
			changed = true
		if _settle_robots(world, out_events):
			changed = true
		if not changed:
			return
	assert(false, "Usazování překročilo MAX_SETTLE_ITERATIONS — chyba v pravidlech")

static func _settle_blocks(world: WorldState, out_events: Array) -> bool:
	var changed := false
	for index in world.cell_count():
		var block := world.blocks[index]
		if not GridTypes.falls(block):
			continue
		var cell := world.index_to_cell(index)
		var below := cell + GridTypes.DOWN_VECTOR
		if not world.is_inside(below):
			continue
		if world.block_at(below) != GridTypes.BlockType.EMPTY:
			continue
		# Blok padající na robota nemá vzniknout — akce to kontrolují předem
		# (§8). Když se to přesto stane, je to chyba v pravidlech.
		if world.robot_at(below) != -1:
			assert(false, "Blok by spadl na robota na %s" % below)
			continue
		var orientation := world.orientation_at(cell)
		world.set_block(below, block)
		world.set_orientation(below, orientation)
		world.set_block(cell, GridTypes.BlockType.EMPTY)
		out_events.append(Event.block_fell(cell, below, block))
		changed = true
	return changed

static func _settle_items(world: WorldState) -> bool:
	var changed := false
	var cells: Array = world.items_on_ground.keys()
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	for cell in cells:
		var below: Vector3i = cell + GridTypes.DOWN_VECTOR
		if not world.is_inside(below):
			continue
		if world.is_solid_at(below) or world.has_item_at(below):
			continue
		var item: int = world.take_item_at(cell)
		world.put_item_at(below, item)
		changed = true
	return changed

## Robot na vrcholu propadající se věže klesne spolu s ní, aniž by se cokoli
## zničilo (design dokument §1.1.1) — pád je mírný a robotům neubližuje.
static func _settle_robots(world: WorldState, out_events: Array) -> bool:
	var changed := false
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		if robot.in_target:
			continue
		if robot.kind == GridTypes.RobotKind.DA:
			continue # létá, gravitaci nepodléhá
		var here := world.block_at(robot.cell)
		if here == GridTypes.BlockType.RAMP:
			continue # stojí na šikmině
		if world.water_depth_at(robot.cell) != GridTypes.WaterDepth.DRY \
				and robot.kind == GridTypes.RobotKind.DUL:
			continue # plave
		if world.has_support_below(robot.cell):
			continue
		var below := robot.cell + GridTypes.DOWN_VECTOR
		if not world.is_inside(below):
			continue
		if world.is_solid_at(below) or world.robot_at(below) != -1:
			continue
		var depth := world.water_depth_at(below)
		if depth == GridTypes.WaterDepth.DEEP and not GridTypes.can_enter_deep_water(robot.kind):
			continue
		if depth != GridTypes.WaterDepth.DRY and not GridTypes.can_enter_water(robot.kind):
			continue
		var from := robot.cell
		robot.cell = below
		out_events.append(Event.robot_moved(i, from, below, GridTypes.Substep.DOWN_VERTICAL))
		changed = true
	return changed

## Kam dopadne kostka/předmět puštěný v buňce `start` — první buňka, ve které
## spočine (§11, `landing_cell_for_drop`). Vrátí `start`, když je tam podklad
## hned; NO_CELL, když je `start` sám neprůchodný.
static func landing_cell_for_drop(world: WorldState, start: Vector3i) -> Vector3i:
	if not world.is_inside(start) or world.is_solid_at(start):
		return RobotState.NO_CELL
	var cell := start
	for _i in GridTypes.MAX_SETTLE_ITERATIONS:
		var below := cell + GridTypes.DOWN_VECTOR
		if not world.is_inside(below) or world.is_solid_at(below):
			return cell
		cell = below
	return cell
