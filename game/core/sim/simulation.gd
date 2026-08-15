class_name Simulation
extends RefCounted

## Vstupní bod simulace (§6). Příkaz se vyhodnotí a aplikuje celý v jednom
## okamžiku (nula herních snímků); výsledkem je seznam událostí, které si
## prezentační vrstva přehraje v čase jako animaci (P3).
##
## Průběh příkazu (§6.2):
##   1. VALIDACE     — čistá funkce, nesmí mutovat
##   2. APLIKACE     — mutace WorldState, sběr událostí
##   3. DOSAZENÍ     — gravitace, voda, automatika až do ustálení
##   4. INVARIANTY   — v debug buildu I1–I8
##   5. POSTPODMÍNKY — kontrola dokončení levelu

var level: LevelData
var world: WorldState

var _action_1: Dictionary = {}
var _action_2: Dictionary = {}

func _init(p_level: LevelData) -> void:
	level = p_level
	_build_action_table()
	reset()

func reset() -> void:
	world = WorldState.from_level(level)
	DeviceSystem.initialize(world)

func _build_action_table() -> void:
	_action_1 = {
		GridTypes.RobotKind.HAN: HanDig.new(),
		GridTypes.RobotKind.DUL: DulPump.new(),
		GridTypes.RobotKind.SET: SetBurn.new(),
		GridTypes.RobotKind.YEO: YeoFreeze.new(),
		GridTypes.RobotKind.IL: IlInteract.new(),
		# Net a Da akci 1 neprovádí (design dokument §1.1.4, §1.1.5).
	}
	_action_2 = {
		GridTypes.RobotKind.HAN: HanDump.new(),
		GridTypes.RobotKind.DUL: DulRelease.new(),
		GridTypes.RobotKind.SET: DropItem.new(GridTypes.ItemType.FUEL),
		GridTypes.RobotKind.NET: DropItem.new(),
		GridTypes.RobotKind.DA: DaDrop.new(),
		GridTypes.RobotKind.YEO: DropItem.new(GridTypes.ItemType.FUEL),
		GridTypes.RobotKind.IL: IlReleaseOrDrop.new(),
	}

# ── Vstupní bod ────────────────────────────────────────────────────────────

func submit_command(command: Command) -> Command.Result:
	var result := Command.Result.new(true, "")
	var robot_index := world.active_robot_index

	if command.type == Command.CommandType.RESTART_LEVEL:
		reset()
		result.events.append(Event.level_restarted())
		return result

	if robot_index < 0 or robot_index >= world.robots.size():
		return _reject(command, "žádný aktivní robot")

	var validation := _validate(command, robot_index)
	if not validation.ok:
		return _reject(command, validation.reason)

	# Vstup do ovládaného zařízení se dá vyhodnotit až v aplikační fázi (závisí
	# na stavu plošin a čerpadel). Když se nic nestalo, je to odmítnutý příkaz
	# jako každý jiný — nic se nezměnilo, takže se nesmí hlásit jako přijatý (P5).
	var apply_error := _apply(command, robot_index, validation, result.events)
	if apply_error != "":
		return _reject(command, apply_error)
	_settle(result.events)
	_check_invariants()
	_check_postconditions(result.events)
	return result

func _reject(command: Command, reason: String) -> Command.Result:
	var result := Command.Result.new(false, reason)
	result.events.append(Event.command_rejected(command.type, reason))
	return result

# ── 1. Validace ────────────────────────────────────────────────────────────

func _validate(command: Command, robot_index: int) -> Validation:
	match command.type:
		Command.CommandType.TURN_LEFT, Command.CommandType.TURN_RIGHT, \
		Command.CommandType.TURN_AROUND:
			return Validation.accept({}) # otáčet se mohou všichni neomezeně
		Command.CommandType.STEP:
			var queue := StepEvaluator.evaluate(world, robot_index)
			if queue.is_empty():
				return Validation.reject("krok není možný")
			return Validation.accept({"queue": queue})
		Command.CommandType.STEP_UP:
			return _validate_vertical(robot_index, GridTypes.UP_VECTOR)
		Command.CommandType.STEP_DOWN:
			return _validate_vertical(robot_index, GridTypes.DOWN_VECTOR)
		Command.CommandType.ACTION_1:
			return _validate_action(_action_1, robot_index, "akci 1")
		Command.CommandType.ACTION_2:
			return _validate_action(_action_2, robot_index, "akci 2")
		Command.CommandType.SWITCH_ROBOT_NEXT:
			return _validate_switch(next_robot_in_sequence(), robot_index)
		Command.CommandType.SWITCH_ROBOT_TO:
			return _validate_switch(command.target_index, robot_index)
		Command.CommandType.DEVICE_INPUT:
			var robot: RobotState = world.robots[robot_index]
			if robot.controlling_device == -1:
				return Validation.reject("robot neovládá žádné zařízení")
			return Validation.accept({})
	return Validation.reject("neznámý příkaz")

func _validate_action(table: Dictionary, robot_index: int, label: String) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if not table.has(robot.kind):
		return Validation.reject("%s tenhle robot neprovádí" % label)
	var action: Action = table[robot.kind]
	return action.validate(world, robot_index)

## §7.7 — přímé vertikální kroky mimo behavior tree: Da (kdykoli) a Dul
## (jen ve vodě). Pro ostatní roboty je příkaz vždy odmítnutý.
func _validate_vertical(robot_index: int, delta: Vector3i) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	var is_da := robot.kind == GridTypes.RobotKind.DA
	var is_dul := robot.kind == GridTypes.RobotKind.DUL
	if not is_da and not is_dul:
		return Validation.reject("tenhle robot se svisle nepohybuje")
	if is_dul and world.water_depth_at(robot.cell) == GridTypes.WaterDepth.DRY:
		return Validation.reject("Dul se svisle pohybuje jen ve vodě")

	var target := robot.cell + delta
	if not world.is_inside(target):
		return Validation.reject("cíl je mimo level")
	if world.is_solid_at(target):
		return Validation.reject("v cíli je pevný blok")
	if world.robot_at(target) != -1:
		return Validation.reject("v cíli stojí jiný robot")

	var target_is_water := world.water_depth_at(target) != GridTypes.WaterDepth.DRY
	if is_da:
		if target_is_water:
			return Validation.reject("Da do vody nesmí")
		if delta == GridTypes.DOWN_VECTOR and target == robot.cannot_land_cell:
			return Validation.reject("sem Da po odhození předmětu přistát nesmí")
	else:
		# Dul se svisle pohybuje jen uvnitř vody; vynoření řeší normální krok.
		if not target_is_water:
			return Validation.reject("Dul by opustil vodu")
	return Validation.accept({"target": target})

func _validate_switch(target_index: int, current_index: int) -> Validation:
	if target_index < 0 or target_index >= world.robots.size():
		return Validation.reject("takový robot na scéně není")
	var target: RobotState = world.robots[target_index]
	if target.in_target:
		return Validation.reject("robot je už v cíli")
	if target_index == current_index:
		return Validation.reject("robot už je aktivní")
	if not is_safe_to_leave(current_index):
		return Validation.reject("aktivní robot není v bezpečí — Da musí přistát")
	return Validation.accept({"target": target_index})

## §10 — jediný skutečný případ je Da ve vzduchu. Il si podrží ovládané
## zařízení přes přepnutí a Net nikdy nezůstává v mezistavu šplhání.
func is_safe_to_leave(robot_index: int) -> bool:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.DA:
		return true
	return world.has_support_below(robot.cell)

# ── 2. Aplikace ────────────────────────────────────────────────────────────

## Vrátí prázdný řetězec, když se příkaz provedl; jinak důvod, proč se
## neprovedl (jen DEVICE_INPUT — ostatní příkazy rozhoduje validace).
func _apply(command: Command, robot_index: int, validation: Validation,
		out_events: Array) -> String:
	var robot: RobotState = world.robots[robot_index]
	match command.type:
		Command.CommandType.TURN_LEFT:
			_turn(robot_index, GridTypes.turn_left(robot.facing), out_events)
		Command.CommandType.TURN_RIGHT:
			_turn(robot_index, GridTypes.turn_right(robot.facing), out_events)
		Command.CommandType.TURN_AROUND:
			_turn(robot_index, GridTypes.turn_around(robot.facing), out_events)
		Command.CommandType.STEP:
			for substep in validation.data["queue"]:
				_move_robot(robot_index, GridTypes.substep_delta(substep, robot.facing),
						substep, out_events)
				if robot.in_target:
					break
		Command.CommandType.STEP_UP:
			_move_robot(robot_index, GridTypes.UP_VECTOR,
					GridTypes.Substep.UP_VERTICAL, out_events)
		Command.CommandType.STEP_DOWN:
			_move_robot(robot_index, GridTypes.DOWN_VECTOR,
					GridTypes.Substep.DOWN_VERTICAL, out_events)
		Command.CommandType.ACTION_1:
			var action_1: Action = _action_1[robot.kind]
			action_1.apply(world, robot_index, validation, out_events)
		Command.CommandType.ACTION_2:
			var action_2: Action = _action_2[robot.kind]
			action_2.apply(world, robot_index, validation, out_events)
		Command.CommandType.SWITCH_ROBOT_NEXT, Command.CommandType.SWITCH_ROBOT_TO:
			_set_active_robot(validation.data["target"], out_events)
		Command.CommandType.DEVICE_INPUT:
			var device_validation := DeviceSystem.device_input(world, robot_index, out_events)
			if not device_validation.ok:
				return device_validation.reason
	return ""

func _turn(robot_index: int, new_facing: int, out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var old_facing := robot.facing
	robot.facing = new_facing
	out_events.append(Event.robot_turned(robot_index, old_facing, new_facing))

func _move_robot(robot_index: int, delta: Vector3i, substep: int, out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var from := robot.cell
	var to := from + delta
	robot.cell = to
	out_events.append(Event.robot_moved(robot_index, from, to, substep))
	_handle_cell_entry(robot_index, to, out_events)

## Efekty vstupu do buňky: sebrání předmětu a klíče (automatické, §12, §14)
## a vstup do cíle.
func _handle_cell_entry(robot_index: int, cell: Vector3i, out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]

	var item := world.item_at(cell)
	if item != GridTypes.NO_ITEM and robot.can_take(item):
		world.take_item_at(cell)
		robot.inventory.append(item)
		out_events.append(Event.item_picked_up(robot_index, item, cell))
		if robot.cannot_land_cell == cell:
			robot.cannot_land_cell = RobotState.NO_CELL

	if world.key_is_at(cell):
		world.key_holder = robot_index
		out_events.append(Event.key_picked_up(robot_index, cell))

	if world.block_at(cell) == GridTypes.BlockType.TARGET:
		_enter_target(robot_index, cell, out_events)

func _enter_target(robot_index: int, cell: Vector3i, out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	if not world.target_unlocked and world.key_holder == robot_index:
		world.target_unlocked = true
		out_events.append(Event.target_unlocked())
	robot.in_target = true
	world.finished_robots.append(robot_index)
	world.robot_sequence.erase(robot_index)
	out_events.append(Event.robot_entered_target(robot_index, cell))

	# Robot v cíli zmizí ze scény a hra rovnou přepne na dalšího v sekvenci —
	# bez kontroly is_safe_to_leave (§14).
	if not world.robot_sequence.is_empty():
		_set_active_robot(int(world.robot_sequence[0]), out_events)

func _set_active_robot(target_index: int, out_events: Array) -> void:
	var from := world.active_robot_index
	world.active_robot_index = target_index
	out_events.append(Event.active_robot_changed(from, target_index))

## Další robot v pevné cyklické sekvenci (§10).
func next_robot_in_sequence() -> int:
	if world.robot_sequence.is_empty():
		return -1
	var position := world.robot_sequence.find(world.active_robot_index)
	if position == -1:
		return int(world.robot_sequence[0])
	return int(world.robot_sequence[(position + 1) % world.robot_sequence.size()])

# ── 3. Dosazení ────────────────────────────────────────────────────────────

func _settle(out_events: Array) -> void:
	for _iteration in GridTypes.MAX_SETTLE_ITERATIONS:
		var events_before := out_events.size()
		Gravity.settle(world, out_events)
		WaterSystem.reidentify(world)
		DeviceSystem.run_automatics(world, out_events)
		if out_events.size() == events_before:
			return
	assert(false, "Dosazení překročilo MAX_SETTLE_ITERATIONS — chyba v pravidlech")

# ── 4. Invarianty ──────────────────────────────────────────────────────────

func _check_invariants() -> void:
	if not OS.is_debug_build():
		return
	var problems := world.check_invariants()
	if not problems.is_empty():
		push_error("Porušené invarianty: %s" % ", ".join(problems))
		assert(false, "Porušené invarianty po příkazu")

# ── 5. Postpodmínky ────────────────────────────────────────────────────────

func _check_postconditions(out_events: Array) -> void:
	if world.robots.is_empty():
		return
	if world.finished_robots.size() == world.robots.size():
		out_events.append(Event.level_completed())

func is_level_completed() -> bool:
	return not world.robots.is_empty() \
		and world.finished_robots.size() == world.robots.size()
