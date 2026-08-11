class_name Validation
extends RefCounted

## Výsledek validační fáze akce/příkazu (§6.2, §11). Validace nesmí mutovat
## stav (P5) — proto si výsledek nese i data, která už spočítala, aby je
## aplikační fáze nemusela počítat znovu.

var ok: bool = false
var reason: String = ""
var data: Dictionary = {}

func _init(p_ok: bool = false, p_reason: String = "", p_data: Dictionary = {}) -> void:
	ok = p_ok
	reason = p_reason
	data = p_data

static func accept(p_data: Dictionary = {}) -> Validation:
	return Validation.new(true, "", p_data)

static func reject(p_reason: String) -> Validation:
	return Validation.new(false, p_reason, {})

func _to_string() -> String:
	return "Validation(ok=%s, %s)" % [ok, reason]
