class_name StepEvaluator
extends RefCounted

## Interpret kroku (§7.3). Vrátí frontu dílčích kroků, které se mají provést,
## nebo prázdné pole, když krok není možný.
##
## „Jeden krok" v design dokumentu = jeden příkaz hráče (STEP), ne jeden
## dílčí krok. Dokud strom vrací RUNNING, sonda postupuje dál a fronta roste;
## teprve SUCCESS/FAIL rozhodne, jestli se celá fronta provede, nebo zahodí.

static func evaluate(world: WorldState, robot_index: int) -> Array:
	var robot: RobotState = world.robots[robot_index]
	var probe := GridProbe.new(world, robot.cell, robot.facing, robot_index)
	var ctx := BTContext.new(probe)
	var tree := BTLibrary.tree_for(world, robot_index)
	if tree.is_empty():
		push_error("Robot %s nemá strom kroku" % robot.name_of())
		return []

	for _iteration in GridTypes.MAX_STEP_ITERATIONS:
		var queue_size_before := ctx.queue.size()
		var status := BTRuntime.tick(tree, ctx)
		match status:
			GridTypes.BTStatus.SUCCESS:
				if _rests_on_ramp(world, robot, ctx.probe.cell):
					return []
				return ctx.queue
			GridTypes.BTStatus.FAIL:
				return []
			GridTypes.BTStatus.RUNNING:
				# Kontrakt uzlu RUNNING: musí přidat dílčí krok i posunout sondu.
				assert(ctx.queue.size() > queue_size_before,
						"RUNNING uzel nepřidal dílčí krok — nekonečná smyčka ve stromě")
				if ctx.queue.size() == queue_size_before:
					return []
	# Ochrana proti zacyklení (§7.3).
	assert(false, "Krok překročil MAX_STEP_ITERATIONS — chyba ve stromě")
	return []

## Na šikmině nelze setrvat (design dok. §2.1.4), takže krok na ni nikdy nesmí
## být poslední — za ním musí následovat aspoň jeden další dílčí krok. Větve
## šikmin ve stromech proto vracejí RUNNING (režim `ramp`); tahle kontrola je
## pojistka pro všechny ostatní větve, které by robota na šikmině složily
## (rovná chůze na horní hranu, výlez Neta, vylezení Dula z vody).
##
## Da nad šikminou letí a Dul v zatopené šikmině plave — ti se jí nedotýkají,
## stejná výjimka jako v usazování (§8).
static func _rests_on_ramp(world: WorldState, robot: RobotState, cell: Vector3i) -> bool:
	if robot.kind == GridTypes.RobotKind.DA:
		return false
	if robot.kind == GridTypes.RobotKind.DUL \
			and world.water_depth_at(cell) != GridTypes.WaterDepth.DRY:
		return false
	return world.is_on_ramp(cell)
