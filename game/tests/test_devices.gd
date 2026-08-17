class_name TestDevices
extends TestSuite

## §13 — Il ovládá plošinu, hmotnostní limit, přenos čerpadlem s kontrolou
## utonutí (celý, ne částečný), oprava zařízení service kitem.

## Il stojí u řídicí jednotky ve zdi; vedle je plošina a napájecí skříň.
## Zařízení: 0 = napájecí skříň, 1 = řídicí jednotka.
## `weight_limit` je spouštěcí práh, ne nosnost (design dok. §2.2.1).
func _platform_level(weight_limit: int = 0, rider: bool = false) -> Simulation:
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

## Jeden stisk akce 1 = jedno sepnutí; žádný režim ovládání neexistuje
## (design dok. §1.1.7).
func test_il_switches_the_control_unit_and_moves_the_platform() -> void:
	var sim := _platform_level()
	var input := action_1(sim)
	t.is_true(input.accepted, "Il sepne řídicí jednotku")
	t.equal(sim.world.block_at(Vector3i(3, 2, 0)), GridTypes.BlockType.WALL,
			"plošina přejela do druhé polohy")
	t.equal(sim.world.block_at(Vector3i(3, 1, 0)), GridTypes.BlockType.EMPTY,
			"a v původní poloze už není")
	t.is_true(input.has_event(Event.EventType.PLATFORM_MOVED), "událost přejezdu")

## Sepnutí funkční skříně přepíná napájení (§13.1, O8).
func test_il_toggles_the_power_cabinet() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".L#.") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST) \
		.simulate()
	t.is_true(sim.world.devices[0].is_on, "skříň bez poruchy startuje pod napětím")

	var off := action_1(sim)
	t.is_true(off.accepted, "stisk projde")
	t.is_false(sim.world.devices[0].is_on, "a skříň vypne")
	t.is_true(off.has_event(Event.EventType.DEVICE_TOGGLED), "událost přepnutí")

	action_1(sim)
	t.is_true(sim.world.devices[0].is_on, "další stisk ji zase zapne")

## Akce 2 Ila jen odkládá service kit — žádné opouštění ovládání už neexistuje.
func test_il_action_2_drops_the_service_kit() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "####") \
		.layer(1, ".L#.") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST) \
		.simulate()
	t.is_false(action_2(sim).accepted, "s prázdným inventářem není co odložit")

	sim.world.robots[0].inventory.append(GridTypes.ItemType.SERVICE_KIT)
	var dropped := action_2(sim)
	t.is_true(dropped.accepted, "kit se odloží")
	t.is_true(sim.world.robots[0].inventory.is_empty(), "a zmizí z inventáře")
	t.equal(sim.world.item_at(Vector3i(0, 1, 0)), GridTypes.ItemType.SERVICE_KIT,
			"leží za robotem")

func test_platform_carries_the_robot_standing_on_it() -> void:
	var sim := _platform_level(2, true)
	t.equal(sim.world.robots[1].cell, Vector3i(3, 2, 0), "Han stojí na plošině")
	action_1(sim)
	t.equal(sim.world.robots[1].cell, Vector3i(3, 3, 0), "vyjel s plošinou nahoru")

## Hmotnostní limit je spouštěcí práh: pod ním se plošina nehne, na něm
## a nad ním ano (design dok. §2.2.1).
func test_platform_needs_the_trigger_weight() -> void:
	var sim := _platform_level(3, true)
	var input := action_1(sim)
	t.is_false(input.accepted, "pod prahem se plošina nehne")
	t.equal(sim.world.block_at(Vector3i(3, 1, 0)), GridTypes.BlockType.WALL,
			"plošina zůstala dole")

	var loaded := _platform_level(2, true)
	t.is_true(action_1(loaded).accepted, "s dost těžkým nákladem se rozjede")

## Zařízení v kostce plošiny je její pevnou součástí a přesune se s ní
## (design dok. §2.2.1) — jinak by zůstalo viset na staré souřadnici.
func test_platform_carries_its_own_device() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "#####") \
		.layer(1, ".L###") \
		.layer(2, ".....") \
		.layer(3, ".....") \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(4, 1, 0),
				GridTypes.Direction.WEST) \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST, GridTypes.ControlMode.BUTTON) \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(3, 1, 0),
				GridTypes.Direction.NORTH) \
		.platform([Vector3i(3, 1, 0)], Vector3i.ZERO, Vector3i(0, 1, 0), 0, [0], [1]) \
		.simulate()

	t.is_true(action_1(sim).accepted, "plošina přejela")
	t.equal(sim.world.devices[2].cell, Vector3i(3, 2, 0),
			"skříň na plošině jela s ní")
	t.equal(sim.world.device_at(Vector3i(3, 2, 0)), 2,
			"a v nové poloze se dá najít")
	t.equal(sim.world.devices[0].cell, Vector3i(4, 1, 0),
			"skříň mimo plošinu zůstala na místě")

## Klíč i odložené předměty na plošině jedou s ní (design dok. §2.2.1) —
## jinak by po přejezdu zůstaly viset ve vzduchu nad starou polohou.
func test_platform_carries_the_key_and_the_items_on_it() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "######") \
		.layer(1, ".L####") \
		.layer(2, "...+f.") \
		.layer(3, "......") \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(2, 1, 0),
				GridTypes.Direction.WEST, GridTypes.ControlMode.BUTTON) \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(5, 1, 0),
				GridTypes.Direction.WEST) \
		.platform([Vector3i(3, 1, 0), Vector3i(4, 1, 0)], Vector3i.ZERO,
				Vector3i(0, 1, 0), 0, [1], [0]) \
		.simulate()

	t.is_true(action_1(sim).accepted, "plošina přejela")
	t.equal(sim.world.key_position, Vector3i(3, 3, 0), "klíč vyjel s plošinou")
	t.equal(sim.world.item_at(Vector3i(4, 3, 0)), GridTypes.ItemType.FUEL,
			"kanystr vyjel s plošinou")
	t.is_false(sim.world.has_item_at(Vector3i(4, 2, 0)),
			"a ve staré poloze už neleží")

func test_empty_platform_with_a_threshold_stays_put() -> void:
	var sim := _platform_level(2, false)
	t.is_false(action_1(sim).accepted, "prázdná plošina práh nesplní")

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

## Oprava skříň nejen zprovozní, ale rovnou ji uvede pod napětí — stejně jako
## skříň bez poruchy po startu levelu. Jinak by napojené automatické čerpadlo
## po opravě zůstalo stát (design dok. §1.1.7, §2.2.1).
func test_repairing_a_cabinet_powers_it_and_starts_the_automatic_pump() -> void:
	var sim := LevelBuilder.new() \
		.layer(0, "##########\n##########\n##########") \
		.layer(1, "##########\n#...#....#\n##########") \
		.layer(2, "##########\n#...##...#\n#####L####") \
		.reservoir(Vector3i(1, 1, 1), 4) \
		.reservoir(Vector3i(5, 1, 1), 0) \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(6, 2, 2),
				GridTypes.Direction.WEST, GridTypes.ControlMode.BUTTON, true) \
		.pump(0, 1, [0]) \
		.simulate()
	t.is_false(sim.world.devices[0].is_on, "rozbitá skříň není pod napětím")
	t.equal(sim.world.reservoirs[0].volume_units, 4, "ve zdroji jsou dvě kostky")

	sim.world.robots[0].inventory.append(GridTypes.ItemType.SERVICE_KIT)
	var repaired := action_1(sim)
	t.is_true(repaired.accepted, "Il skříň opraví")
	t.is_true(sim.world.devices[0].is_on, "opravená skříň je rovnou pod napětím")
	t.equal(sim.world.reservoirs[0].volume_units, 0,
			"automatika hned přečerpá celý obsah zdroje")
	t.equal(sim.world.reservoirs[1].volume_units, 4, "a doteče do cíle")

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
		.pump(0, 1, [0]) \
		.build()
	var world := WorldState.from_level(level)
	DeviceSystem.initialize(world)
	return world

## Jedno sepnutí přečerpá CELÝ obsah zdroje, ne pevnou kostku (design dok.
## §2.2.1).
func test_pump_transfers_the_whole_source() -> void:
	var world := _pump_world(4, 0)
	t.equal(world.reservoirs.size(), 2, "dvě nádrže")
	t.equal(world.reservoirs[0].cells.size(), 6, "nádrž A má šest buněk")
	t.equal(world.reservoirs[1].cells.size(), 6, "nádrž B taky")
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_true(validation.ok, "přenos je možný: " + validation.reason)
	t.equal(int(validation.data["units"]), 4, "dávka je celý obsah zdroje")
	var events: Array = []
	DeviceSystem.transfer(world, 0, validation, events)
	t.equal(world.reservoirs[0].volume_units, 0, "zdroj se vyprázdnil beze zbytku")
	t.equal(world.reservoirs[1].volume_units, 4, "a celý obsah přitekl do cíle")

## Zbytek pod celou kostkou se přečerpá taky — pravidlo mluví o 100 % obsahu,
## ne o celých kostkách.
func test_pump_transfers_a_partial_cube_too() -> void:
	var world := _pump_world(1, 0)
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_true(validation.ok, "půl kostky je pořád obsah zdroje: " + validation.reason)
	var events: Array = []
	DeviceSystem.transfer(world, 0, validation, events)
	t.equal(world.reservoirs[0].volume_units, 0, "zdroj je prázdný")
	t.equal(world.reservoirs[1].volume_units, 1, "a půlkostka je v cíli")

func test_pump_stops_completely_when_someone_would_drown() -> void:
	var world := _pump_world(4, 2, true)
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_false(validation.ok, "přenos, který by někoho utopil, se neprovede vůbec")
	t.equal(world.reservoirs[0].volume_units, 4, "zdroj se nezměnil")
	t.equal(world.reservoirs[1].volume_units, 2, "cíl taky ne")

func test_pump_needs_water_in_the_source() -> void:
	var world := _pump_world(0, 0)
	t.is_false(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"z prázdné nádrže se nečerpá")

## Nestačí-li volná kapacita cíle na celý obsah zdroje, nepřečerpá se nic —
## ani ta část, která by se vešla (design dok. §2.2.1).
func test_pump_needs_room_for_the_whole_source() -> void:
	# Cíl má kapacitu 12 jednotek a 10 už je zabraných → volné jsou 2,
	# zdroj má 4.
	var world := _pump_world(4, 10)
	t.equal(world.reservoirs[1].total_capacity(), 12, "kapacita cíle")
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_false(validation.ok, "částečný přenos neexistuje")
	t.equal(world.reservoirs[0].volume_units, 4, "zdroj se nezměnil")
	t.equal(world.reservoirs[1].volume_units, 10, "cíl taky ne")

## Přesně padnoucí kapacita stačí — podmínka je „stejná nebo větší".
func test_pump_accepts_an_exactly_fitting_target() -> void:
	var world := _pump_world(4, 8)
	var validation := DeviceSystem.pump_can_transfer(world, 0, 0)
	t.is_true(validation.ok, "volné 4 jednotky na 4 jednotky zdroje stačí: "
			+ validation.reason)
	var events: Array = []
	DeviceSystem.transfer(world, 0, validation, events)
	t.equal(world.reservoirs[1].volume_units, 12, "cíl je po přenosu plný")

func test_pump_must_not_drain_an_unlimited_reservoir() -> void:
	var world := _pump_world(4, 0)
	world.reservoirs[0].unlimited = true
	t.is_false(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"z neomezené nádrže čerpadlo čerpat nesmí (§13.3)")

## Čerpadlo je pod napětím, jen když jsou VŠECHNY napojené skříně opravené
## a zapnuté (design dok. §2.2.1).
func test_pump_needs_all_of_its_cabinets() -> void:
	var world := _pump_world(4, 0)
	var second := DeviceState.new()
	second.kind = GridTypes.DeviceKind.POWER_CABINET
	second.cell = Vector3i(4, 2, 1)
	second.is_broken = true
	world.devices.append(second)
	world.pumps[0].linked_cabinets = [0, 1]
	t.is_false(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"rozbitá druhá skříň čerpadlo zastaví")
	second.is_broken = false
	second.is_on = true
	t.is_true(DeviceSystem.pump_can_transfer(world, 0, 0).ok,
			"po opravě čerpadlo zase jede")

## Automatické čerpadlo (bez řídicí jednotky) přečerpá celý obsah zdroje
## v momentě, kdy jsou poprvé splněné podmínky přenosu, a pak čeká na další
## náběžnou hranu (design dok. §2.2.1). Protože po přenosu zůstane zdroj
## prázdný, podmínka sama přestane platit a čerpadlo čeká, až se zdroj naplní.
func test_automatic_pump_fires_once_on_the_rising_edge() -> void:
	var world := _pump_world(4, 0)
	var events: Array = []
	DeviceSystem.run_automatics(world, events)
	t.equal(world.reservoirs[0].volume_units, 0, "první sepnutí vyprázdnilo zdroj")
	t.equal(world.reservoirs[1].volume_units, 4, "a celý obsah je v cíli")

	events.clear()
	DeviceSystem.run_automatics(world, events)
	t.equal(world.reservoirs[1].volume_units, 4, "podruhé už nemá co čerpat")
	t.is_true(events.is_empty(), "a nevydá žádnou událost")

	# Nová voda ve zdroji je nová náběžná hrana.
	world.reservoirs[0].volume_units = 2
	DeviceSystem.run_automatics(world, events)
	t.equal(world.reservoirs[0].volume_units, 0, "doplněný zdroj čerpadlo sepne znovu")
	t.equal(world.reservoirs[1].volume_units, 6, "a doteče do cíle")

## ── Přepínač nad čerpadlem (§13.1) ────────────────────────────────────────
##
## Il stojí u řídicí jednotky (zařízení 1) ve zdi mezi dvěma nádržemi;
## zařízení 0 je napájecí skříň. Čerpadlo 0 je obousměrné a napojené právě
## na tu řídicí jednotku.
func _switch_pump_level(volume_a: int, volume_b: int,
		control_mode: int = GridTypes.ControlMode.SWITCH,
		bidirectional: bool = true) -> Simulation:
	return LevelBuilder.new() \
		.layer(0, "##########\n##########\n##########") \
		.layer(1, "##########\n#...##...#\n##########") \
		.layer(2, "##########\n#...##...#\n####L#####") \
		.reservoir(Vector3i(1, 1, 1), volume_a) \
		.reservoir(Vector3i(6, 1, 1), volume_b) \
		.device(GridTypes.DeviceKind.POWER_CABINET, Vector3i(5, 2, 1),
				GridTypes.Direction.SOUTH) \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(4, 2, 1),
				GridTypes.Direction.SOUTH, control_mode) \
		.pump(0, 1, [0], 1, bidirectional) \
		.facing(GridTypes.RobotKind.IL, GridTypes.Direction.NORTH) \
		.simulate()

## Přepnutí přepínače přečerpá celý obsah zdroje a zároveň prohodí zdrojovou
## a cílovou nádrž — další sepnutí čerpá zpátky (design dok. §2.2.1, §13.1).
func test_switch_pumps_and_swaps_source_and_target() -> void:
	var sim := _switch_pump_level(6, 0)
	var first := action_1(sim)
	t.is_true(first.accepted, "první sepnutí projde: " + first.reason)
	t.equal(sim.world.reservoirs[0].volume_units, 0, "zdroj se vyprázdnil")
	t.equal(sim.world.reservoirs[1].volume_units, 6, "celý obsah je v cíli")
	t.equal(sim.world.pumps[0].current_direction, 1, "a nádrže se prohodily")
	t.is_true(first.has_event(Event.EventType.PUMP_TRANSFERRED), "událost přenosu")

	var second := action_1(sim)
	t.is_true(second.accepted, "druhé sepnutí projde: " + second.reason)
	t.equal(sim.world.reservoirs[0].volume_units, 6, "voda se vrátila zpátky")
	t.equal(sim.world.reservoirs[1].volume_units, 0, "a v druhé nádrži nezůstala")
	t.equal(sim.world.pumps[0].current_direction, 0, "směr je zase výchozí")

## Tlačítko čerpá pořád stejným, předem daným směrem — i když je čerpadlo
## obousměrné (design dok. §2.2.1).
func test_button_always_pumps_in_the_default_direction() -> void:
	var sim := _switch_pump_level(6, 0, GridTypes.ControlMode.BUTTON)
	t.is_true(action_1(sim).accepted, "první sepnutí")
	t.equal(sim.world.pumps[0].current_direction, 0, "tlačítko směr nemění")
	t.is_false(action_1(sim).accepted,
			"druhé sepnutí nemá co čerpat — zdroj je prázdný")
	t.equal(sim.world.reservoirs[1].volume_units, 6, "voda zůstala v cíli")

## Nedá-li se přenos provést, přepínač směr NEprohodí a příkaz se odmítne —
## odmítnutý příkaz nesmí měnit stav (P5).
func test_switch_does_not_swap_when_the_transfer_is_impossible() -> void:
	var sim := _switch_pump_level(0, 6)
	var rejected := action_1(sim)
	t.is_false(rejected.accepted, "z prázdného zdroje se nečerpá")
	t.equal(sim.world.pumps[0].current_direction, 0, "směr zůstal beze změny")
	t.equal(sim.world.reservoirs[1].volume_units, 6, "a voda se nehnula")

## Jednosměrné čerpadlo se přepínačem obrátit nedá — čerpá pořád A → B.
func test_switch_over_a_one_way_pump_keeps_the_direction() -> void:
	var sim := _switch_pump_level(6, 0, GridTypes.ControlMode.SWITCH, false)
	t.is_true(action_1(sim).accepted, "přenos projde")
	t.equal(sim.world.pumps[0].current_direction, 0,
			"jednosměrné čerpadlo si směr drží")

func test_automatic_pump_waits_until_the_target_has_room() -> void:
	# Cíl je plný (kapacita 12 jednotek, viz test výše — 6 buněk po 2).
	var world := _pump_world(4, 12)
	var events: Array = []
	DeviceSystem.run_automatics(world, events)
	t.equal(world.reservoirs[0].volume_units, 4, "do plné nádrže se nečerpá")
	t.is_true(events.is_empty(), "a nic se nestane")
