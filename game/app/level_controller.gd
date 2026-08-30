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
var _restart_confirm_dialog: ConfirmationDialog
var intro_flight: IntroCameraFlight
var intro_text_overlay: IntroTextOverlay
var music: MusicPlayer

var input_locked: bool = false

## Uloženo ze `setup_with_simulation`, aby ho šlo znovu použít při přehrání
## intro přeletu po restartu levelu (§2.1.6) — restart je taky "zahájení
## levelu" (§2.1.1), takže musí přelet i úvodní text přehrát znovu.
var _world_position: Variant = null

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
	_world_position = world_position

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

	_restart_confirm_dialog = ConfirmationDialog.new()
	_restart_confirm_dialog.title = "Restartovat level"
	_restart_confirm_dialog.dialog_text = "Opravdu chceš restartovat level? Veškerý postup se ztratí."
	_restart_confirm_dialog.ok_button_text = "Restartovat"
	_restart_confirm_dialog.cancel_button_text = "Zrušit"
	_restart_confirm_dialog.confirmed.connect(func(): _send(Command.CommandType.RESTART_LEVEL, InputActions.RESTART_LEVEL))
	add_child(_restart_confirm_dialog)

	music = MusicPlayer.new()
	add_child(music)
	music.start()

	_focus_active_robot()
	hud.show_state(simulation, "")

	if simulation.level.has_intro_camera:
		_start_intro_flight(world_position)
	else:
		_maybe_show_intro_text()

## Úvodní přelet kamery (§2.1.1) z uložené pozice (v místní mřížce levelu,
## viz LevelData) do pozice, kde by CameraRig už normálně stál a sledoval
## prvního robota. `world_position` je stejná transformace jako pro WorldView
## výše — level zasazený do krajiny je zmenšený a posunutý, takže uložená
## pozice kamery se musí přepočítat stejně jako celá scéna.
func _start_intro_flight(world_position: Variant) -> void:
	var from_eye := _level_point_to_world(simulation.level.intro_camera_eye, world_position)
	var from_target := _level_point_to_world(simulation.level.intro_camera_target, world_position)
	var resting := camera_rig.resting_transform()

	camera_rig.set_process(false)
	camera_rig.set_process_unhandled_input(false) # jinak by orbit myší za letu tajně měnil yaw/pitch/zoom
	input_locked = true
	intro_flight = IntroCameraFlight.new()
	add_child(intro_flight)
	intro_flight.finished.connect(_on_intro_flight_finished)
	intro_flight.start(camera_rig.camera, from_eye, from_target, resting["eye"], resting["target"])

func _level_point_to_world(point: Vector3, world_position: Variant) -> Vector3:
	if world_position == null:
		return point
	return (world_position as Vector3) + point * LEVEL_SCALE_IN_WORLD

func _on_intro_flight_finished() -> void:
	intro_flight.queue_free()
	intro_flight = null
	_maybe_show_intro_text()

## Úvodní textová zpráva (§2.1.1) — zobrazí se po příjezdu kamery, tj. hned
## po dokončení intro přeletu, nebo hned na začátku levelu, který žádný
## přelet nemá. Beze zprávy (`intro_text` prázdný) se rovnou odemkne vstup.
func _maybe_show_intro_text() -> void:
	if simulation.level.intro_text.strip_edges() == "":
		_unlock_input()
		return
	input_locked = true
	camera_rig.set_process(false)
	camera_rig.set_process_unhandled_input(false)
	intro_text_overlay = IntroTextOverlay.new()
	add_child(intro_text_overlay)
	intro_text_overlay.closed.connect(_on_intro_text_closed)
	intro_text_overlay.show_text(simulation.level.intro_text)

func _on_intro_text_closed() -> void:
	intro_text_overlay.queue_free()
	intro_text_overlay = null
	_unlock_input()

func _unlock_input() -> void:
	camera_rig.set_process(true)
	camera_rig.set_process_unhandled_input(true)
	input_locked = false

func _unhandled_input(_event: InputEvent) -> void:
	if intro_text_overlay != null:
		return
	if intro_flight != null and intro_flight.is_playing():
		if Input.is_action_just_pressed(InputActions.SKIP_ANIMATION):
			intro_flight.skip()
		return
	if input_locked:
		return
	if Input.is_action_just_pressed(InputActions.SKIP_ANIMATION):
		animator.skip()
		return
	if Input.is_action_just_pressed(InputActions.CAMERA_FIRST_PERSON):
		camera_rig.first_person = not camera_rig.first_person
		_focus_active_robot()
		return
	if animator.is_playing():
		return # vstup je blokovaný po dobu přehrávání, ne simulace (§17.2)

	if Input.is_action_just_pressed(InputActions.RESTART_LEVEL):
		_restart_confirm_dialog.popup_centered()
		return

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
		if simulation.level.has_intro_camera:
			_start_intro_flight(_world_position)
		else:
			_maybe_show_intro_text()
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
