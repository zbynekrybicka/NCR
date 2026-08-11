class_name BTLibrary
extends RefCounted

## Načítání a výběr stromů kroku (§7.5, §7.6).
##
## Odchylka od §7.5: stromy nejsou `.tres`, ale JSON v `core/bt/trees/`.
## Důvod je praktický — soubor stromu se ručně píše a čte v diffu, JSON jde
## editovat i validovat bez Godot inspektoru a nese stejná data. Požadavek
## P7 (pravidla jsou data, ne kód) tím zůstává splněný.
##
## Sdílený základ chůze (§7.6.0) je jeden soubor `walk_base.json`, ne sedm
## kopií — Han, Set, Il i Dul po souši ho používají beze změny.

const TREE_DIR := "res://core/bt/trees/"

const TREE_WALK_BASE := "walk_base"
const TREE_WALK_YEO := "walk_yeo"
const TREE_NET := "net"
const TREE_DA := "da"
const TREE_DUL_SWIM := "dul_swim"

const ALL_TREES := [TREE_WALK_BASE, TREE_WALK_YEO, TREE_NET, TREE_DA, TREE_DUL_SWIM]

static var _cache: Dictionary = {}

static func load_tree(tree_name: String) -> Dictionary:
	if _cache.has(tree_name):
		return _cache[tree_name]
	var path := TREE_DIR + tree_name + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Strom nelze načíst: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("root"):
		push_error("Poškozený soubor stromu: %s" % path)
		return {}
	var root: Dictionary = parsed["root"]
	_cache[tree_name] = root
	return root

static func clear_cache() -> void:
	_cache.clear()

## Výběr stromu podle druhu robota i podle jeho stavu — Dul plave vlastním
## stromem, dokud je ve vodě (§7.6, komentář u Dula).
static func tree_name_for(world: WorldState, robot_index: int) -> String:
	var robot: RobotState = world.robots[robot_index]
	match robot.kind:
		GridTypes.RobotKind.DUL:
			if world.water_depth_at(robot.cell) != GridTypes.WaterDepth.DRY:
				return TREE_DUL_SWIM
			return TREE_WALK_BASE
		GridTypes.RobotKind.DA:
			return TREE_DA
		GridTypes.RobotKind.NET:
			return TREE_NET
		GridTypes.RobotKind.YEO:
			return TREE_WALK_YEO
	return TREE_WALK_BASE

static func tree_for(world: WorldState, robot_index: int) -> Dictionary:
	return load_tree(tree_name_for(world, robot_index))
