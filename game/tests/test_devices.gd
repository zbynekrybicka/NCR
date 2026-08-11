class_name TestDevices
extends TestSuite

## §13 — Il ovládá plošinu, hmotnostní limit, přenos čerpadlem s kontrolou
## utonutí (celý, ne částečný), oprava zařízení service kitem.

## Il stojí u řídicí jednotky ve zdi; vedle je plošina a napájecí skříň.
## Zařízení: 0 = napájecí skříň, 1 = řídicí jednotka.
func _platform_level(weight_limit: int = 2, rider: bool = false) -> Simulation:
	var builder := LevelBuilder.new() \
		.layer(0, "#####") \
		.layer(1, ".L###") \
		.layer(2, "...H." if rider else ".....") \
		.layer(3, ".....") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(4, 1, 0),
				GridTypes.Direction.WEST) \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST, GridTypes.ControlMode.BUTTON) \
		.platform([Vector3i(3, 1, 0)], Vector3i.ZERO, Vector3i(0, 1, 0),
				weight_limit, [0], [1])
	return builder.simulate()

func test_il_takes_control_and_moves_the_platform() -> void:
	var sim := _platform_level()
	var taken := action_1(sim)
	t.is_true(taken.accepted, "Il převezme kontrolu nad řídicí jednotkou")
	t.equal(sim.world.robots[0].controlling_device, 1, "drží si ovládané zařízení")
	t.is_true(taken.has_event(Event.EventType.DEVICE_CONTROL_TAKEN), "událost převzetí")

	var input := submit(sim, Command.CommandType.DEVICE_INPUT)
	t.is_true(input.accepted, "vstup do zařízení projde")
	t.equal(sim.world.block_at(Vector3i(3, 2, 0)), GridTypes.BlockType.WALL,
			"plošina přejela do druhé polohy")
	t.equal(sim.world.block_at(Vector3i(3, 1, 0)), GridTypes.BlockType.EMPTY,
			"a v původní poloze už není")
	t.is_true(input.has_event(Event.EventType.PLATFORM_MOVED), "událost přejezdu")

func test_control_survives_robot_switch() -> void:
	var sim := _platform_level(2, true)
	action_1(sim)
	t.equal(sim.world.robots[0].controlling_device, 1, "Il ovládá jednotku")
	submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 1)
	submit(sim, Command.CommandType.SWITCH_ROBOT_TO, 0)
	t.equal(sim.world.robots[0].controlling_device, 1,
			"ovládání přepnutí robota přežije (§13.1)")
	var released := action_2(sim)
	t.is_true(released.accepted, "akce 2 ovládání ukončí")
	t.equal(sim.world.robots[0].controlling_device, -1, "a Il je zase sám za sebe")

func test_platform_carries_the_robot_standing_on_it() -> void:
	var sim := _platform_level(2, true)
	t.equal(sim.world.robots[1].cell, Vector3i(3, 2, 0), "Han stojí na plošině")
	action_1(sim)
	submit(sim, Command.CommandType.DEVICE_INPUT)
	t.equal(sim.world.robots[1].cell, Vector3i(3, 3, 0), "vyjel s plošinou nahoru")

func test_platform_respects_the_weight_limit() -> void:
	var sim := _platform_level(1, true)
	action_1(sim)
	var input := submit(sim, Command.CommandType.DEVICE_INPUT)
	t.is_false(input.accepted, "přetížená plošina se nehne")
	t.equal(sim.world.block_at(Vector3i(3, 1, 0)), GridTypes.BlockType.WALL,
			"plošina zůstala dole")

func test_broken_device_needs_a_service_kit() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".L#.") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST, GridTypes.ControlMode.BUTTON, true) \
		.simulate()
	t.is_false(action_1(sim).accepted, "rozbité zařízení bez kitu opravit nejde")
	sim.world.robots[0].inventory.append(GridTypes.ItemType.SERVICE_KIT)
	var repaired := action_1(sim)
	t.is_true(repaired.accepted, "se service kitem ano")
	t.is_false(sim.world.devices[0].is_broken, "zařízení je opravené")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "kit se spotřeboval")
	t.is_true(repaired.has_event(Event.EventType.DEVICE_REPAIRED), "událost opravy")

func test_il_must_stand_in_the_access_direction() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".L#.") \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(2, 1, 0),
				GridTypes.Direction.NORTH) \
		.simulate()
	t.is_false(action_1(sim).accepted, "ze špatné strany se zařízení ovládat nedá")

# ── Čerpadla ───────────────────────────────────────────────────────────────

## Dvě oddělené nádrže (x 1–3 a x 6–8), mezi nimi zeď; čerpadlo 0: A → B.
func _pump_world(volume_a: int, volume_b: int, robot_in_b: bool = false) -> WorldState:
	var pool_b := "#H..#" if robot_in_b else "#...#"
	var level := LevelBuilder.new() \
		.layer(0, "##########\n##########\n##########") \
		.layer(1, "##########\n#...#" + pool_b + "\n##########") \
		.layer(2, "##########\n#...##...#\n##########") \
		.reservoir(Vector3i(1, 1, 1), volume_a) \
		.reservoir(Vector3i(6, 1, 1), volume_b) \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(4, 1, 1),
				GridTypes.Direction.WEST) \
		.pump(0, 1, 0) \
		.build()
	var world := WorldState.from_level(level)
	DeviceSystem.initialize(world)
	return world

func test_pump_transfers_one_cube() -> void:
	var world := _pump_world(4, 0)
	t.equal(world.reservoirs.size(), 2, "dvě nádrže")
	t.equal(world.reservoirs[0].cells.size(), 6, "nádrž A má šest buněk")
	t.equal(world.reservoirs[1].cells.size(), 6, "nádrž B taky")
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_true(validation.ok, "přenos je možný: " + validation.reason)
	var events: Array = []
	DeviceSystem.transfer(world, 0, validation, events)
	t.equal(world.reservoirs[0].volume_units, 2, "ze zdroje ubyla kostka")
	t.equal(world.reservoirs[1].volume_units, 2, "do cíle přibyla")

func test_pump_stops_completely_when_someone_would_drown() -> void:
	var world := _pump_world(4, 2, true)
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_false(validation.ok, "přenos, který by někoho utopil, se neprovede vůbec")
	t.equal(world.reservoirs[0].volume_units, 4, "zdroj se nezměnil")
	t.equal(world.reservoirs[1].volume_units, 2, "cíl taky ne")

func test_pump_needs_water_in_the_source() -> void:
	var world := _pump_world(1, 0)
	t.is_false(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"z prázdné nádrže se nečerpá")

func test_pump_must_not_drain_an_unlimited_reservoir() -> void:
	var world := _pump_world(4, 0)
	world.reservoirs[0].unlimited = true
	t.is_false(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"z neomezené nádrže čerpadlo čerpat nesmí (§13.3)")
