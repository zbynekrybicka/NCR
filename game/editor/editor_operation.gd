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


## Sdílené pro Resize a ResizeRow: zahodí objekty mimo aktuální rozměry
## levelu po změně velikosti. Zařízení a nádrže se odkazují číslem (plošiny,
## čerpadla), takže se odkazy přemapují a mechanismus, který přišel o
## povinnou vazbu, se odebere celý — jinak by level zůstal nevalidní
## (V10, V17).
static func _drop_objects_outside(level: LevelData) -> void:
	for i in range(level.items.size() - 1, -1, -1):
		if not level.is_inside(level.items[i].cell):
			level.items.remove_at(i)
	for i in range(level.robots.size() - 1, -1, -1):
		if not level.is_inside(level.robots[i].cell):
			level.robots.remove_at(i)

	var device_map := {}
	var kept_devices: Array = []
	for i in level.devices.size():
		if not level.is_inside(level.devices[i].cell):
			continue
		device_map[i] = kept_devices.size()
		kept_devices.append(level.devices[i])
	level.devices = kept_devices

	var reservoir_map := {}
	var kept_reservoirs: Array = []
	for i in level.reservoirs.size():
		if not level.is_inside(level.reservoirs[i].anchor):
			continue
		reservoir_map[i] = kept_reservoirs.size()
		kept_reservoirs.append(level.reservoirs[i])
	level.reservoirs = kept_reservoirs

	for i in range(level.platforms.size() - 1, -1, -1):
		var platform = level.platforms[i]
		var outside := false
		for cell in platform.cells:
			if not level.is_inside(cell + platform.pose_a) \
					or not level.is_inside(cell + platform.pose_b):
				outside = true
				break
		platform.linked_cabinets = _remap_indices(platform.linked_cabinets, device_map)
		platform.linked_control_units = _remap_indices(platform.linked_control_units, device_map)
		if outside or platform.linked_cabinets.is_empty():
			level.platforms.remove_at(i)

	for i in range(level.pumps.size() - 1, -1, -1):
		var pump = level.pumps[i]
		if not reservoir_map.has(pump.reservoir_a) or not reservoir_map.has(pump.reservoir_b):
			level.pumps.remove_at(i)
			continue
		pump.reservoir_a = reservoir_map[pump.reservoir_a]
		pump.reservoir_b = reservoir_map[pump.reservoir_b]
		pump.linked_cabinets = _remap_indices(pump.linked_cabinets, device_map)
		pump.linked_control_unit = int(device_map.get(pump.linked_control_unit, -1))
		if pump.linked_cabinets.is_empty():
			level.pumps.remove_at(i)

static func _remap_indices(indices: Array, mapping: Dictionary) -> Array:
	var out: Array = []
	for index in indices:
		if mapping.has(index):
			out.append(mapping[index])
	return out


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


## Umístění robota na konec pořadí; existuje-li už v levelu, přesune ho.
## Na rozdíl od PlaceRobot rovnou přečísluje sequence_index všech robotů
## podle jejich pořadí v poli, takže sekvence zůstává platnou permutací
## (V12) i po přidání/přesunu v editoru bez ručního zásahu.
class PlaceRobotAppend extends EditorOperation:
	var kind: int
	var cell: Vector3i
	var facing: int
	var _had_previous: bool = false
	var _previous: LevelData.RobotPlacement = null
	var _old_sequence: Dictionary = {} # kind -> sequence_index před operací

	func _init(p_kind: int, p_cell: Vector3i, p_facing: int = 0) -> void:
		kind = p_kind
		cell = p_cell
		facing = p_facing

	func apply(level: LevelData) -> void:
		_old_sequence.clear()
		for r in level.robots:
			_old_sequence[r.kind] = r.sequence_index
		_had_previous = false
		for i in range(level.robots.size() - 1, -1, -1):
			if level.robots[i].kind == kind:
				_had_previous = true
				_previous = level.robots[i].duplicate_placement()
				level.robots.remove_at(i)
				break
		level.robots.append(LevelData.RobotPlacement.new(kind, cell, facing, 0))
		_renumber(level)

	func revert(level: LevelData) -> void:
		for i in range(level.robots.size() - 1, -1, -1):
			if level.robots[i].kind == kind:
				level.robots.remove_at(i)
		if _had_previous:
			level.robots.append(_previous.duplicate_placement())
		for r in level.robots:
			if _old_sequence.has(r.kind):
				r.sequence_index = _old_sequence[r.kind]

	func _renumber(level: LevelData) -> void:
		for i in level.robots.size():
			level.robots[i].sequence_index = i

	func describe() -> String:
		return "umístění robota %s" % GridTypes.robot_name(kind)


## Odebrání robota daného druhu; přečíslovává sekvenci stejně jako
## PlaceRobotAppend (V12 zůstává splněné).
class RemoveRobotRenumber extends EditorOperation:
	var kind: int
	var _removed: LevelData.RobotPlacement = null
	var _old_sequence: Dictionary = {}

	func _init(p_kind: int) -> void:
		kind = p_kind

	func apply(level: LevelData) -> void:
		_old_sequence.clear()
		for r in level.robots:
			_old_sequence[r.kind] = r.sequence_index
		_removed = null
		for i in range(level.robots.size() - 1, -1, -1):
			if level.robots[i].kind == kind:
				_removed = level.robots[i].duplicate_placement()
				level.robots.remove_at(i)
				break
		_renumber(level)

	func revert(level: LevelData) -> void:
		if _removed != null:
			level.robots.append(_removed.duplicate_placement())
		for r in level.robots:
			if _old_sequence.has(r.kind):
				r.sequence_index = _old_sequence[r.kind]

	func _renumber(level: LevelData) -> void:
		for i in level.robots.size():
			level.robots[i].sequence_index = i

	func describe() -> String:
		return "odebrání robota %s" % GridTypes.robot_name(kind)


## Odebrání předmětu na dané buňce (pokud tam nějaký leží).
class RemoveItem extends EditorOperation:
	var cell: Vector3i
	var _removed_type: int = GridTypes.NO_ITEM

	func _init(p_cell: Vector3i) -> void:
		cell = p_cell

	func apply(level: LevelData) -> void:
		_removed_type = GridTypes.NO_ITEM
		for i in range(level.items.size() - 1, -1, -1):
			if level.items[i].cell == cell:
				_removed_type = level.items[i].item_type
				level.items.remove_at(i)
				break

	func revert(level: LevelData) -> void:
		if _removed_type != GridTypes.NO_ITEM:
			level.items.append(LevelData.ItemPlacement.new(_removed_type, cell))

	func describe() -> String:
		return "odebrání předmětu na %s" % cell


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


## Umístění elektrické skříně / řídicí jednotky. Zařízení zabírá vlastní
## kostku, která se chová jako zeď (design dok. §2.2.1) — operace proto
## současně nastaví na dané buňce blok WALL. Zařízení už na buňce stojící
## se nahradí.
class PlaceDevice extends EditorOperation:
	var cell: Vector3i
	var kind: int
	var control_mode: int
	var access_direction: int
	var is_broken: bool
	var _old_block: int = 0
	var _old_model: int = 0
	var _old_orientation: int = 0
	var _replaced_index: int = -1
	var _replaced: LevelData.DeviceDef = null

	func _init(p_cell: Vector3i, p_kind: int, p_access_direction: int,
			p_control_mode: int = 0, p_is_broken: bool = false) -> void:
		cell = p_cell
		kind = p_kind
		access_direction = p_access_direction
		control_mode = p_control_mode
		is_broken = p_is_broken

	func apply(level: LevelData) -> void:
		_old_block = level.block_at(cell)
		_old_model = level.model_at(cell)
		_old_orientation = level.orientation_at(cell)
		_replaced_index = -1
		_replaced = null
		for i in level.devices.size():
			if level.devices[i].cell == cell:
				_replaced_index = i
				_replaced = level.devices[i].duplicate_def()
				level.devices.remove_at(i)
				break
		level.set_block(cell, GridTypes.BlockType.WALL)
		level.set_orientation(cell, access_direction)
		level.devices.append(LevelData.DeviceDef.new(kind, control_mode, cell,
				access_direction, is_broken))
		if _replaced_index != -1:
			# Nahrazení na stejném indexu — vazby plošin a čerpadel na zařízení
			# jsou číselné a nesmí se posunout.
			var placed = level.devices.pop_back()
			level.devices.insert(_replaced_index, placed)

	func revert(level: LevelData) -> void:
		for i in range(level.devices.size() - 1, -1, -1):
			if level.devices[i].cell == cell:
				level.devices.remove_at(i)
				break
		if _replaced != null:
			level.devices.insert(_replaced_index, _replaced.duplicate_def())
		level.set_block(cell, _old_block)
		level.set_model(cell, _old_model)
		level.set_orientation(cell, _old_orientation)

	func describe() -> String:
		return "umístění zařízení na %s" % cell


## Odebrání zařízení i kostky zdi, ve které sedí. Vazby plošin a čerpadel na
## zařízení jsou číselné, takže se odebráním přečíslují — operace to udělá
## sama, aby level zůstal validní (V17).
class RemoveDevice extends EditorOperation:
	var cell: Vector3i
	var _removed_index: int = -1
	var _removed: LevelData.DeviceDef = null
	var _old_block: int = 0
	var _platform_links: Array = []   # [cabinets, control_units] před operací
	var _pump_links: Array = []       # [cabinets, control_unit] před operací

	func _init(p_cell: Vector3i) -> void:
		cell = p_cell

	func apply(level: LevelData) -> void:
		_removed_index = -1
		for i in level.devices.size():
			if level.devices[i].cell == cell:
				_removed_index = i
				_removed = level.devices[i].duplicate_def()
				break
		if _removed_index == -1:
			return
		_old_block = level.block_at(cell)
		_platform_links = []
		for platform in level.platforms:
			_platform_links.append([platform.linked_cabinets.duplicate(),
					platform.linked_control_units.duplicate()])
		_pump_links = []
		for pump in level.pumps:
			_pump_links.append([pump.linked_cabinets.duplicate(), pump.linked_control_unit])

		level.devices.remove_at(_removed_index)
		level.set_block(cell, GridTypes.BlockType.EMPTY)
		for platform in level.platforms:
			platform.linked_cabinets = _shift(platform.linked_cabinets, _removed_index)
			platform.linked_control_units = _shift(platform.linked_control_units, _removed_index)
		for pump in level.pumps:
			pump.linked_cabinets = _shift(pump.linked_cabinets, _removed_index)
			pump.linked_control_unit = _shift_one(pump.linked_control_unit, _removed_index)

	func revert(level: LevelData) -> void:
		if _removed == null:
			return
		level.devices.insert(_removed_index, _removed.duplicate_def())
		level.set_block(cell, _old_block)
		for i in level.platforms.size():
			level.platforms[i].linked_cabinets = _platform_links[i][0].duplicate()
			level.platforms[i].linked_control_units = _platform_links[i][1].duplicate()
		for i in level.pumps.size():
			level.pumps[i].linked_cabinets = _pump_links[i][0].duplicate()
			level.pumps[i].linked_control_unit = _pump_links[i][1]

	## Odkazy na odebrané zařízení zmizí, vyšší indexy se posunou o jedna dolů.
	static func _shift(indices: Array, removed: int) -> Array:
		var out: Array = []
		for index in indices:
			if index == removed:
				continue
			out.append(index - 1 if index > removed else index)
		return out

	static func _shift_one(index: int, removed: int) -> int:
		if index == removed:
			return -1
		return index - 1 if index > removed else index

	func describe() -> String:
		return "odebrání zařízení na %s" % cell


## Založení nebo úprava nádrže. Tvar se neukládá — odvozuje se z geometrie
## zdí (§9.1), definice nese jen kotevní buňku, počáteční objem a příznak
## neomezenosti (design dok. §2.2.1).
class SetReservoir extends EditorOperation:
	var anchor: Vector3i
	var volume_units: int
	var unlimited: bool
	var _existing_index: int = -1
	var _previous: LevelData.ReservoirDef = null

	func _init(p_anchor: Vector3i, p_volume_units: int, p_unlimited: bool = false) -> void:
		anchor = p_anchor
		volume_units = p_volume_units
		unlimited = p_unlimited

	func apply(level: LevelData) -> void:
		_existing_index = -1
		_previous = null
		for i in level.reservoirs.size():
			if level.reservoirs[i].anchor == anchor:
				_existing_index = i
				_previous = level.reservoirs[i].duplicate_def()
				break
		var def := LevelData.ReservoirDef.new(anchor, volume_units, unlimited)
		if _existing_index == -1:
			level.reservoirs.append(def)
		else:
			level.reservoirs[_existing_index] = def

	func revert(level: LevelData) -> void:
		if _existing_index == -1:
			for i in range(level.reservoirs.size() - 1, -1, -1):
				if level.reservoirs[i].anchor == anchor:
					level.reservoirs.remove_at(i)
					break
			return
		level.reservoirs[_existing_index] = _previous.duplicate_def()

	func describe() -> String:
		return "nastavení nádrže na %s" % anchor


## Odebrání nádrže. Čerpadla na nádrže odkazují číslem, takže se odkazy
## přečíslují a čerpadlo, které o nádrž přišlo, se odebere taky (V10).
class RemoveReservoir extends EditorOperation:
	var anchor: Vector3i
	var _removed_index: int = -1
	var _removed: LevelData.ReservoirDef = null
	var _old_pumps: Array = []

	func _init(p_anchor: Vector3i) -> void:
		anchor = p_anchor

	func apply(level: LevelData) -> void:
		_removed_index = -1
		for i in level.reservoirs.size():
			if level.reservoirs[i].anchor == anchor:
				_removed_index = i
				_removed = level.reservoirs[i].duplicate_def()
				break
		if _removed_index == -1:
			return
		_old_pumps = []
		for pump in level.pumps:
			_old_pumps.append(pump.duplicate_def())
		level.reservoirs.remove_at(_removed_index)
		for i in range(level.pumps.size() - 1, -1, -1):
			var pump = level.pumps[i]
			if pump.reservoir_a == _removed_index or pump.reservoir_b == _removed_index:
				level.pumps.remove_at(i)
				continue
			if pump.reservoir_a > _removed_index:
				pump.reservoir_a -= 1
			if pump.reservoir_b > _removed_index:
				pump.reservoir_b -= 1

	func revert(level: LevelData) -> void:
		if _removed == null:
			return
		level.reservoirs.insert(_removed_index, _removed.duplicate_def())
		level.pumps.clear()
		for pump in _old_pumps:
			level.pumps.append(pump.duplicate_def())

	func describe() -> String:
		return "odebrání nádrže na %s" % anchor


## Přidání transportní plošiny. `cells` jsou buňky zdí v poloze A, `pose_b`
## je posun druhé polohy vůči první (§13.2); `weight_limit` je spouštěcí
## práh (design dok. §2.2.1).
class AddPlatform extends EditorOperation:
	var cells: Array
	var pose_b: Vector3i
	var weight_limit: int
	var cabinets: Array
	var control_units: Array

	func _init(p_cells: Array, p_pose_b: Vector3i, p_weight_limit: int,
			p_cabinets: Array, p_control_units: Array = []) -> void:
		cells = p_cells.duplicate()
		pose_b = p_pose_b
		weight_limit = p_weight_limit
		cabinets = p_cabinets.duplicate()
		control_units = p_control_units.duplicate()

	func apply(level: LevelData) -> void:
		var def := LevelData.PlatformDef.new()
		def.cells = cells.duplicate()
		def.pose_a = Vector3i.ZERO
		def.pose_b = pose_b
		def.weight_limit = weight_limit
		def.linked_cabinets = cabinets.duplicate()
		def.linked_control_units = control_units.duplicate()
		level.platforms.append(def)

	func revert(level: LevelData) -> void:
		if not level.platforms.is_empty():
			level.platforms.pop_back()

	func describe() -> String:
		return "přidání plošiny (%d buněk)" % cells.size()


class RemovePlatform extends EditorOperation:
	var index: int
	var _removed: LevelData.PlatformDef = null

	func _init(p_index: int) -> void:
		index = p_index

	func apply(level: LevelData) -> void:
		if index < 0 or index >= level.platforms.size():
			return
		_removed = level.platforms[index].duplicate_def()
		level.platforms.remove_at(index)

	func revert(level: LevelData) -> void:
		if _removed != null:
			level.platforms.insert(index, _removed.duplicate_def())

	func describe() -> String:
		return "odebrání plošiny %d" % index


## Přidání čerpadla mezi dvě nádrže (§13.3). Bez řídicí jednotky
## (`control_unit == -1`) je čerpadlo automatické.
class AddPump extends EditorOperation:
	var reservoir_a: int
	var reservoir_b: int
	var bidirectional: bool
	var default_direction: int
	var cabinets: Array
	var control_unit: int

	func _init(p_a: int, p_b: int, p_cabinets: Array, p_control_unit: int = -1,
			p_bidirectional: bool = false, p_default_direction: int = 0) -> void:
		reservoir_a = p_a
		reservoir_b = p_b
		cabinets = p_cabinets.duplicate()
		control_unit = p_control_unit
		bidirectional = p_bidirectional
		default_direction = p_default_direction

	func apply(level: LevelData) -> void:
		level.pumps.append(LevelData.PumpDef.new(reservoir_a, reservoir_b, bidirectional,
				default_direction, cabinets, control_unit))

	func revert(level: LevelData) -> void:
		if not level.pumps.is_empty():
			level.pumps.pop_back()

	func describe() -> String:
		return "přidání čerpadla %d → %d" % [reservoir_a, reservoir_b]


class RemovePump extends EditorOperation:
	var index: int
	var _removed: LevelData.PumpDef = null

	func _init(p_index: int) -> void:
		index = p_index

	func apply(level: LevelData) -> void:
		if index < 0 or index >= level.pumps.size():
			return
		_removed = level.pumps[index].duplicate_def()
		level.pumps.remove_at(index)

	func revert(level: LevelData) -> void:
		if _removed != null:
			level.pumps.insert(index, _removed.duplicate_def())

	func describe() -> String:
		return "odebrání čerpadla %d" % index


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
		EditorOperation._drop_objects_outside(level)

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

	func describe() -> String:
		return "změna rozměrů na %s" % new_size


## Rozšíření/zúžení levelu o jednu řadu ve zvoleném směru — ovládá se
## rozklikávacími prvky u okrajů levelu v editoru (design dok. §2.2.1).
## Směr DOWN je vyloučen, dno levelu se nikdy nemění. Zúžení se smí provést,
## jen když je celá odebíraná řada úplně prázdná (žádný blok, robot, předmět,
## zařízení, nádrž ani klíč) — jinak `apply()` level nezmění (ověř `can_shrink`
## / `did_apply` před zápisem do undo historie, viz EditorSession).
class ResizeRow extends EditorOperation:
	var direction: int      # GridTypes.Direction, kromě DOWN
	var grow: bool
	var _snapshot: LevelData = null
	var _applied: bool = false

	func _init(p_direction: int, p_grow: bool) -> void:
		direction = p_direction
		grow = p_grow

	func apply(level: LevelData) -> void:
		_snapshot = level.duplicate_level()
		_applied = false
		var unit := _axis_unit(direction)
		if grow:
			var shift := unit if _is_near(direction) else Vector3i.ZERO
			_resize(level, shift, level.size + unit)
			_applied = true
		elif can_shrink(level):
			var shift := -unit if _is_near(direction) else Vector3i.ZERO
			_resize(level, shift, level.size - unit)
			_applied = true

	func revert(level: LevelData) -> void:
		if not _applied or _snapshot == null:
			return
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

	## Skutečně se operace provedla? (Zúžení se odmítne, není-li řada prázdná.)
	func did_apply() -> bool:
		return _applied

	## Je celá řada, kterou by zúžení odebralo, prázdná? Volá i EditorSession
	## pro dotaz z UI, ještě než se operace vůbec spustí.
	func can_shrink(level: LevelData) -> bool:
		if direction == GridTypes.Direction.DOWN:
			return false
		if _axis_length(level.size, direction) <= 1:
			return false
		return _removed_slice_is_empty(level, _shrink_slice_index(level))

	func _removed_slice_is_empty(level: LevelData, slice: int) -> bool:
		for index in level.cell_count():
			var cell := level.index_to_cell(index)
			if _cell_axis_coord(cell) != slice:
				continue
			if level.blocks[index] != GridTypes.BlockType.EMPTY:
				return false
		for it in level.items:
			if _cell_axis_coord(it.cell) == slice:
				return false
		for r in level.robots:
			if _cell_axis_coord(r.cell) == slice:
				return false
		for d in level.devices:
			if _cell_axis_coord(d.cell) == slice:
				return false
		for res in level.reservoirs:
			if _cell_axis_coord(res.anchor) == slice:
				return false
		if _cell_axis_coord(level.key_position) == slice:
			return false
		return true

	func _shrink_slice_index(level: LevelData) -> int:
		if _is_near(direction):
			return 0
		return _axis_length(level.size, direction) - 1

	## Přestaví level na nové rozměry a posune všechny buňky/objekty o `shift`
	## (nenulové jen u WEST/NORTH, kde se přidává/ubírá řada na nulovém konci
	## osy — viz _is_near).
	func _resize(level: LevelData, shift: Vector3i, new_size: Vector3i) -> void:
		var resized := LevelData.create_empty(new_size)
		for index in level.cell_count():
			var cell := level.index_to_cell(index)
			var dest := cell + shift
			if not resized.is_inside(dest):
				continue
			resized.set_block(dest, level.blocks[index])
			resized.set_model(dest, level.models[index])
			resized.set_orientation(dest, level.orientations[index])
		level.size = resized.size
		level.blocks = resized.blocks
		level.models = resized.models
		level.orientations = resized.orientations

		level.key_position += shift
		for it in level.items:
			it.cell += shift
		for r in level.robots:
			r.cell += shift
		for res in level.reservoirs:
			res.anchor += shift
		for d in level.devices:
			d.cell += shift
		for p in level.platforms:
			for i in p.cells.size():
				p.cells[i] += shift

		EditorOperation._drop_objects_outside(level)

	func _cell_axis_coord(cell: Vector3i) -> int:
		var unit := _axis_unit(direction)
		return unit.x * cell.x + unit.y * cell.y + unit.z * cell.z

	static func _axis_length(size: Vector3i, dir: int) -> int:
		var unit := _axis_unit(dir)
		return unit.x * size.x + unit.y * size.y + unit.z * size.z

	static func _axis_unit(dir: int) -> Vector3i:
		var v := GridTypes.dir_vector(dir)
		return Vector3i(abs(v.x), abs(v.y), abs(v.z))

	## WEST a NORTH rostou/zužují na nulovém konci osy — tam se musí zbytek
	## levelu posunout, aby nová řada vznikla na indexu 0 (resp. aby se
	## odebrala právě řada 0). EAST, SOUTH a UP rostou/zužují na horním konci,
	## kde žádný posun není potřeba.
	static func _is_near(dir: int) -> bool:
		return dir == GridTypes.Direction.WEST or dir == GridTypes.Direction.NORTH

	func describe() -> String:
		var verb := "rozšíření" if grow else "zúžení"
		return "%s levelu směrem %s" % [verb, GridTypes.Direction.keys()[direction]]
