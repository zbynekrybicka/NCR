class_name DemoLevel
extends RefCounted

## Ukázkový level postavený v kódu — než vzniknou levely z editoru (§20.1).
## Splňuje validační pravidla V1–V14.

const SIZE := Vector3i(10, 4, 8)

static func build() -> LevelData:
	var level := LevelData.create_empty(SIZE)

	# Podlaha
	for x in SIZE.x:
		for z in SIZE.z:
			level.set_block(Vector3i(x, 0, z), GridTypes.BlockType.WALL)

	# Hliněná přepážka, kterou musí Han prokopat
	for z in range(1, 6):
		level.set_block(Vector3i(4, 1, z), GridTypes.BlockType.DIRT)

	# Vyvýšená plošina se šikminou
	for x in range(7, 10):
		for z in range(4, 7):
			level.set_block(Vector3i(x, 1, z), GridTypes.BlockType.WALL)
	level.set_block(Vector3i(6, 1, 5), GridTypes.BlockType.RAMP)
	level.set_orientation(Vector3i(6, 1, 5), GridTypes.Direction.EAST)

	# Klíč, cíl, kanystr
	level.key_position = Vector3i(6, 1, 1)
	level.set_block(Vector3i(8, 2, 5), GridTypes.BlockType.TARGET)
	level.items.append(LevelData.ItemPlacement.new(GridTypes.ItemType.FUEL,
			Vector3i(2, 1, 4)))

	# Roboti
	level.robots.append(LevelData.RobotPlacement.new(GridTypes.RobotKind.HAN,
			Vector3i(1, 1, 1), GridTypes.Direction.EAST, 0))
	level.robots.append(LevelData.RobotPlacement.new(GridTypes.RobotKind.NET,
			Vector3i(1, 1, 3), GridTypes.Direction.EAST, 1))

	level.level_name = "Ukázka"
	return level
