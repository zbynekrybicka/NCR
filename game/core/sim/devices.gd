class_name DeviceSystem
extends RefCounted

## Elektrická zařízení, transportní plošiny a čerpadla (§13).
##
## Během ovládání zařízení míří DEVICE_INPUT na zařízení, ne na robota.
## Převzetí kontroly = přímé ovládání jeho vstupů, jako by je ovládala sama
## řídicí jednotka.

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

static func platform_can_move(world: WorldState, platform_index: int) -> Validation:
	var platform: PlatformState = world.platforms[platform_index]
	if not cabinets_powered(world, platform.linked_cabinets):
		return Validation.reject("plošina není pod napětím")
	var total_load := platform_load(world, platform_index)
	if total_load > platform.weight_limit:
		return Validation.reject("překročená nosnost plošiny")

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

	# 3) položit bloky na nové pozice
	for entry in carried:
		var target: Vector3i = entry[0] + delta
		world.set_block(target, entry[1])
		world.set_orientation(target, entry[2])

	platform.current_pose = validation.data["target_pose"]
	out_events.append(Event.platform_moved(platform_index, from_offset,
			platform.current_offset()))

# ── Čerpadla (§13.3) ───────────────────────────────────────────────────────

static func pump_can_transfer(world: WorldState, pump_index: int, direction: int) -> Validation:
	var pump: PumpState = world.pumps[pump_index]
	if not cabinets_powered(world, [pump.linked_cabinet]):
		return Validation.reject("čerpadlo není pod napětím")
	var source := pump.source_reservoir(direction)
	var target := pump.target_reservoir(direction)
	if source < 0 or source >= world.reservoirs.size():
		return Validation.reject("zdrojová nádrž neexistuje")
	if target < 0 or target >= world.reservoirs.size():
		return Validation.reject("cílová nádrž neexistuje")
	var source_res: ReservoirState = world.reservoirs[source]
	if source_res.unlimited:
		# Z neomezené nádrže čerpadlo čerpat nesmí (§13.3, editor V10).
		return Validation.reject("čerpadlo nesmí čerpat z neomezené nádrže")
	if not WaterSystem.lowering_water_is_possible(world, source, PumpState.TRANSFER_UNITS):
		return Validation.reject("ve zdrojové nádrži není dost vody")
	# Přenos, který by někoho utopil, se neprovede vůbec — ani zčásti (§9.4).
	if not WaterSystem.raising_water_is_safe(world, target, PumpState.TRANSFER_UNITS):
		return Validation.reject("přenos by zvedl hladinu nad bezpečnou mez")
	return Validation.accept({"source": source, "target": target,
			"units": PumpState.TRANSFER_UNITS})

static func transfer(world: WorldState, pump_index: int, validation: Validation,
		out_events: Array) -> void:
	var source: int = validation.data["source"]
	var target: int = validation.data["target"]
	var units: int = validation.data["units"]
	WaterSystem.change_volume(world, source, -units, out_events)
	WaterSystem.change_volume(world, target, units, out_events)
	out_events.append(Event.pump_transferred(pump_index, source, target, units))

# ── Vstup do ovládaného zařízení (§13.1) ───────────────────────────────────

static func device_input(world: WorldState, robot_index: int, out_events: Array) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.controlling_device == -1:
		return Validation.reject("robot neovládá žádné zařízení")
	var device_index := robot.controlling_device
	var device: DeviceState = world.devices[device_index]
	if device.is_broken:
		return Validation.reject("zařízení je rozbité")

	# Skříň: přímé ovládání znamená přepnutí napájení.
	if device.kind == GridTypes.DeviceKind.POWER_CABINET:
		device.is_on = not device.is_on
		return Validation.accept({})

	var acted := false
	var last_reason := "řídicí jednotka není na nic napojená"

	for platform_index in world.platforms.size():
		var platform: PlatformState = world.platforms[platform_index]
		if not platform.linked_control_units.has(device_index):
			continue
		var validation := platform_can_move(world, platform_index)
		if not validation.ok:
			last_reason = validation.reason
			continue
		move_platform(world, platform_index, validation, out_events)
		acted = true

	for pump_index in world.pumps.size():
		var pump: PumpState = world.pumps[pump_index]
		if pump.linked_control_unit != device_index:
			continue
		var direction := pump.current_direction
		var validation := pump_can_transfer(world, pump_index, direction)
		if not validation.ok:
			last_reason = validation.reason
			continue
		transfer(world, pump_index, validation, out_events)
		acted = true
		# Přepínač přečerpává střídavě jedním i druhým směrem (§13.1).
		if device.control_mode == GridTypes.ControlMode.SWITCH and pump.bidirectional:
			pump.current_direction = 1 - pump.current_direction
		else:
			pump.current_direction = pump.default_direction

	if not acted:
		return Validation.reject(last_reason)
	return Validation.accept({})

# ── Automatika (§13.2, §13.3) ──────────────────────────────────────────────

## Automatické plošiny a čerpadla se spouští na náběžné hraně splnění
## podmínky — jinak by kmitaly každý příkaz.
static func run_automatics(world: WorldState, out_events: Array) -> void:
	for platform_index in world.platforms.size():
		var platform: PlatformState = world.platforms[platform_index]
		if platform.is_manual():
			continue
		var ready := platform_load(world, platform_index) >= platform.weight_limit \
				and platform.weight_limit > 0
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

	for pump_index in world.pumps.size():
		var pump: PumpState = world.pumps[pump_index]
		if pump.is_manual():
			continue
		if not cabinets_powered(world, [pump.linked_cabinet]):
			pump.trigger_latched = false
			continue
		if pump.trigger_latched:
			continue
		var validation := pump_can_transfer(world, pump_index, pump.current_direction)
		if not validation.ok:
			continue
		transfer(world, pump_index, validation, out_events)
		pump.trigger_latched = true
