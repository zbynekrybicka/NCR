class_name InputActions
extends RefCounted

## Vstupní akce (§17.4). Registrují se za běhu, aby byly přemapovatelné
## a nemusely žít napevno v project.godot.

const TURN_LEFT := "turn_left"
const TURN_RIGHT := "turn_right"
const TURN_AROUND := "turn_around"
const STEP := "step"
const STEP_UP := "step_up"
const STEP_DOWN := "step_down"
const ACTION_1 := "action_1"
const ACTION_2 := "action_2"
const SWITCH_ROBOT := "switch_robot"
const DEVICE_INPUT := "device_input"
const CAMERA_FIRST_PERSON := "camera_first_person"
const RESTART_LEVEL := "restart_level"
const SKIP_ANIMATION := "skip_animation"

## akce -> seznam kláves (Key)
const DEFAULTS := {
	TURN_LEFT: [KEY_A, KEY_LEFT],
	TURN_RIGHT: [KEY_D, KEY_RIGHT],
	TURN_AROUND: [KEY_S, KEY_DOWN],
	STEP: [KEY_W, KEY_UP],
	STEP_UP: [KEY_SPACE, KEY_PAGEUP],
	STEP_DOWN: [KEY_SHIFT, KEY_PAGEDOWN],
	ACTION_1: [KEY_Q],
	ACTION_2: [KEY_E],
	SWITCH_ROBOT: [KEY_TAB],
	DEVICE_INPUT: [KEY_ENTER],
	CAMERA_FIRST_PERSON: [KEY_F],
	RESTART_LEVEL: [KEY_R],
	SKIP_ANIMATION: [KEY_ESCAPE],
}

## Mapování akce → příkaz simulace. Vstupní vrstva pravidla nezná (P1, P5) —
## posílá příkaz vždy a simulace ho případně odmítne.
const COMMAND_FOR := {
	TURN_LEFT: Command.CommandType.TURN_LEFT,
	TURN_RIGHT: Command.CommandType.TURN_RIGHT,
	TURN_AROUND: Command.CommandType.TURN_AROUND,
	STEP: Command.CommandType.STEP,
	STEP_UP: Command.CommandType.STEP_UP,
	STEP_DOWN: Command.CommandType.STEP_DOWN,
	ACTION_1: Command.CommandType.ACTION_1,
	ACTION_2: Command.CommandType.ACTION_2,
	SWITCH_ROBOT: Command.CommandType.SWITCH_ROBOT_NEXT,
	DEVICE_INPUT: Command.CommandType.DEVICE_INPUT,
	RESTART_LEVEL: Command.CommandType.RESTART_LEVEL,
}

static func register_defaults() -> void:
	for action in DEFAULTS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in DEFAULTS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
