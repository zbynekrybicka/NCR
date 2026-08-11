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
