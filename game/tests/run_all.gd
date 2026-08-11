extends SceneTree

## Headless spouštěč testů (§18):
##     godot --headless --script tests/run_all.gd
##
## Runner je záměrně minimální a bez závislostí — celá simulace je čistý
## GDScript bez scén (P1), takže víc není potřeba.

func _initialize() -> void:
	var runner := TestRunner.new()
	var suites: Array = [
		TestGrid.new(),
		TestWater.new(),
		TestGravity.new(),
		TestTrees.new(),
		TestWalk.new(),
		TestHan.new(),
		TestItems.new(),
		TestDul.new(),
		TestSetYeo.new(),
		TestNetDa.new(),
		TestKeyTarget.new(),
		TestDevices.new(),
		TestIo.new(),
		TestValidator.new(),
		TestArchitecture.new(),
	]
	for suite in suites:
		runner.run_suite(suite)
	runner.print_summary()
	quit(runner.exit_code())
