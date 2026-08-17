class_name IlInteract
extends Action

## Il, Akce 1 — oprava zařízení nebo jeho sepnutí (§7.6, §13.1,
## design dokument §1.1.7). Sepnutí je jednorázové: jeden stisk = jedno
## stisknutí tlačítka / přehození přepínače, žádný režim ovládání neexistuje.

enum IlResult { REPAIR, INPUT }

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.IL:
		return Validation.reject("se zařízeními pracuje jen Il")

	var ahead := ActionHelpers.ahead_cell(world, robot_index)
	var device_index := world.device_at(ahead)
	if device_index == -1:
		return Validation.reject("před robotem není zařízení")
	var device: DeviceState = world.devices[device_index]

	if device.is_broken:
		if not robot.has_item(GridTypes.ItemType.SERVICE_KIT):
			return Validation.reject("zařízení je rozbité a chybí service kit")
		return Validation.accept({"device": device_index, "result": IlResult.REPAIR})

	if not device.is_accessible_from(robot.cell, robot.facing):
		return Validation.reject("k zařízení se nedá dostat z tohoto směru")

	# Jestli sepnutí něco udělá, závisí na stavu napojených plošin a čerpadel —
	# ptá se na to čistá kontrola, aby akce zůstala validovatelná dopředu (§13.1).
	var input := DeviceSystem.device_input_validate(world, device_index)
	if not input.ok:
		return input
	return Validation.accept({"device": device_index, "result": IlResult.INPUT})

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	var device_index: int = validation.data["device"]
	var device: DeviceState = world.devices[device_index]

	if validation.data["result"] == IlResult.REPAIR:
		robot.remove_item(GridTypes.ItemType.SERVICE_KIT)
		device.is_broken = false
		# Opravená skříň je rovnou pod napětím — stejně jako skříň bez poruchy
		# po startu levelu (DeviceSystem.initialize). Bez toho by zůstala
		# vypnutá a napojené čerpadlo ani plošina by se po opravě nerozjely.
		if device.kind == GridTypes.DeviceKind.POWER_CABINET:
			device.is_on = true
		out_events.append(Event.device_repaired(device_index))
		return

	DeviceSystem.device_input(world, device_index, out_events)
