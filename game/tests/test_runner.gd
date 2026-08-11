class_name TestRunner
extends RefCounted

## Minimální testovací runner (§18). Vlastní, bez závislostí — pro čistý
## GDScript bez scén plně dostačuje.
## Spouští se přes: godot --headless --script tests/run_all.gd

var current_suite: String = ""
var current_test: String = ""
var checks: int = 0
var failures: Array = []
var tests_run: int = 0
var suites_run: int = 0

func run_suite(suite: TestSuite) -> void:
	suites_run += 1
	current_suite = suite.get_script().resource_path.get_file().get_basename()
	suite.t = self
	var seen := {}
	for method in suite.get_method_list():
		var name: String = method["name"]
		if not name.begins_with("test_") or seen.has(name):
			continue
		seen[name] = true
		current_test = name
		tests_run += 1
		suite.setup()
		suite.call(name)
		suite.teardown()
	current_test = ""

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append("%s :: %s — %s" % [current_suite, current_test, message])
	return condition

func equal(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected,
			"%s (očekáváno %s, dostal %s)" % [message, expected, actual])

func not_equal(actual: Variant, forbidden: Variant, message: String) -> bool:
	return check(actual != forbidden, "%s (nemělo být %s)" % [message, forbidden])

func is_true(value: bool, message: String) -> bool:
	return check(value, message + " (očekáváno true)")

func is_false(value: bool, message: String) -> bool:
	return check(not value, message + " (očekáváno false)")

func fail(message: String) -> void:
	check(false, message)

func print_summary() -> void:
	print("")
	print("─".repeat(64))
	print("Sad: %d   testů: %d   ověření: %d   chyb: %d"
			% [suites_run, tests_run, checks, failures.size()])
	if failures.is_empty():
		print("VŠE PROŠLO")
	else:
		print("SELHALO:")
		for failure in failures:
			print("  ✗ " + failure)
	print("─".repeat(64))

func exit_code() -> int:
	return 0 if failures.is_empty() else 1
