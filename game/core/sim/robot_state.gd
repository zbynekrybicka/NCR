class_name RobotState
extends RefCounted

## Běhový stav jednoho robota (§5.3).

const NO_CELL := Vector3i(-1, -1, -1)

var kind: int = GridTypes.RobotKind.HAN
var cell: Vector3i = Vector3i.ZERO
var facing: int = GridTypes.Direction.NORTH  # vždy < 4
var inventory: Array = []                     # ItemType, kapacita dle §12
var hopper_full: bool = false                 # Han: korba; Dul: cisterna
var controlling_device: int = -1              # Il: index zařízení, nebo -1
var cannot_land_cell: Vector3i = NO_CELL      # Da: kam po odhození nesmí přistát
var in_target: bool = false

func mass() -> int:
	return GridTypes.robot_mass(kind)

func inventory_capacity() -> int:
	return GridTypes.inventory_capacity(kind)

func has_inventory_room() -> bool:
	return inventory.size() < inventory_capacity()

func has_item(item: int) -> bool:
	return inventory.has(item)

func remove_item(item: int) -> bool:
	var idx := inventory.find(item)
	if idx == -1:
		return false
	inventory.remove_at(idx)
	return true

## Smí tento robot sebrat tento předmět (typ + volné místo)? §12
func can_take(item: int) -> bool:
	return GridTypes.can_pick_up(kind, item) and has_inventory_room()

func name_of() -> String:
	return GridTypes.robot_name(kind)

func duplicate_state() -> RobotState:
	var copy := RobotState.new()
	copy.kind = kind
	copy.cell = cell
	copy.facing = facing
	copy.inventory = inventory.duplicate()
	copy.hopper_full = hopper_full
	copy.controlling_device = controlling_device
	copy.cannot_land_cell = cannot_land_cell
	copy.in_target = in_target
	return copy
