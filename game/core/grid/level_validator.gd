class_name LevelValidator
extends RefCounted

## Validační pravidla V1–V14 (§16.2). Čistá logika nad LevelData.
##
## Umístění: `core/grid/`, ne `editor/` — pravidla potřebuje i čtečka levelu
## (§15), a `core/` nesmí záviset na `editor/` (§3). Editor je používá taky.

const RULE_NAMES := {
	"V1": "právě jeden klíč",
	"V2": "právě jeden cíl",
	"V3": "1–7 robotů, každý typ nejvýše jednou",
	"V4": "roboti jen na zemi nebo ploché zdi; Dul i ve vodě",
	"V5": "objekty (kromě zdí a šikmin) nesmí viset ve vzduchu",
	"V6": "na šikminu nelze nic umístit",
	"V7": "led jen uvnitř nádrže",
	"V8": "dráha plošiny neprochází statickými objekty",
	"V9": "každá plošina má aspoň jednu elektrickou skříň",
	"V10": "čerpadlo odkazuje na dvě existující nádrže; zdrojová není neomezená",
	"V11": "nádrž je uzavřená dutina",
	"V12": "sekvence robotů je úplná permutace",
	"V13": "počáteční objem nádrže ≤ její kapacita",
	"V14": "žádný robot nezačíná v hluboké vodě (kromě Dula)",
}

## Vrátí seznam popsaných porušení; prázdné pole = level je v pořádku.
static func validate(level: LevelData) -> Array:
	var problems: Array = []
	if level.size.x <= 0 or level.size.y <= 0 or level.size.z <= 0:
		problems.append("level má nulový rozměr")
		return problems

	var world := WorldState.from_level(level)

	_check_key(level, problems)
	_check_target(level, problems)
	_check_robots(level, world, problems)
	_check_floating(level, problems)
	_check_ramps(level, problems)
	_check_ice(level, world, problems)
	_check_platforms(level, problems)
	_check_pumps(level, problems)
	_check_reservoirs(level, world, problems)
	return problems

static func _fail(problems: Array, rule: String, detail: String) -> void:
	problems.append("%s (%s): %s" % [rule, RULE_NAMES.get(rule, ""), detail])

# ── V1, V2 ─────────────────────────────────────────────────────────────────

static func _check_key(level: LevelData, problems: Array) -> void:
	if not level.is_inside(level.key_position):
		_fail(problems, "V1", "klíč je mimo level")
		return
	if GridTypes.is_solid(level.block_at(level.key_position)):
		_fail(problems, "V1", "klíč je uvnitř pevného bloku")

static func _check_target(level: LevelData, problems: Array) -> void:
	var count := 0
	for index in level.cell_count():
		if level.blocks[index] == GridTypes.BlockType.TARGET:
			count += 1
	if count != 1:
		_fail(problems, "V2", "cílů je %d, má být právě jeden" % count)

# ── V3, V4, V12, V14 ───────────────────────────────────────────────────────

static func _check_robots(level: LevelData, world: WorldState, problems: Array) -> void:
	var count := level.robots.size()
	if count < 1 or count > GridTypes.ROBOT_COUNT:
		_fail(problems, "V3", "robotů je %d, povoleno 1–7" % count)

	var seen_kinds := {}
	var sequence_indices := {}
	for placement in level.robots:
		if seen_kinds.has(placement.kind):
			_fail(problems, "V3", "robot %s je v levelu víckrát"
					% GridTypes.robot_name(placement.kind))
		seen_kinds[placement.kind] = true
		sequence_indices[placement.sequence_index] = true

		if not level.is_inside(placement.cell):
			_fail(problems, "V4", "robot %s je mimo level"
					% GridTypes.robot_name(placement.kind))
			continue
		if GridTypes.is_solid(level.block_at(placement.cell)):
			_fail(problems, "V4", "robot %s stojí v pevném bloku"
					% GridTypes.robot_name(placement.kind))
		var in_water := world.water_depth_at(placement.cell) != GridTypes.WaterDepth.DRY
		var has_support := GridTypes.is_solid(
				level.block_at(placement.cell + GridTypes.DOWN_VECTOR))
		if not has_support and not (placement.kind == GridTypes.RobotKind.DUL and in_water):
			_fail(problems, "V4", "robot %s nemá pod sebou pevný podklad"
					% GridTypes.robot_name(placement.kind))
		if placement.kind != GridTypes.RobotKind.DUL \
				and world.water_depth_at(placement.cell) == GridTypes.WaterDepth.DEEP:
			_fail(problems, "V14", "robot %s začíná v hluboké vodě"
					% GridTypes.robot_name(placement.kind))

	# V12 — sekvence je úplná permutace 0..n-1
	for i in count:
		if not sequence_indices.has(i):
			_fail(problems, "V12", "v sekvenci chybí pořadí %d" % i)
			break

# ── V5, V6, V7 ─────────────────────────────────────────────────────────────

static func _check_floating(level: LevelData, problems: Array) -> void:
	for index in level.cell_count():
		var block := level.blocks[index]
		if not GridTypes.falls(block):
			continue
		var cell := level.index_to_cell(index)
		var below := cell + GridTypes.DOWN_VECTOR
		var below_block := GridTypes.BlockType.OUTSIDE if not level.is_inside(below) \
				else level.block_at(below)
		if not GridTypes.is_solid(below_block):
			_fail(problems, "V5", "blok na %s visí ve vzduchu" % cell)
	for item in level.items:
		if not level.is_inside(item.cell):
			_fail(problems, "V5", "předmět na %s je mimo level" % item.cell)
			continue
		var below: Vector3i = item.cell + GridTypes.DOWN_VECTOR
		var below_block := GridTypes.BlockType.OUTSIDE if not level.is_inside(below) \
				else level.block_at(below)
		if not GridTypes.is_solid(below_block):
			_fail(problems, "V5", "předmět na %s visí ve vzduchu" % item.cell)

static func _check_ramps(level: LevelData, problems: Array) -> void:
	for index in level.cell_count():
		if level.blocks[index] != GridTypes.BlockType.RAMP:
			continue
		var above := level.index_to_cell(index) + GridTypes.UP_VECTOR
		if not level.is_inside(above):
			continue
		if level.block_at(above) != GridTypes.BlockType.EMPTY:
			_fail(problems, "V6", "na šikmině na %s něco stojí" % above)
		if level.item_at(above) != GridTypes.NO_ITEM:
			_fail(problems, "V6", "na šikmině na %s leží předmět" % above)

static func _check_ice(level: LevelData, world: WorldState, problems: Array) -> void:
	for index in level.cell_count():
		if level.blocks[index] != GridTypes.BlockType.ICE:
			continue
		var cell := level.index_to_cell(index)
		if world.reservoir_at(cell) == -1:
			_fail(problems, "V7", "led na %s není uvnitř nádrže" % cell)

# ── V8, V9 ─────────────────────────────────────────────────────────────────

static func _check_platforms(level: LevelData, problems: Array) -> void:
	for i in level.platforms.size():
		var platform = level.platforms[i]
		if platform.linked_cabinets.is_empty():
			_fail(problems, "V9", "plošina %d nemá elektrickou skříň" % i)
		if platform.cells.is_empty():
			_fail(problems, "V8", "plošina %d nemá žádné buňky" % i)
			continue
		var own_cells := {}
		for cell in platform.cells:
			own_cells[cell + platform.pose_a] = true
			own_cells[cell + platform.pose_b] = true
		for cell in platform.cells:
			for swept in _swept_cells(cell + platform.pose_a, cell + platform.pose_b):
				if not level.is_inside(swept):
					_fail(problems, "V8", "plošina %d by vyjela z levelu" % i)
					continue
				if own_cells.has(swept):
					continue
				if GridTypes.is_solid(level.block_at(swept)):
					_fail(problems, "V8", "v dráze plošiny %d je překážka na %s" % [i, swept])

## Buňky mezi dvěma polohami včetně obou konců. Dráha se vzorkuje po
## největším společném děliteli složek, takže vodorovný, svislý i diagonální
## pohyb dá celočíselné mezikroky.
static func _swept_cells(from: Vector3i, to: Vector3i) -> Array:
	var delta := to - from
	var steps: int = maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.z))
	if steps == 0:
		return [from]
	var out: Array = []
	for i in steps + 1:
		out.append(Vector3i(
			from.x + delta.x * i / steps,
			from.y + delta.y * i / steps,
			from.z + delta.z * i / steps))
	return out

# ── V10, V11, V13 ──────────────────────────────────────────────────────────

static func _check_pumps(level: LevelData, problems: Array) -> void:
	for i in level.pumps.size():
		var pump = level.pumps[i]
		var count := level.reservoirs.size()
		if pump.reservoir_a < 0 or pump.reservoir_a >= count \
				or pump.reservoir_b < 0 or pump.reservoir_b >= count:
			_fail(problems, "V10", "čerpadlo %d odkazuje na neexistující nádrž" % i)
			continue
		if pump.reservoir_a == pump.reservoir_b:
			_fail(problems, "V10", "čerpadlo %d čerpá z nádrže do ní samé" % i)
			continue
		var sources: Array = [pump.default_direction]
		if pump.bidirectional:
			sources = [0, 1]
		for direction in sources:
			var source_index: int = pump.reservoir_a if direction == 0 else pump.reservoir_b
			if level.reservoirs[source_index].unlimited:
				_fail(problems, "V10",
						"čerpadlo %d by čerpalo z neomezené nádrže %d" % [i, source_index])

static func _check_reservoirs(level: LevelData, world: WorldState, problems: Array) -> void:
	for i in level.reservoirs.size():
		var def = level.reservoirs[i]
		if i >= world.reservoirs.size():
			_fail(problems, "V11", "nádrž %d nemá odpovídající dutinu" % i)
			continue
		var res: ReservoirState = world.reservoirs[i]
		if res.cells.is_empty():
			_fail(problems, "V11",
					"kotevní buňka nádrže %d (%s) neleží v uzavřené dutině" % [i, def.anchor])
			continue
		if def.volume_units > res.total_capacity():
			_fail(problems, "V13", "nádrž %d má objem %d > kapacita %d"
					% [i, def.volume_units, res.total_capacity()])
