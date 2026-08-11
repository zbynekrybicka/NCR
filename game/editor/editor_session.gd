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
