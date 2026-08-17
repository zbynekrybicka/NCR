class_name Command
extends RefCounted

## Jediný vstup do simulace (§6.1). Uzavřený výčet — nic jiného stav nemění.

enum CommandType {
	TURN_LEFT,
	TURN_RIGHT,
	TURN_AROUND,
	STEP,
	STEP_UP,
	STEP_DOWN,
	ACTION_1,
	ACTION_2,
	SWITCH_ROBOT_NEXT,
	SWITCH_ROBOT_TO,
	RESTART_LEVEL,
}

var type: int
var target_index: int = -1   # SWITCH_ROBOT_TO: cílový robot

func _init(p_type: int = CommandType.STEP, p_target_index: int = -1) -> void:
	type = p_type
	target_index = p_target_index

func type_name() -> String:
	return CommandType.keys()[type]

func _to_string() -> String:
	if target_index >= 0:
		return "%s(%d)" % [type_name(), target_index]
	return type_name()


## Výsledek jednoho příkazu (§6.2).
class Result extends RefCounted:
	var accepted: bool = false
	var reason: String = ""
	var events: Array = []   # Event

	func _init(p_accepted: bool = true, p_reason: String = "") -> void:
		accepted = p_accepted
		reason = p_reason

	func has_event(event_type: int) -> bool:
		for event in events:
			if event.type == event_type:
				return true
		return false

	func events_of(event_type: int) -> Array:
		var out: Array = []
		for event in events:
			if event.type == event_type:
				out.append(event)
		return out

	func _to_string() -> String:
		return "Result(accepted=%s, reason=%s, events=%d)" % [accepted, reason, events.size()]
