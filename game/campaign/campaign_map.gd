class_name CampaignMap
extends RefCounted

## Evidence "kde ve světě leží který level" — vědomě mimo formát levelu
## (docs/import-assets.md §7.3: pozice v krajině je vlastnost kampaně, ne
## levelu — dva levely se stejným obsahem mohou ležet jinde a hráčovy
## levely z editoru žádné oficiální místo nemají). Klíčem je cesta k
## souboru levelu (stejná hodnota, kterou vrací uložení/načtení v editoru).
##
## Tohle je autorská pracovní evidence v user:// (stejná logika jako
## EditorUi.LEVELS_DIR pro samotné levely) — ne hotový res://campaign/
## campaign.json katalog oficiální kampaně, což je samostatný pozdější
## krok (A14 v docs/import-assets.md §8).

const DEFAULT_PATH := "user://campaign_map.json"

var _entries: Dictionary = {}   # level_path (String) -> Vector3

func load_from_file(path: String = DEFAULT_PATH) -> void:
	_entries.clear()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for level_path in parsed.keys():
		var entry = parsed[level_path]
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("position"):
			continue
		var pos: Array = entry["position"]
		if pos.size() != 3:
			continue
		_entries[level_path] = Vector3(pos[0], pos[1], pos[2])

func save_to_file(path: String = DEFAULT_PATH) -> Error:
	var out := {}
	for level_path in _entries.keys():
		var pos: Vector3 = _entries[level_path]
		out[level_path] = {"position": [pos.x, pos.y, pos.z]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	return OK

## null, když level ještě žádné místo ve světě nemá.
func get_position(level_path: String) -> Variant:
	return _entries.get(level_path)

func has_position(level_path: String) -> bool:
	return _entries.has(level_path)

func set_position(level_path: String, position: Vector3) -> void:
	_entries[level_path] = position

func remove_position(level_path: String) -> void:
	_entries.erase(level_path)
