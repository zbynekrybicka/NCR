class_name TestGravity
extends TestSuite

## §8 — usazování odspodu nahoru, sloupec spadne v jednom průchodu, robot na
## vrcholu propadající se věže klesne bez zničení, hledání místa dopadu.

func test_single_block_falls() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "#.")
		.layer(1, ".S")
		.build())
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.EMPTY, "kámen odletěl")
	t.equal(world.block_at(Vector3i(1, 0, 0)), GridTypes.BlockType.STONE, "a dopadl o patro níž")
	t.equal(events.size(), 1, "jedna událost pádu")
	t.equal(events[0].type, Event.EventType.BLOCK_FELL, "typ události")

func test_wall_and_ice_never_fall() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "..")
		.layer(1, "#I")
		.build())
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.block_at(Vector3i(0, 1, 0)), GridTypes.BlockType.WALL, "zeď se nehnula")
	t.equal(world.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.ICE,
			"led je vždy ukotvený a nikdy nepadá")

func test_column_settles_in_one_pass() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "##")
		.layer(1, ".D")
		.layer(2, ".S")
		.layer(3, ".D")
		.build())
	world.set_block(Vector3i(1, 1, 0), GridTypes.BlockType.EMPTY)
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.block_at(Vector3i(1, 1, 0)), GridTypes.BlockType.STONE, "kámen klesl o jedna")
	t.equal(world.block_at(Vector3i(1, 2, 0)), GridTypes.BlockType.DIRT, "hlína klesla o jedna")
	t.equal(world.block_at(Vector3i(1, 3, 0)), GridTypes.BlockType.EMPTY, "nahoře zbylo prázdno")

func test_robot_rides_the_collapsing_tower() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "##")
		.layer(1, ".D")
		.layer(2, ".H")
		.build())
	world.set_block(Vector3i(1, 1, 0), GridTypes.BlockType.EMPTY)
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.robots[0].cell, Vector3i(1, 1, 0), "Han klesl s věží o jednu kostku")
	t.is_true(world.check_invariants().is_empty(), "a nic se nezničilo")

func test_da_does_not_fall() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "##")
		.layer(1, ".A")
		.layer(2, "..")
		.build())
	world.robots[0].cell = Vector3i(1, 2, 0)
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.robots[0].cell, Vector3i(1, 2, 0), "Da zůstal viset ve vzduchu")

func test_landing_cell_for_drop() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "##")
		.layer(1, "..")
		.layer(2, "..")
		.build())
	t.equal(Gravity.landing_cell_for_drop(world, Vector3i(1, 2, 0)), Vector3i(1, 1, 0),
			"kostka propadne až na pevný podklad")
	t.equal(Gravity.landing_cell_for_drop(world, Vector3i(0, 0, 0)), RobotState.NO_CELL,
			"do zdi nic nespadne")

func test_items_fall_too() -> void:
	var world := WorldState.from_level(LevelBuilder.new()
		.layer(0, "#.")
		.layer(1, "..")
		.build())
	world.put_item_at(Vector3i(1, 1, 0), GridTypes.ItemType.FUEL)
	var events: Array = []
	Gravity.settle(world, events)
	t.equal(world.item_at(Vector3i(1, 0, 0)), GridTypes.ItemType.FUEL,
			"předmět bez podpory klesl")
