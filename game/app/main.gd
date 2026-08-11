extends Node

## Vstupní bod hry. Zatím rovnou spouští ukázkový level — hlavní menu
## a načítání levelů ze souborů přijdou v M17 (§20.4).

func _ready() -> void:
	InputActions.register_defaults()

	var level := DemoLevel.build()
	var problems := LevelValidator.validate(level)
	if not problems.is_empty():
		push_error("Ukázkový level je nevalidní: %s" % ", ".join(problems))

	var controller := LevelController.new()
	add_child(controller)
	controller.setup(level)
