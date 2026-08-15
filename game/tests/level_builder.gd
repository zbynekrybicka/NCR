class_name LevelBuilder
extends RefCounted

## Testovací fixtura (§18): level se staví textovým zápisem po vrstvách,
## aby byl test čitelný.
##
## Vrstva 0 je nejnižší. V textu jde X doprava, Z dolů.
##
## Legenda:
##   `.` prázdno       `#` zeď          `D` hlína     `S` kámen
##   `I` led           `W` dřevo        `T` cíl
##   `^ v < >` šikmina stoupající k severu / jihu / západu / východu
##   roboti: `H` Han, `U` Dul, `E` Set, `N` Net, `A` Da, `Y` Yeo, `L` Il
##   předměty: `f` kanystr s palivem, `s` service kit
##   `+` klíč
## Robot/předmět/klíč se umisťuje do prázdné buňky.

const BLOCK_CHARS := {
	".": GridTypes.BlockType.EMPTY,
	"#": GridTypes.BlockType.WALL,
	"D": GridTypes.BlockType.DIRT,
	"S": GridTypes.BlockType.STONE,
	"I": GridTypes.BlockType.ICE,
	"W": GridTypes.BlockType.WOOD,
	"T": GridTypes.BlockType.TARGET,
}

const RAMP_CHARS := {
	"^": GridTypes.Direction.NORTH,
	"v": GridTypes.Direction.SOUTH,
	"<": GridTypes.Direction.WEST,
	">": GridTypes.Direction.EAST,
}

const ROBOT_CHARS := {
	"H": GridTypes.RobotKind.HAN,
	"U": GridTypes.RobotKind.DUL,
	"E": GridTypes.RobotKind.SET,
	"N": GridTypes.RobotKind.NET,
	"A": GridTypes.RobotKind.DA,
	"Y": GridTypes.RobotKind.YEO,
	"L": GridTypes.RobotKind.IL,
}

const ITEM_CHARS := {
	"f": GridTypes.ItemType.FUEL,
	"s": GridTypes.ItemType.SERVICE_KIT,
}

var _layers: Array = []          # y -> Array[String] (řádky)
var _reservoirs: Array = []      # [anchor, volume, unlimited]
var _devices: Array = []
var _platforms: Array = []
var _pumps: Array = []
var _facings: Dictionary = {}    # RobotKind -> Direction
var _key_cell: Vector3i = Vector3i(-1, -1, -1)

func layer(y: int, text: String) -> LevelBuilder:
	while _layers.size() <= y:
		_layers.append([])
	var rows: Array = []
	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		rows.append(line)
	_layers[y] = rows
	return self

func facing(kind: int, direction: int) -> LevelBuilder:
	_facings[kind] = direction
	return self

func key(cell: Vector3i) -> LevelBuilder:
	_key_cell = cell
	return self

func reservoir(anchor: Vector3i, volume_units: int, unlimited: bool = false) -> LevelBuilder:
	_reservoirs.append([anchor, volume_units, unlimited])
	return self

func device(kind: int, cell: Vector3i, access_direction: int,
		control_mode: int = 0, is_broken: bool = false) -> LevelBuilder:
	_devices.append(LevelData.DeviceDef.new(kind, control_mode, cell,
			access_direction, is_broken))
	return self

func platform(cells: Array, pose_a: Vector3i, pose_b: Vector3i, weight_limit: int,
		cabinets: Array, control_units: Array = []) -> LevelBuilder:
	var def := LevelData.PlatformDef.new()
	def.cells = cells
	def.pose_a = pose_a
	def.pose_b = pose_b
	def.weight_limit = weight_limit
	def.linked_cabinets = cabinets
	def.linked_control_units = control_units
	_platforms.append(def)
	return self

func pump(reservoir_a: int, reservoir_b: int, cabinets: Array, control_unit: int = -1,
		bidirectional: bool = false, default_direction: int = 0) -> LevelBuilder:
	_pumps.append(LevelData.PumpDef.new(reservoir_a, reservoir_b, bidirectional,
			default_direction, cabinets, control_unit))
	return self

func build() -> LevelData:
	var z_width := 0
	var x_len := 0
	for rows in _layers:
		z_width = maxi(z_width, rows.size())
		for row in rows:
			x_len = maxi(x_len, String(row).length())

	var level := LevelData.create_empty(Vector3i(x_len, _layers.size(), z_width))
	var robots: Array = []

	for y in _layers.size():
		var rows: Array = _layers[y]
		for z in rows.size():
			var row: String = rows[z]
			for x in row.length():
				var cell := Vector3i(x, y, z)
				var symbol := row[x]
				if BLOCK_CHARS.has(symbol):
					level.set_block(cell, BLOCK_CHARS[symbol])
					continue
				if RAMP_CHARS.has(symbol):
					level.set_block(cell, GridTypes.BlockType.RAMP)
					level.set_orientation(cell, RAMP_CHARS[symbol])
					continue
				if ROBOT_CHARS.has(symbol):
					robots.append([ROBOT_CHARS[symbol], cell])
					continue
				if ITEM_CHARS.has(symbol):
					level.items.append(
							LevelData.ItemPlacement.new(ITEM_CHARS[symbol], cell))
					continue
				if symbol == "+":
					_key_cell = cell
					continue
				push_error("LevelBuilder: neznámý znak '%s' na %s" % [symbol, cell])

	for i in robots.size():
		var kind: int = robots[i][0]
		var cell: Vector3i = robots[i][1]
		var dir: int = int(_facings.get(kind, GridTypes.Direction.EAST))
		level.robots.append(LevelData.RobotPlacement.new(kind, cell, dir, i))

	for entry in _reservoirs:
		level.reservoirs.append(LevelData.ReservoirDef.new(entry[0], entry[1], entry[2]))
	level.devices = _devices
	level.platforms = _platforms
	level.pumps = _pumps
	level.key_position = _key_cell if _key_cell.x >= 0 else Vector3i.ZERO
	return level

## Zkratka: level → hotová simulace.
func simulate() -> Simulation:
	return Simulation.new(build())
