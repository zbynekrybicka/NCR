class_name DeviceState
extends RefCounted

## Elektrická skříň / řídicí jednotka (§13.1).

var kind: int = GridTypes.DeviceKind.POWER_CABINET
var control_mode: int = GridTypes.ControlMode.BUTTON  # jen CONTROL_UNIT
var cell: Vector3i = Vector3i.ZERO
var access_direction: int = GridTypes.Direction.NORTH
var is_broken: bool = false
var is_on: bool = false

## Buňka, ze které se zařízení ovládá — soused ve směru `access_direction`.
func access_cell() -> Vector3i:
	return cell + GridTypes.dir_vector(access_direction)

## Il musí stát v přístupové buňce a být otočený k zařízení (§13.1).
func is_accessible_from(robot_cell: Vector3i, robot_facing: int) -> bool:
	if robot_cell != access_cell():
		return false
	return GridTypes.turn_around(access_direction) == robot_facing

func duplicate_state() -> DeviceState:
	var copy := DeviceState.new()
	copy.kind = kind
	copy.control_mode = control_mode
	copy.cell = cell
	copy.access_direction = access_direction
	copy.is_broken = is_broken
	copy.is_on = is_on
	return copy
