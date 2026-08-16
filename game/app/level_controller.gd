class_name LevelController
extends Node3D

## Drží Simulation, převádí vstup na Command a předává události animátorovi
## (§17.1, §17.2). Pravidla hry nezná — o všem rozhoduje simulace (P1, P5).

var simulation: Simulation
var view: WorldView
var animator: EventAnimator
var camera_rig: CameraRig
var hud: Hud

var input_locked: bool = false

func setup(level: LevelData) -> void:
	setup_with_simulation(Simulation.new(level))

## Použije se, když už simulace existuje (např. náhled z editoru běží nad
## kopií editovaných dat — §16.1).
func setup_with_simulation(p_simulation: Simulation) -> void:
	simulation = p_simulation

	view = WorldView.new()
	add_child(view)
	view.build(simulation.world)

	animator = EventAnimator.new()
	animator.view = view
	add_child(animator)
	animator.finished.connect(_on_animation_finished)

	camera_rig = CameraRig.new()
	add_child(camera_rig)

	hud = Hud.new()
	add_child(hud)

	_focus_active_robot(true)
	hud.show_state(simulation, "")

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.SKIP_ANIMATION):
		animator.skip()
		return
	if Input.is_action_just_pressed(InputActions.CAMERA_FIRST_PERSON):
		camera_rig.first_person = not camera_rig.first_person
		_focus_active_robot(true)
		return
	if animator.is_playing():
		return # vstup je blokovaný po dobu přehrávání, ne simulace (§17.2)

	for action in InputActions.COMMAND_FOR.keys():
		if Input.is_action_just_pressed(action):
			_send(InputActions.COMMAND_FOR[action])
			return

func _send(command_type: int) -> void:
	var result := simulation.submit_command(Command.new(command_type))
	if result.has_event(Event.EventType.LEVEL_RESTARTED):
		view.build(simulation.world)
		_focus_active_robot(true)
		hud.show_state(simulation, "Level restartován")
		return
	animator.play(result.events)
	hud.show_state(simulation, result.reason if not result.accepted else "")
	_focus_active_robot(false)

func _on_animation_finished() -> void:
	view.refresh_items()
	_focus_active_robot(false)
	hud.show_state(simulation, "")

func _focus_active_robot(instant: bool) -> void:
	var robot := simulation.world.active_robot()
	if robot == null:
		return
	camera_rig.look_at_cell(robot.cell, instant)
	camera_rig.set_facing(robot.facing)
