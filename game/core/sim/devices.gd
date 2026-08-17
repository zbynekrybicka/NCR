class_name DeviceSystem
extends RefCounted

## Elektrická zařízení, transportní plošiny a čerpadla (§13).
##
## Zařízení sepíná Il svojí akcí 1 — jeden stisk = jedno sepnutí, žádný režim
## ovládání neexistuje (design dokument §1.1.7).

## Skříň bez poruchy je po startu pod napětím.
static func initialize(world: WorldState) -> void:
	for device in world.devices:
		if device.kind == GridTypes.DeviceKind.POWER_CABINET:
			device.is_on = not device.is_broken

# ── Napájení ───────────────────────────────────────────────────────────────

static func cabinets_powered(world: WorldState, cabinet_indices: Array) -> bool:
	if cabinet_indices.is_empty():
		return false
	for index in cabinet_indices:
		if index < 0 or index >= world.devices.size():
			return false
		var cabinet: DeviceState = world.devices[index]
		if cabinet.is_broken or not cabinet.is_on:
			return false
	return true

# ── Plošiny (§13.2) ────────────────────────────────────────────────────────

## Hmotnost na plošině = součet hmotností robotů stojících na jejích buňkách.
## Nesené předměty se nepočítají (§10).
static func platform_load(world: WorldState, platform_index: int) -> int:
	var platform: PlatformState = world.platforms[platform_index]
	var cells := platform.occupied_cells()
	var total := 0
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		if robot.in_target:
			continue
		if cells.has(robot.cell + GridTypes.DOWN_VECTOR):
			total += robot.mass()
	return total

static func platform_riders(world: WorldState, platform_index: int) -> Array:
	var platform: PlatformState = world.platforms[platform_index]
	var cells := platform.occupied_cells()
	var riders: Array = []
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		if robot.in_target:
			continue
		if cells.has(robot.cell + GridTypes.DOWN_VECTOR):
			riders.append(i)
	return riders

## Hmotnostní limit je **spouštěcí práh**, ne horní mez nosnosti (design dok.
## §2.2.1): plošina se rozjede, teprve když je na ní aspoň `weight_limit`
## hmotnosti. Těžší náklad ji nezastaví. Práh platí pro automatickou
## i manuální plošinu stejně.
static func platform_can_move(world: WorldState, platform_index: int) -> Validation:
	var platform: PlatformState = world.platforms[platform_index]
	if not cabinets_powered(world, platform.linked_cabinets):
		return Validation.reject("plošina není pod napětím")
	var total_load := platform_load(world, platform_index)
	if total_load < platform.weight_limit:
		return Validation.reject("na plošině není dost hmotnosti pro spuštění")

	var target_pose := 1 - platform.current_pose
	var delta := platform.offset_of_pose(target_pose) - platform.current_offset()
	var riders := platform_riders(world, platform_index)

	# Dráha plošiny je z principu vždy prázdná (kontroluje editor, V8) — ale
	# cíl přejezdu se pro jistotu ověří i tady.
	var platform_target_cells := platform.cells_at_pose(target_pose)
	var own_cells := platform.occupied_cells()
	for cell in platform_target_cells:
		if not world.is_inside(cell):
			return Validation.reject("plošina by vyjela z levelu")
		if own_cells.has(cell):
			continue
		if world.is_solid_at(cell):
			return Validation.reject("v dráze plošiny je překážka")

	# Utonutí: hrozí-li přejezdem utonutí robota jiného než Dula, plošina se
	# zablokuje bez ohledu na ostatní podmínky (design dokument §2.2.1).
	for rider_index in riders:
		var robot: RobotState = world.robots[rider_index]
		var target_cell: Vector3i = robot.cell + delta
		if not world.is_inside(target_cell):
			return Validation.reject("robot by vyjel z levelu")
		if robot.kind == GridTypes.RobotKind.DUL:
			continue
		var reservoir_index := world.reservoir_at(target_cell)
		if reservoir_index == -1:
			continue
		var res: ReservoirState = world.reservoirs[reservoir_index]
		if WaterSystem.would_drown(res, target_cell.y):
			return Validation.reject("robot by se na cílové poloze utopil")

	return Validation.accept({"target_pose": target_pose, "delta": delta, "riders": riders})

static func move_platform(world: WorldState, platform_index: int, validation: Validation,
		out_events: Array) -> void:
	var platform: PlatformState = world.platforms[platform_index]
	var delta: Vector3i = validation.data["delta"]
	var riders: Array = validation.data["riders"]
	var from_offset := platform.current_offset()

	# 0) buňky nad plošinou — co v nich leží, jede s plošinou (§2.2.1)
	var top_cells := {}
	for cell in platform.occupied_cells():
		top_cells[cell + GridTypes.UP_VECTOR] = true

	# 1) sejmout bloky ze starých pozic (i s jejich orientací)
	var carried: Array = []
	for cell in platform.occupied_cells():
		carried.append([cell, world.block_at(cell), world.orientation_at(cell)])
	for entry in carried:
		world.set_block(entry[0], GridTypes.BlockType.EMPTY)

	# 2) roboti stojící na plošině jedou s ní — dřív, než se položí bloky,
	#    aby jezdec ani na okamžik neskončil uvnitř pevného bloku (I3)
	for rider_index in riders:
		var robot: RobotState = world.robots[rider_index]
		var from := robot.cell
		robot.cell = from + delta
		out_events.append(Event.robot_moved(rider_index, from, robot.cell,
				GridTypes.Substep.FORWARD))

	# 2b) klíč a odložené předměty ležící na plošině jedou s ní stejně jako
	#     roboti (design dok. §2.2.1) — jinak by zůstaly nad starou polohou
	if world.key_holder == -1 and top_cells.has(world.key_position):
		world.key_position += delta

	var moved_items: Array = []
	for cell in world.items_on_ground.keys():
		if top_cells.has(cell):
			moved_items.append([cell, world.item_at(cell)])
	for entry in moved_items:
		world.take_item_at(entry[0])
	for entry in moved_items:
		world.put_item_at(entry[0] + delta, entry[1])

	# 3) položit bloky na nové pozice
	for entry in carried:
		var target: Vector3i = entry[0] + delta
		world.set_block(target, entry[1])
		world.set_orientation(target, entry[2])

	# 4) zařízení v kostkách plošiny jsou její pevnou součástí a jedou s ní
	#    (design dok. §2.2.1); jinak se ani přesunout, ani zničit nedají.
	var carried_cells := {}
	for entry in carried:
		carried_cells[entry[0]] = true
	for device in world.devices:
		if carried_cells.has(device.cell):
			device.cell += delta

	platform.current_pose = validation.data["target_pose"]
	out_events.append(Event.platform_moved(platform_index, from_offset,
			platform.current_offset()))

# ── Čerpadla (§13.3) ───────────────────────────────────────────────────────

static func pump_can_transfer(world: WorldState, pump_index: int, direction: int) -> Validation:
	var pump: PumpState = world.pumps[pump_index]
	if not cabinets_powered(world, pump.linked_cabinets):
		return Validation.reject("čerpadlo není pod napětím")
	var source := pump.source_reservoir(direction)
	var target := pump.target_reservoir(direction)
	if source < 0 or source >= world.reservoirs.size():
		return Validation.reject("zdrojová nádrž neexistuje")
	if target < 0 or target >= world.reservoirs.size():
		return Validation.reject("cílová nádrž neexistuje")
	var source_res: ReservoirState = world.reservoirs[source]
	if source_res.unlimited:
		# Z neomezené nádrže čerpadlo čerpat nesmí (§13.3, editor V10) — neměla
		# by definovaný „celý obsah", který by šlo přečerpat.
		return Validation.reject("čerpadlo nesmí čerpat z neomezené nádrže")

	# Jedno sepnutí přečerpá CELÝ obsah zdroje, ne pevnou kostku (design dok.
	# §2.2.1). Buď se přečerpá všechno, nebo nic — částečný přenos neexistuje.
	var units := source_res.volume_units
	if units <= 0:
		return Validation.reject("zdrojová nádrž je prázdná")
	var target_res: ReservoirState = world.reservoirs[target]
	if not target_res.unlimited \
			and target_res.total_capacity() - target_res.volume_units < units:
		return Validation.reject("v cílové nádrži není dost volné kapacity")
	# Přenos, který by někoho utopil, se neprovede vůbec — ani zčásti (§9.4).
	if not WaterSystem.raising_water_is_safe(world, target, units):
		return Validation.reject("přenos by zvedl hladinu nad bezpečnou mez")
	return Validation.accept({"source": source, "target": target, "units": units})

static func transfer(world: WorldState, pump_index: int, validation: Validation,
		out_events: Array) -> void:
	var source: int = validation.data["source"]
	var target: int = validation.data["target"]
	var units: int = validation.data["units"]
	WaterSystem.change_volume(world, source, -units, out_events)
	WaterSystem.change_volume(world, target, units, out_events)
	out_events.append(Event.pump_transferred(pump_index, source, target, units))

# ── Sepnutí zařízení (§13.1) ───────────────────────────────────────────────

## Udělá stisk tlačítka / přehození přepínače vůbec něco? Čistá kontrola pro
## validaci Ilovy akce 1 — prochází plošiny a čerpadla ve stejném pořadí jako
## `device_input`, takže první položka, která projde tady, projde i tam.
static func device_input_validate(world: WorldState, device_index: int) -> Validation:
	var device: DeviceState = world.devices[device_index]
	if device.is_broken:
		return Validation.reject("zařízení je rozbité")

	# Skříň: sepnutí přepíná napájení, to jde vždycky.
	if device.kind == GridTypes.DeviceKind.POWER_CABINET:
		return Validation.accept({})

	var last_reason := "řídicí jednotka není na nic napojená"
	for platform_index in world.platforms.size():
		var platform: PlatformState = world.platforms[platform_index]
		if not platform.linked_control_units.has(device_index):
			continue
		var validation := platform_can_move(world, platform_index)
		if validation.ok:
			return Validation.accept({})
		last_reason = validation.reason

	for pump_index in world.pumps.size():
		var pump: PumpState = world.pumps[pump_index]
		if pump.linked_control_unit != device_index:
			continue
		var validation := pump_can_transfer(world, pump_index, pump.current_direction)
		if validation.ok:
			return Validation.accept({})
		last_reason = validation.reason

	return Validation.reject(last_reason)

## Provedení sepnutí. Každý dílčí přejezd/přenos se validuje znovu těsně před
## provedením — dřívější přejezd mohl podmínky dalšího zařízení změnit.
static func device_input(world: WorldState, device_index: int, out_events: Array) -> void:
	var device: DeviceState = world.devices[device_index]

	if device.kind == GridTypes.DeviceKind.POWER_CABINET:
		device.is_on = not device.is_on
		out_events.append(Event.device_toggled(device_index, device.is_on))
		return

	for platform_index in world.platforms.size():
		var platform: PlatformState = world.platforms[platform_index]
		if not platform.linked_control_units.has(device_index):
			continue
		var validation := platform_can_move(world, platform_index)
		if not validation.ok:
			continue
		move_platform(world, platform_index, validation, out_events)

	for pump_index in world.pumps.size():
		var pump: PumpState = world.pumps[pump_index]
		if pump.linked_control_unit != device_index:
			continue
		var validation := pump_can_transfer(world, pump_index, pump.current_direction)
		if not validation.ok:
			continue
		transfer(world, pump_index, validation, out_events)
		# Přepínač přečerpává střídavě jedním i druhým směrem (§13.1).
		if device.control_mode == GridTypes.ControlMode.SWITCH and pump.bidirectional:
			pump.current_direction = 1 - pump.current_direction
		else:
			pump.current_direction = pump.default_direction

# ── Automatika (§13.2, §13.3) ──────────────────────────────────────────────

## Automatické plošiny a čerpadla se spouští na náběžné hraně splnění
## podmínky — jinak by kmitaly každý příkaz.
static func run_automatics(world: WorldState, out_events: Array) -> void:
	for platform_index in world.platforms.size():
		var platform: PlatformState = world.platforms[platform_index]
		if platform.is_manual():
			continue
		# Práh 0 by automatickou plošinu rozjel hned na startu levelu — editor
		# proto u automatické plošiny vyžaduje práh ≥ 1 (V16).
		var ready := platform.weight_limit > 0 \
				and platform_load(world, platform_index) >= platform.weight_limit
		if not ready:
			platform.trigger_latched = false
			continue
		if platform.trigger_latched:
			continue
		var validation := platform_can_move(world, platform_index)
		if not validation.ok:
			continue
		move_platform(world, platform_index, validation, out_events)
		platform.trigger_latched = true

	# Automatické čerpadlo přečerpá celý obsah zdroje v momentě, kdy jsou
	# poprvé splněné všechny podmínky přenosu (design dok. §2.2.1): všechny
	# napojené skříně jsou opravené a pod napětím, ve zdroji je nějaká voda,
	# v cíli aspoň tolik volné kapacity, kolik je ve zdroji vody, a nikdo se
	# přenosem neutopí. Přesně tyhle podmínky ověřuje pump_can_transfer —
	# automatika tedy jen sleduje náběžnou hranu jejího výsledku.
	for pump_index in world.pumps.size():
		var pump: PumpState = world.pumps[pump_index]
		if pump.is_manual():
			continue
		var validation := pump_can_transfer(world, pump_index, pump.current_direction)
		if not validation.ok:
			pump.trigger_latched = false
			continue
		if pump.trigger_latched:
			continue
		transfer(world, pump_index, validation, out_events)
		pump.trigger_latched = true
