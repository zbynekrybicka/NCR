class_name PumpState
extends RefCounted

## Čerpadlo mezi dvěma nádržemi (§13.3).

## Kolik jednotek přenese jedno sepnutí — jedna kostka vody.
const TRANSFER_UNITS := GridTypes.UNITS_PER_CUBE

var reservoir_a: int = 0
var reservoir_b: int = 0
var bidirectional: bool = false
var default_direction: int = 0     # 0 = A→B, 1 = B→A
var current_direction: int = 0     # u SWITCH se střídá
var linked_cabinet: int = -1
var linked_control_unit: int = -1  # -1 → automatické
## Automatické čerpadlo přečerpá jednou na náběžné hraně napájení, ne každý
## příkaz — stejný důvod jako u plošiny (§13.2).
var trigger_latched: bool = false

func is_manual() -> bool:
	return linked_control_unit != -1

func source_reservoir(direction: int) -> int:
	return reservoir_a if direction == 0 else reservoir_b

func target_reservoir(direction: int) -> int:
	return reservoir_b if direction == 0 else reservoir_a

func duplicate_state() -> PumpState:
	var copy := PumpState.new()
	copy.reservoir_a = reservoir_a
	copy.reservoir_b = reservoir_b
	copy.bidirectional = bidirectional
	copy.default_direction = default_direction
	copy.current_direction = current_direction
	copy.linked_cabinet = linked_cabinet
	copy.linked_control_unit = linked_control_unit
	copy.trigger_latched = trigger_latched
	return copy
