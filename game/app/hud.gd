class_name Hud
extends CanvasLayer

## Funkční minimum HUD (§20.1: vizuál UI je mimo rozsah 0.1.0) — aktivní
## robot, jeho stav a důvod posledního odmítnutého příkazu.

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)

func show_state(simulation: Simulation, message: String) -> void:
	if _label == null:
		return
	var world := simulation.world
	var robot := world.active_robot()
	if robot == null:
		_label.text = "Žádný aktivní robot"
		return
	var lines: Array = []
	lines.append("Aktivní: %s   (Tab přepne)" % robot.name_of())
	lines.append("Pozice: %s   směr: %s"
			% [robot.cell, GridTypes.Direction.keys()[robot.facing]])
	lines.append("Inventář: %d/%d%s"
			% [robot.inventory.size(), robot.inventory_capacity(),
				"   korba plná" if robot.hopper_full else ""])
	lines.append("Klíč: %s   cíl: %s"
			% ["u robota %d" % world.key_holder if world.key_holder != -1 else "na zemi",
				"odemčený" if world.target_unlocked else "zamčený"])
	lines.append("V cíli: %d / %d" % [world.finished_robots.size(), world.robots.size()])
	if message != "":
		lines.append("» " + message)
	if simulation.is_level_completed():
		lines.append("LEVEL DOKONČEN")
	_label.text = "\n".join(lines)
