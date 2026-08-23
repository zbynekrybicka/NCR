class_name LevelController
extends Node3D

## Drží Simulation, převádí vstup na Command a předává události animátorovi
## (§17.1, §17.2). Pravidla hry nezná — o všem rozhoduje simulace (P1, P5).

var simulation: Simulation
var view: WorldView
var animator: EventAnimator
var camera_rig: CameraRig
var hud: Hud
var landscape: LandscapeView

var input_locked: bool = false

## Akce, kterou po dokončení animace zopakujeme, pokud je pořád držená
## (plynulá chůze/otáčení, §17.4).
var _repeat_action: String = ""

## Level zasazený do krajiny se kreslí zmenšený na pětinu — v plném
## měřítku (1 buňka = 1 m, docs/import-assets.md §2.2) by proti okolní
## krajině (postavené v reálném měřítku, viz zadani_krajina_lowpoly_bpy.md
## §1) působil neúměrně velký. Mimo krajinu (world_position == null) se
## měřítko nemění.
const LEVEL_SCALE_IN_WORLD := 0.2

func setup(level: LevelData) -> void:
	setup_with_simulation(Simulation.new(level))

## Použije se, když už simulace existuje (např. náhled z editoru běží nad
## kopií editovaných dat — §16.1). `world_position`, je-li zadaná (viz
## CampaignMap, docs/import-assets.md §7.3), zasadí level do krajiny na
## dané místo — čistě kosmetická kulisa (§7.2), pravidla hry o ní nic neví.
func setup_with_simulation(p_simulation: Simulation, world_position: Variant = null) -> void:
	simulation = p_simulation

	if world_position != null:
		landscape = LandscapeView.new()
		add_child(landscape)

	view = WorldView.new()
	add_child(view)
	if world_position != null:
		view.position = world_position
		view.scale = Vector3.ONE * LEVEL_SCALE_IN_WORLD
	view.build(simulation.world)

	animator = EventAnimator.new()
	animator.view = view
	add_child(animator)
	animator.finished.connect(_on_animation_finished)

	camera_rig = CameraRig.new()
	if world_position != null:
		camera_rig.set_level_scale(LEVEL_SCALE_IN_WORLD)
	add_child(camera_rig)

	hud = Hud.new()
	add_child(hud)

	_focus_active_robot()
	hud.show_state(simulation, "")

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.SKIP_ANIMATION):
		animator.skip()
		return
	if Input.is_action_just_pressed(InputActions.CAMERA_FIRST_PERSON):
		camera_rig.first_person = not camera_rig.first_person
		_focus_active_robot()
		return
	if animator.is_playing():
		return # vstup je blokovaný po dobu přehrávání, ne simulace (§17.2)

	for action in InputActions.COMMAND_FOR.keys():
		if Input.is_action_just_pressed(action):
			_send(InputActions.COMMAND_FOR[action], action)
			return

func _send(command_type: int, action: String = "") -> void:
	var result := simulation.submit_command(Command.new(command_type))
	if result.has_event(Event.EventType.LEVEL_RESTARTED):
		view.build(simulation.world)
		_focus_active_robot()
		hud.show_state(simulation, "Level restartován")
		_repeat_action = ""
		return
	# Nastavit PŘED přehráním: když fronta neobsahuje nic k animaci (typicky
	# odmítnutý příkaz), `animator.play` vyvolá `finished` synchronně ještě
	# uvnitř tohoto volání — _on_animation_finished by jinak četl starou
	# hodnotu z předchozího (přijatého) příkazu a rekurzivně se vnořoval do
	# nekonečna (přetečení zásobníku, viz §17.4).
	_repeat_action = action if result.accepted and InputActions.REPEATABLE.has(action) else ""
	animator.play(result.events)
	hud.show_state(simulation, result.reason if not result.accepted else "")
	_focus_active_robot()

func _on_animation_finished() -> void:
	view.refresh_items()
	_focus_active_robot()
	hud.show_state(simulation, "")
	if _repeat_action != "" and Input.is_action_pressed(_repeat_action):
		# Odloženo na příští snímek — `_send` by (přes `animator.play`) mohl
		# `finished` vyvolat znovu synchronně a vnořovat se do zásobníku bez
		# odvíjení (viz pojistka výše).
		call_deferred("_send", InputActions.COMMAND_FOR[_repeat_action], _repeat_action)

func _focus_active_robot() -> void:
	var robot := simulation.world.active_robot()
	if robot == null:
		return
	camera_rig.follow(view.robot_node(simulation.world.active_robot_index))
	camera_rig.set_facing(robot.facing)
