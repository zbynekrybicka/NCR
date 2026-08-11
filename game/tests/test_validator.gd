class_name TestValidator
extends TestSuite

## §16.2 — validační pravidla V1–V14 nad LevelData.

func _valid_level() -> LevelData:
	return LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H+T") \
		.build()

func _has_rule(problems: Array, rule: String) -> bool:
	for problem in problems:
		if String(problem).begins_with(rule + " "):
			return true
	return false

func test_minimal_level_is_valid() -> void:
	var problems := LevelValidator.validate(_valid_level())
	t.is_true(problems.is_empty(), "minimální level projde: " + ", ".join(problems))

func test_v1_key_must_be_inside() -> void:
	var level := _valid_level()
	level.key_position = Vector3i(99, 0, 0)
	t.is_true(_has_rule(LevelValidator.validate(level), "V1"), "klíč mimo level")

func test_v2_exactly_one_target() -> void:
	var level := _valid_level()
	level.set_block(Vector3i(3, 1, 0), GridTypes.BlockType.EMPTY)
	t.is_true(_has_rule(LevelValidator.validate(level), "V2"), "level bez cíle")
	level.set_block(Vector3i(3, 1, 0), GridTypes.BlockType.TARGET)
	level.set_block(Vector3i(0, 1, 0), GridTypes.BlockType.TARGET)
	t.is_true(_has_rule(LevelValidator.validate(level), "V2"), "level se dvěma cíli")

func test_v3_each_robot_kind_at_most_once() -> void:
	var level := _valid_level()
	level.robots.append(LevelData.RobotPlacement.new(GridTypes.RobotKind.HAN,
			Vector3i(2, 1, 0), GridTypes.Direction.EAST, 1))
	t.is_true(_has_rule(LevelValidator.validate(level), "V3"), "dva Hanové")

func test_v4_robot_needs_ground() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, "..+T") \
		.layer(2, ".H..") \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V4"), "robot visí ve vzduchu")

func test_v5_no_floating_blocks() -> void:
	var level := _valid_level()
	level.set_block(Vector3i(0, 1, 0), GridTypes.BlockType.STONE)
	t.is_false(_has_rule(LevelValidator.validate(level), "V5"),
			"kámen na podlaze je v pořádku")
	var floating := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H+T") \
		.layer(2, "S...") \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(floating), "V5"), "kámen ve vzduchu")

func test_v6_nothing_on_a_ramp() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H+T") \
		.build()
	level.set_block(Vector3i(0, 1, 0), GridTypes.BlockType.RAMP)
	level.items.append(LevelData.ItemPlacement.new(GridTypes.ItemType.FUEL,
			Vector3i(0, 2, 0)))
	t.is_true(_has_rule(LevelValidator.validate(level), "V6"),
			"na šikmině nesmí nic ležet")

func test_v7_ice_only_inside_a_reservoir() -> void:
	var level := _valid_level()
	level.set_block(Vector3i(0, 1, 0), GridTypes.BlockType.ICE)
	t.is_true(_has_rule(LevelValidator.validate(level), "V7"), "led mimo nádrž")

func test_v11_reservoir_must_be_closed() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".H+T") \
		.reservoir(Vector3i(0, 1, 0), 0) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V11"), "otevřená dutina není nádrž")

func test_v12_sequence_is_a_permutation() -> void:
	var level := _valid_level()
	level.robots[0].sequence_index = 3
	t.is_true(_has_rule(LevelValidator.validate(level), "V12"), "díra v sekvenci")

func test_v13_volume_fits_the_capacity() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 999) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V13"), "objem nad kapacitu")

func test_v10_pump_must_not_drain_unlimited() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 2, true) \
		.reservoir(Vector3i(2, 1, 1), 2) \
		.pump(0, 1, -1) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V10"),
			"čerpat z neomezené nádrže nelze")

func test_v14_no_robot_starts_in_deep_water() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 8) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V14"),
			"Han by se hned na startu utopil")

# ── Editor (§16.1) ─────────────────────────────────────────────────────────

func test_undo_restores_the_exact_level() -> void:
	var session := EditorSession.new(_valid_level())
	var before := session.level.blocks.duplicate()
	session.run(EditorOperation.SetCell.new(Vector3i(0, 1, 0),
			GridTypes.BlockType.STONE, 7, GridTypes.Direction.SOUTH))
	t.equal(session.level.block_at(Vector3i(0, 1, 0)), GridTypes.BlockType.STONE,
			"operace se provedla")
	session.undo()
	t.equal(session.level.blocks, before, "undo vrátil přesně původní data")
	session.redo()
	t.equal(session.level.block_at(Vector3i(0, 1, 0)), GridTypes.BlockType.STONE,
			"redo operaci zopakuje")

func test_place_robot_moves_the_existing_one() -> void:
	var session := EditorSession.new(_valid_level())
	session.run(EditorOperation.PlaceRobot.new(GridTypes.RobotKind.HAN,
			Vector3i(2, 1, 0), GridTypes.Direction.WEST, 0))
	t.equal(session.level.robots.size(), 1, "robot se nezdvojil")
	t.equal(session.level.robots[0].cell, Vector3i(2, 1, 0), "jen se přesunul")
	session.undo()
	t.equal(session.level.robots[0].cell, Vector3i(1, 1, 0), "undo ho vrátil zpátky")

func test_resize_drops_objects_outside() -> void:
	var session := EditorSession.new(_valid_level())
	session.run(EditorOperation.Resize.new(Vector3i(2, 2, 1)))
	t.equal(session.level.size, Vector3i(2, 2, 1), "level se zmenšil")
	t.equal(session.level.robots.size(), 1, "Han se do nového rozměru vešel")
	t.equal(session.level.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.EMPTY,
			"zbylá data sedí")
	session.undo()
	t.equal(session.level.size, Vector3i(4, 2, 1), "undo vrátil původní rozměr")
	t.equal(session.level.block_at(Vector3i(3, 1, 0)), GridTypes.BlockType.TARGET,
			"i smazaný cíl")

func test_playtest_runs_on_a_copy() -> void:
	var session := EditorSession.new(_valid_level())
	var sim := session.start_playtest()
	sim.submit_command(Command.new(Command.CommandType.STEP))
	t.equal(sim.world.robots[0].cell, Vector3i(2, 1, 0), "náhled se hraje")
	t.equal(session.level.robots[0].cell, Vector3i(1, 1, 0),
			"editovaná data se náhledem nezmění")
