class_name IlReleaseOrDrop
extends Action

## Il, Akce 2 — opuštění ovládání, jinak odložení service kitu (§7.6, §13.1).
## Ovládání má přednost: pokud Il právě ovládá zařízení, Akce 2 se od něj
## odpojí; teprve když nic neovládá, odkládá kit.

var _drop := DropItem.new(GridTypes.ItemType.SERVICE_KIT)

func validate(world: WorldState, robot_index: int) -> Validation:
	var robot: RobotState = world.robots[robot_index]
	if robot.kind != GridTypes.RobotKind.IL:
		return Validation.reject("tuhle akci má jen Il")
	if robot.controlling_device != -1:
		return Validation.accept({"release": true, "device": robot.controlling_device})
	var validation := _drop.validate(world, robot_index)
	if validation.ok:
		validation.data["release"] = false
	return validation

func apply(world: WorldState, robot_index: int, validation: Validation,
		out_events: Array) -> void:
	var robot: RobotState = world.robots[robot_index]
	if validation.data.get("release", false):
		var device_index: int = validation.data["device"]
		robot.controlling_device = -1
		out_events.append(Event.device_control_released(robot_index, device_index))
		return
	_drop.apply(world, robot_index, validation, out_events)
