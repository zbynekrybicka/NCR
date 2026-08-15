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
		.layer(2, "....") \
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
		.pump(0, 1, []) \
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

# ── V15, V16, V17 — mechanismy ─────────────────────────────────────────────

## Level se zařízením ve zdi: skříň 0 na (2,1,0), ovládaná ze západu.
func _device_level() -> LevelData:
	return LevelBuilder.new() \
		.layer(0, "#####") \
		.layer(1, ".H#+T") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST) \
		.build()

func test_v15_device_sits_in_a_wall_cube() -> void:
	t.is_false(_has_rule(LevelValidator.validate(_device_level()), "V15"),
			"zařízení v kostce zdi je v pořádku")
	var level := _device_level()
	level.set_block(Vector3i(2, 1, 0), GridTypes.BlockType.EMPTY)
	t.is_true(_has_rule(LevelValidator.validate(level), "V15"),
			"zařízení mimo kostku zdi je chyba")

func test_v15_device_needs_a_horizontal_access_direction() -> void:
	var level := _device_level()
	level.devices[0].access_direction = GridTypes.Direction.UP
	t.is_true(_has_rule(LevelValidator.validate(level), "V15"),
			"shora se zařízení ovládat nedá")

func test_v15_device_needs_solid_ground() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#####") \
		.layer(1, ".H.+T") \
		.layer(2, "..#..") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 2, 0),
				GridTypes.Direction.WEST) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V15"),
			"zařízení visící ve vzduchu je chyba")

func test_v16_platform_is_made_of_walls() -> void:
	# Zařízení je pevnou součástí plošiny a jede s ní (design dok. §2.2.1).
	var level := _device_level()
	level.platforms.append(_platform_def([Vector3i(2, 1, 0)], Vector3i(0, 1, 0), 2, [0]))
	t.is_false(_has_rule(LevelValidator.validate(level), "V16"),
			"plošina smí vézt zařízení")

	var free_platform := LevelBuilder.new() \
		.layer(0, "#####") \
		.layer(1, ".H.+T") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST) \
		.build()
	free_platform.platforms.append(
			_platform_def([Vector3i(4, 0, 0)], Vector3i(0, 1, 0), 2, [0]))
	t.is_false(_has_rule(LevelValidator.validate(free_platform), "V16"),
			"plošina ze zdi projde")
	free_platform.platforms[0].cells = [Vector3i(1, 1, 0)]
	t.is_true(_has_rule(LevelValidator.validate(free_platform), "V16"),
			"plošina z prázdné buňky ne")

func test_v16_automatic_platform_needs_a_threshold() -> void:
	var level := _device_level()
	level.platforms.append(_platform_def([Vector3i(4, 0, 0)], Vector3i(0, 1, 0), 0, [0]))
	t.is_true(_has_rule(LevelValidator.validate(level), "V16"),
			"automatická plošina s nulovým prahem by jela hned na startu")

func test_v17_links_must_point_to_the_right_devices() -> void:
	var level := _device_level()
	# Index 0 je skříň, ne řídicí jednotka.
	level.platforms.append(_platform_def([Vector3i(4, 0, 0)], Vector3i(0, 1, 0), 2, [0], [0]))
	t.is_true(_has_rule(LevelValidator.validate(level), "V17"),
			"skříň se nedá použít jako řídicí jednotka")

	var missing := _device_level()
	missing.platforms.append(_platform_def([Vector3i(4, 0, 0)], Vector3i(0, 1, 0), 2, [7]))
	t.is_true(_has_rule(LevelValidator.validate(missing), "V17"),
			"vazba na neexistující zařízení je chyba")

func test_v10_pump_needs_a_cabinet() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), 2) \
		.reservoir(Vector3i(2, 2, 1), 2) \
		.pump(0, 1, []) \
		.build()
	t.is_true(_has_rule(LevelValidator.validate(level), "V10"),
			"čerpadlo bez elektrické skříně nefunguje")

func _platform_def(cells: Array, pose_b: Vector3i, weight_limit: int,
		cabinets: Array, control_units: Array = []) -> LevelData.PlatformDef:
	var def := LevelData.PlatformDef.new()
	def.cells = cells
	def.pose_b = pose_b
	def.weight_limit = weight_limit
	def.linked_cabinets = cabinets
	def.linked_control_units = control_units
	return def

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

# ── Editor: mechanismy (§13, §16) ──────────────────────────────────────────

func test_place_device_puts_a_wall_under_it() -> void:
	var session := EditorSession.new(_valid_level())
	session.run(EditorOperation.PlaceDevice.new(Vector3i(2, 1, 0),
			GridTypes.DeviceKind.CONTROL_UNIT, GridTypes.Direction.WEST,
			GridTypes.ControlMode.SWITCH))
	t.equal(session.level.devices.size(), 1, "zařízení přibylo")
	t.equal(session.level.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.WALL,
			"a sedí ve vlastní kostce zdi")
	session.undo()
	t.is_true(session.level.devices.is_empty(), "undo zařízení odebral")
	t.equal(session.level.block_at(Vector3i(2, 1, 0)), GridTypes.BlockType.EMPTY,
			"i kostku zdi")

func test_remove_device_renumbers_links() -> void:
	var session := EditorSession.new(_valid_level())
	session.run(EditorOperation.PlaceDevice.new(Vector3i(0, 1, 0),
			GridTypes.DeviceKind.POWER_CABINET, GridTypes.Direction.EAST))
	session.run(EditorOperation.PlaceDevice.new(Vector3i(2, 1, 0),
			GridTypes.DeviceKind.POWER_CABINET, GridTypes.Direction.WEST))
	session.run(EditorOperation.AddPlatform.new([Vector3i(0, 0, 0)], Vector3i(0, 1, 0),
			2, [1]))
	session.run(EditorOperation.RemoveDevice.new(Vector3i(0, 1, 0)))
	t.equal(session.level.devices.size(), 1, "zbylo jedno zařízení")
	t.equal(session.level.platforms[0].linked_cabinets, [0],
			"vazba plošiny se přečíslovala na zbylou skříň")
	session.undo()
	t.equal(session.level.platforms[0].linked_cabinets, [1],
			"undo vrátil původní číslování")

func test_reservoir_operations() -> void:
	var session := EditorSession.new(LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.build())
	t.is_true(session.cell_is_in_closed_cavity(Vector3i(1, 2, 1)),
			"dutina nad podlahou je uzavřená")
	t.is_false(session.cell_is_in_closed_cavity(Vector3i(0, 2, 0)),
			"buňka u okraje levelu nádrž být nemůže")

	session.run(EditorOperation.SetReservoir.new(Vector3i(1, 2, 1), 4))
	t.equal(session.level.reservoirs.size(), 1, "nádrž vznikla")
	# Dutina sahá přes obě patra (3 buňky nahoře + 2 dole u Hana a klíče),
	# kapacita je součet jejich půlkostkových jednotek (§9.1).
	t.equal(session.reservoir_capacity(0), 10, "kapacita se odvodila z geometrie")
	t.equal(session.reservoir_index_at(Vector3i(2, 2, 1)), 0,
			"sousední buňka patří téže nádrži")

	session.run(EditorOperation.SetReservoir.new(Vector3i(1, 2, 1), 2, true))
	t.equal(session.level.reservoirs.size(), 1, "druhý klik nádrž nezdvojí")
	t.is_true(session.level.reservoirs[0].unlimited, "jen upraví nastavení")
	session.undo()
	t.equal(session.level.reservoirs[0].volume_units, 4, "undo vrátil původní objem")

func test_remove_reservoir_drops_dependent_pumps() -> void:
	var session := EditorSession.new(LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H+T#\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.build())
	session.run(EditorOperation.SetReservoir.new(Vector3i(1, 2, 1), 4))
	session.run(EditorOperation.SetReservoir.new(Vector3i(3, 1, 1), 0))
	session.run(EditorOperation.PlaceDevice.new(Vector3i(2, 1, 0),
			GridTypes.DeviceKind.POWER_CABINET, GridTypes.Direction.WEST))
	session.run(EditorOperation.AddPump.new(0, 1, [0]))
	t.equal(session.level.pumps.size(), 1, "čerpadlo vzniklo")
	session.run(EditorOperation.RemoveReservoir.new(Vector3i(1, 2, 1)))
	t.is_true(session.level.pumps.is_empty(), "čerpadlo bez nádrže se odebralo taky")
	session.undo()
	t.equal(session.level.pumps.size(), 1, "undo vrátil čerpadlo i nádrž")
	t.equal(session.level.reservoirs.size(), 2, "obě nádrže jsou zpátky")

func test_editor_can_build_a_valid_level_with_mechanisms() -> void:
	# Dvě uzavřené kapsy na vodu (x = 5 a x = 7), mezi nimi zeď se skříní
	# a řídicí jednotkou, a manuální plošina ze zdi nad Hanem.
	var session := EditorSession.new(LevelBuilder.new() \
		.layer(0, "#########\n#########\n#########") \
		.layer(1, "#########\n#H+T#.#.#\n#########") \
		.layer(2, "#########\n##..#.#.#\n#########") \
		.layer(3, ".........\n.........\n.........") \
		.build())
	session.run(EditorOperation.SetReservoir.new(Vector3i(5, 1, 1), 4))
	session.run(EditorOperation.SetReservoir.new(Vector3i(7, 1, 1), 0))
	session.run(EditorOperation.PlaceDevice.new(Vector3i(6, 1, 1),
			GridTypes.DeviceKind.POWER_CABINET, GridTypes.Direction.WEST))
	session.run(EditorOperation.PlaceDevice.new(Vector3i(6, 2, 1),
			GridTypes.DeviceKind.CONTROL_UNIT, GridTypes.Direction.WEST,
			GridTypes.ControlMode.BUTTON))
	session.run(EditorOperation.AddPump.new(0, 1, [0], 1))
	session.run(EditorOperation.AddPlatform.new([Vector3i(1, 2, 1)], Vector3i(0, 1, 0),
			2, [0], [1]))
	var problems := session.validate()
	t.is_true(problems.is_empty(),
			"level s nádržemi, čerpadlem i plošinou je validní: " + ", ".join(problems))

	# A dá se rovnou hrát — mechanismy se přenesou do simulace.
	var sim := session.start_playtest()
	t.equal(sim.world.reservoirs.size(), 2, "obě nádrže jsou v simulaci")
	t.equal(sim.world.pumps[0].linked_cabinets, [0], "čerpadlo si drží vazbu na skříň")
	t.equal(sim.world.platforms[0].weight_limit, 2, "plošina si drží práh")

func test_playtest_runs_on_a_copy() -> void:
	var session := EditorSession.new(_valid_level())
	var sim := session.start_playtest()
	sim.submit_command(Command.new(Command.CommandType.STEP))
	t.equal(sim.world.robots[0].cell, Vector3i(2, 1, 0), "náhled se hraje")
	t.equal(session.level.robots[0].cell, Vector3i(1, 1, 0),
			"editovaná data se náhledem nezmění")
