class_name Action
extends RefCounted

## Základ akce robota (§11). Dvě metody, přísně oddělené:
##   validate() — čistá, NESMÍ mutovat stav (P5); vrací i data pro apply()
##   apply()    — mutace WorldState, průběžně sbírá události (P8)

func validate(_world: WorldState, _robot_index: int) -> Validation:
	return Validation.reject("akce není definovaná")

func apply(_world: WorldState, _robot_index: int, _validation: Validation,
		_out_events: Array) -> void:
	pass
