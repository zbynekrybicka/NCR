class_name TestTrees
extends TestSuite

## §7.5 — soubory stromů jsou data (P7). Test hlídá, že jdou načíst a že
## odkazují jen na známé uzly a registrované predikáty.

func test_all_trees_load_and_are_well_formed() -> void:
	for tree_name in BTLibrary.ALL_TREES:
		var root := BTLibrary.load_tree(tree_name)
		t.is_false(root.is_empty(), "strom %s se načetl" % tree_name)
		var problems: Array = []
		BTRuntime.validate_tree(root, problems, tree_name)
		t.is_true(problems.is_empty(),
				"strom %s je dobře utvořený: %s" % [tree_name, ", ".join(problems)])

func test_every_robot_kind_has_a_tree() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#########") \
		.layer(1, ".HUENAYL.") \
		.build()
	var world := WorldState.from_level(level)
	for i in world.robots.size():
		var tree_name := BTLibrary.tree_name_for(world, i)
		t.is_true(BTLibrary.ALL_TREES.has(tree_name),
				"%s má přiřazený strom (%s)" % [world.robots[i].name_of(), tree_name])
		t.is_false(BTLibrary.load_tree(tree_name).is_empty(),
				"a ten strom existuje")

func test_unknown_predicate_is_reported() -> void:
	var problems: Array = []
	BTRuntime.validate_tree({
		"type": "sequence",
		"children": [{"type": "condition", "predicate": "neexistujici_predikat"}],
	}, problems)
	t.equal(problems.size(), 1, "neznámý predikát se ohlásí")

func test_running_node_contract() -> void:
	# Uzel, který vrací RUNNING, musí přidat dílčí krok i posunout sondu.
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "###")
		.layer(1, ".H.")
		.build())
	var probe := GridProbe.new(world, Vector3i(1, 1, 0), GridTypes.Direction.EAST, 0)
	var ctx := BTContext.new(probe)
	var status := BTRuntime.tick({"type": "emit_continue", "substep": 0, "mode": "slide"}, ctx)
	t.equal(status, GridTypes.BTStatus.RUNNING, "emit_continue vrací RUNNING")
	t.equal(ctx.queue.size(), 1, "a přidal dílčí krok")
	t.equal(ctx.probe.cell, Vector3i(2, 1, 0), "a posunul sondu")
	t.equal(ctx.mode, "slide", "a nastavil režim smyčky")
