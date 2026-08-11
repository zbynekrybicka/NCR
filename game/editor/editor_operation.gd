class_name EditorOperation
extends RefCounted

## Jedna vratná operace editoru (§16.1). Editor má undo (na rozdíl od hry),
## implementované jako zásobník operací s apply()/revert().

func apply(_level: LevelData) -> void:
	pass

func revert(_level: LevelData) -> void:
	pass

func describe() -> String:
	return "operace"


## Změna jedné buňky (typ, model, orientace).
class SetCell extends EditorOperation:
	var cell: Vector3i
	var block: int
	var model_id: int
	var orientation: int
	var _old_block: int = 0
	var _old_model: int = 0
	var _old_orientation: int = 0

	func _init(p_cell: Vector3i, p_block: int, p_model_id: int = 0,
			p_orientation: int = 0) -> void:
		cell = p_cell
		block = p_block
		model_id = p_model_id
		orientation = p_orientation

	func apply(level: LevelData) -> void:
		_old_block = level.block_at(cell)
		_old_model = level.model_at(cell)
		_old_orientation = level.orientation_at(cell)
		level.set_block(cell, block)
		level.set_model(cell, model_id)
		level.set_orientation(cell, orientation)

	func revert(level: LevelData) -> void:
		level.set_block(cell, _old_block)
		level.set_model(cell, _old_model)
		level.set_orientation(cell, _old_orientation)

	func describe() -> String:
		return "nastavení buňky %s" % cell


## Položení předmětu; nahradí ten, co tam případně ležel.
class PlaceItem extends EditorOperation:
	var cell: Vector3i
	var item_type: int
	var _old_item: int = GridTypes.NO_ITEM

	func _init(p_cell: Vector3i, p_item_type: int) -> void:
		cell = p_cell
		item_type = p_item_type

	func apply(level: LevelData) -> void:
		_old_item = level.item_at(cell)
		_erase(level)
		level.items.append(LevelData.ItemPlacement.new(item_type, cell))

	func revert(level: LevelData) -> void:
		_erase(level)
		if _old_item != GridTypes.NO_ITEM:
			level.items.append(LevelData.ItemPlacement.new(_old_item, cell))

	func _erase(level: LevelData) -> void:
		for i in range(level.items.size() - 1, -1, -1):
			if level.items[i].cell == cell:
				level.items.remove_at(i)

	func describe() -> String:
		return "položení předmětu na %s" % cell


## Umístění robota daného druhu (přesune ho, pokud už v levelu je).
class PlaceRobot extends EditorOperation:
	var kind: int
	var cell: Vector3i
	var facing: int
	var sequence_index: int
	var _had_previous: bool = false
	var _previous: LevelData.RobotPlacement = null

	func _init(p_kind: int, p_cell: Vector3i, p_facing: int = 0,
			p_sequence_index: int = 0) -> void:
		kind = p_kind
		cell = p_cell
		facing = p_facing
		sequence_index = p_sequence_index

	func apply(level: LevelData) -> void:
		_had_previous = false
		for i in level.robots.size():
			if level.robots[i].kind == kind:
				_had_previous = true
				_previous = level.robots[i].duplicate_placement()
				level.robots.remove_at(i)
				break
		level.robots.append(
				LevelData.RobotPlacement.new(kind, cell, facing, sequence_index))

	func revert(level: LevelData) -> void:
		for i in range(level.robots.size() - 1, -1, -1):
			if level.robots[i].kind == kind:
				level.robots.remove_at(i)
		if _had_previous:
			level.robots.append(_previous.duplicate_placement())

	func describe() -> String:
		return "umístění robota %s" % GridTypes.robot_name(kind)


## Přesun klíče.
class MoveKey extends EditorOperation:
	var cell: Vector3i
	var _old_cell: Vector3i = Vector3i.ZERO

	func _init(p_cell: Vector3i) -> void:
		cell = p_cell

	func apply(level: LevelData) -> void:
		_old_cell = level.key_position
		level.key_position = cell

	func revert(level: LevelData) -> void:
		level.key_position = _old_cell

	func describe() -> String:
		return "přesun klíče na %s" % cell


## Změna rozměrů levelu. Zmenšení maže zasažené objekty (design dok. §2.2.1).
class Resize extends EditorOperation:
	var new_size: Vector3i
	var _snapshot: LevelData = null

	func _init(p_new_size: Vector3i) -> void:
		new_size = p_new_size

	func apply(level: LevelData) -> void:
		_snapshot = level.duplicate_level()
		var resized := LevelData.create_empty(new_size)
		for index in resized.cell_count():
			var cell := resized.index_to_cell(index)
			if not level.is_inside(cell):
				continue
			resized.blocks[index] = level.block_at(cell)
			resized.models[index] = level.model_at(cell)
			resized.orientations[index] = level.orientation_at(cell)
		level.size = resized.size
		level.blocks = resized.blocks
		level.models = resized.models
		level.orientations = resized.orientations
		_drop_outside(level)

	func revert(level: LevelData) -> void:
		var restored := _snapshot.duplicate_level()
		level.size = restored.size
		level.blocks = restored.blocks
		level.models = restored.models
		level.orientations = restored.orientations
		level.items = restored.items
		level.robots = restored.robots
		level.reservoirs = restored.reservoirs
		level.devices = restored.devices
		level.platforms = restored.platforms
		level.pumps = restored.pumps
		level.key_position = restored.key_position

	func _drop_outside(level: LevelData) -> void:
		for i in range(level.items.size() - 1, -1, -1):
			if not level.is_inside(level.items[i].cell):
				level.items.remove_at(i)
		for i in range(level.robots.size() - 1, -1, -1):
			if not level.is_inside(level.robots[i].cell):
				level.robots.remove_at(i)
		for i in range(level.devices.size() - 1, -1, -1):
			if not level.is_inside(level.devices[i].cell):
				level.devices.remove_at(i)
		for i in range(level.reservoirs.size() - 1, -1, -1):
			if not level.is_inside(level.reservoirs[i].anchor):
				level.reservoirs.remove_at(i)

	func describe() -> String:
		return "změna rozměrů na %s" % new_size
