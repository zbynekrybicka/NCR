class_name MusicPlayer
extends AudioStreamPlayer

## Hudba na pozadí levelu. Skladby leží v assets/music (mp3); Menu.mp3 je
## vyhrazená pro budoucí hlavní menu (§20.4 zatím neexistuje) a do výběru se
## nezařazuje. Level po spuštění začne hrát náhodnou skladbu a po jejím
## dohrání navazuje další náhodná, aby hudba běžela nepřetržitě. Klávesou H
## (SWITCH_MUSIC) lze skladbu kdykoli přeskočit na jinou, opět náhodně
## vybranou.

const MUSIC_DIR := "res://assets/music"
const EXCLUDED_TRACK := "Menu.mp3"

var _tracks: Array[String] = []
var _last_track: String = ""

func start() -> void:
	if _tracks.is_empty():
		_tracks = _scan_tracks()
	if not finished.is_connected(_play_random):
		finished.connect(_play_random)
	_play_random()

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.SWITCH_MUSIC):
		_play_random()

func _scan_tracks() -> Array[String]:
	var tracks: Array[String] = []
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return tracks
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".mp3") and entry != EXCLUDED_TRACK:
			tracks.append(MUSIC_DIR + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return tracks

func _play_random() -> void:
	if _tracks.is_empty():
		return
	var track := _pick_track()
	_last_track = track
	stream = load(track)
	play()

## Vybere náhodnou skladbu jinou než tu poslední (pokud jich je na výběr
## víc), ať se hned po sobě neopakuje stejná.
func _pick_track() -> String:
	if _tracks.size() == 1:
		return _tracks[0]
	var choice := _last_track
	while choice == _last_track:
		choice = _tracks[randi() % _tracks.size()]
	return choice
