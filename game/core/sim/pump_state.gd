class_name PumpState
extends RefCounted

## Čerpadlo mezi dvěma nádržemi (§13.3).

## Jedno sepnutí přečerpá celý obsah zdrojové nádrže (design dok. §2.2.1),
## takže čerpadlo nemá pevný objem dávky — počítá se z `volume_units` zdroje.

var reservoir_a: int = 0
var reservoir_b: int = 0
var bidirectional: bool = false
var default_direction: int = 0     # 0 = A→B, 1 = B→A
var current_direction: int = 0     # u SWITCH se střídá
var linked_cabinets: Array = []    # indexy do WorldState.devices
var linked_control_unit: int = -1  # -1 → automatické
## Automatické čerpadlo sepne na náběžné hraně splnění všech podmínek přenosu,
## ne každý příkaz — stejný důvod jako u plošiny (§13.2). Od chvíle, kdy jedno
## sepnutí přečerpá celý obsah zdroje, je zámek jen pojistka: po přenosu je
## zdroj prázdný, takže podmínka stejně sama přestane platit.
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
	copy.linked_cabinets = linked_cabinets.duplicate()
	copy.linked_control_unit = linked_control_unit
	copy.trigger_latched = trigger_latched
	return copy
