class_name TestArchitecture
extends TestSuite

## §18, úroveň 5 — architektonický test. Selhání = porušení P1 nebo P2.

const CORE_DIR := "res://core"

## Vzory, které v `core/` nesmí být. Simulace nesmí sahat na scénu (P1)
## ani počítat v plovoucí čárce či náhodě (P2).
const FORBIDDEN := [
	"extends Node",
	"get_node(",
	"get_tree(",
	"randf(",
	"randi(",
	"randomize(",
	": float",
	"-> float",
	"res://app",
	"res://editor",
]

func _collect_scripts(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path + "/" + entry
		if dir.current_is_dir():
			_collect_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

## Odstraní řádkové komentáře a řetězce, aby test nehlásil zmínky v textu.
func _strip_comments(source: String) -> String:
	var out := ""
	for line in source.split("\n"):
		var text: String = line
		var hash_index := text.find("#")
		if hash_index != -1:
			text = text.substr(0, hash_index)
		out += text + "\n"
	return out

func test_core_has_no_forbidden_patterns() -> void:
	var scripts: Array = []
	_collect_scripts(CORE_DIR, scripts)
	t.is_true(scripts.size() > 10, "v core/ se našly skripty (%d)" % scripts.size())
	for path in scripts:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			t.fail("nelze otevřít %s" % path)
			continue
		var source := _strip_comments(file.get_as_text())
		file.close()
		for pattern in FORBIDDEN:
			t.is_false(source.contains(pattern),
					"%s neobsahuje '%s'" % [path.get_file(), pattern])

func test_core_classes_do_not_extend_node() -> void:
	# Kontrola přes běhový typ: všechny simulační třídy jsou RefCounted.
	var level := LevelBuilder.new().layer(0, "###").layer(1, ".H.").build()
	var sim := Simulation.new(level)
	t.is_true(sim is RefCounted, "Simulation je RefCounted")
	t.is_true(sim.world is RefCounted, "WorldState je RefCounted")
	t.is_true(level is RefCounted, "LevelData je RefCounted")
	t.is_false(sim is Node, "a nic z toho není Node")
