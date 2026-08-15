class_name EditorSession
extends RefCounted

## Editor pracuje nad TÝMŽ LevelData, které používá runtime (P6, §16.1).
## Nemá vlastní paralelní reprezentaci světa.

var level: LevelData
var selection: Array = []          # Vector3i
var undo_stack: Array = []         # EditorOperation
var redo_stack: Array = []

func _init(p_level: LevelData = null) -> void:
	level = p_level if p_level != null else LevelData.create_empty(Vector3i(8, 8, 8))

func run(operation: EditorOperation) -> void:
	operation.apply(level)
	undo_stack.append(operation)
	redo_stack.clear()

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func undo() -> void:
	if undo_stack.is_empty():
		return
	var operation: EditorOperation = undo_stack.pop_back()
	operation.revert(level)
	redo_stack.append(operation)

func redo() -> void:
	if redo_stack.is_empty():
		return
	var operation: EditorOperation = redo_stack.pop_back()
	operation.apply(level)
	undo_stack.append(operation)

## Validace podle §16.2 — editor nesmí dovolit pravidla porušit.
func validate() -> Array:
	return LevelValidator.validate(level)

func is_valid() -> bool:
	return validate().is_empty()

# ── Dotazy pro editorové UI (mechanismy) ───────────────────────────────────
#
# Tvar nádrže se neukládá, odvozuje se z geometrie (§9.1) — editor se na něj
# proto ptá přes stejný WorldState, jaký postaví runtime. Levely jsou malé,
# takže se stav staví na dotaz a nikde se necachuje.

func preview_world() -> WorldState:
	return WorldState.from_level(level)

func device_index_at(cell: Vector3i) -> int:
	for i in level.devices.size():
		if level.devices[i].cell == cell:
			return i
	return -1

func reservoir_index_at_anchor(cell: Vector3i) -> int:
	for i in level.reservoirs.size():
		if level.reservoirs[i].anchor == cell:
			return i
	return -1

## Index nádrže, do jejíž dutiny buňka patří (ne nutně kotevní), nebo -1.
func reservoir_index_at(cell: Vector3i) -> int:
	return preview_world().reservoir_at(cell)

## Je buňka součástí uzavřené dutiny, ze které voda nevyteče (V11)? Editor
## tím ověřuje, že tam smí vzniknout nádrž.
func cell_is_in_closed_cavity(cell: Vector3i) -> bool:
	var world := preview_world()
	for component in WaterSystem.find_closed_cavities(world):
		if component.has(cell):
			return true
	return false

## Kapacita nádrže v půlkostkových jednotkách (§9.1); -1, když kotevní buňka
## v žádné dutině neleží.
func reservoir_capacity(index: int) -> int:
	var world := preview_world()
	if index < 0 or index >= world.reservoirs.size():
		return -1
	var res: ReservoirState = world.reservoirs[index]
	if res.cells.is_empty():
		return -1
	return res.total_capacity()

func platform_index_at(cell: Vector3i) -> int:
	for i in level.platforms.size():
		var platform = level.platforms[i]
		for member in platform.cells:
			if member + platform.pose_a == cell:
				return i
	return -1

## Indexy zařízení daného druhu — pro nabídky vazeb v UI.
func device_indices_of_kind(kind: int) -> Array:
	var out: Array = []
	for i in level.devices.size():
		if level.devices[i].kind == kind:
			out.append(i)
	return out

## Náhled (playtest) běží nad KOPIÍ dat; editovaná data se náhledem nikdy
## nezmění (§16.1).
func start_playtest() -> Simulation:
	return Simulation.new(level.duplicate_level())

func save_to_file(path: String) -> Error:
	return LevelWriter.save_to_file(level, path)

func load_from_file(path: String) -> String:
	var result := LevelReader.load_from_file(path)
	if not result.ok:
		return result.error
	level = result.level
	undo_stack.clear()
	redo_stack.clear()
	return ""
