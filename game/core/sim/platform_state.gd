class_name PlatformState
extends RefCounted

## Transportní plošina (§13.2). Pohyb může být vodorovný, svislý i diagonální.

var cells: Array = []                 # Vector3i — členské buňky v základní poloze
var pose_a: Vector3i = Vector3i.ZERO  # offsety obou krajních poloh
var pose_b: Vector3i = Vector3i.ZERO
var current_pose: int = 0             # 0 = A, 1 = B
var weight_limit: int = 0
var linked_cabinets: Array = []       # indexy do WorldState.devices
var linked_control_units: Array = []  # prázdné → automatická plošina
## Automatická plošina se spouští na náběžné hraně splnění podmínky, ne
## opakovaně každý příkaz — jinak by mezi polohami kmitala. Design dokument
## §2.2.1 mluví o „jakmile je limit splněn", tj. o přechodu stavu.
var trigger_latched: bool = false

func current_offset() -> Vector3i:
	return pose_b if current_pose == 1 else pose_a

func other_offset() -> Vector3i:
	return pose_a if current_pose == 1 else pose_b

func offset_of_pose(pose: int) -> Vector3i:
	return pose_b if pose == 1 else pose_a

## Buňky, které plošina zabírá v dané poloze.
func cells_at_pose(pose: int) -> Array:
	var offset := offset_of_pose(pose)
	var out: Array = []
	for c in cells:
		out.append(c + offset)
	return out

func occupied_cells() -> Array:
	return cells_at_pose(current_pose)

func is_manual() -> bool:
	return not linked_control_units.is_empty()

func duplicate_state() -> PlatformState:
	var copy := PlatformState.new()
	copy.cells = cells.duplicate()
	copy.pose_a = pose_a
	copy.pose_b = pose_b
	copy.current_pose = current_pose
	copy.weight_limit = weight_limit
	copy.linked_cabinets = linked_cabinets.duplicate()
	copy.linked_control_units = linked_control_units.duplicate()
	copy.trigger_latched = trigger_latched
	return copy
