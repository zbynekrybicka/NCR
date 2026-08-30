class_name GridTypes
extends RefCounted

## Enumy a tabulky vlastností mřížky (technický design §4, §5.1, §10, §12).
##
## Vlastnosti typů jsou tabulky, ne `if` (§5.1). Všechno je celočíselné (P2).

# ── Bloky ──────────────────────────────────────────────────────────────────

enum BlockType {
	EMPTY = 0,
	WALL = 1,      # beton/ocel, nepohyblivá, nezničitelná
	RAMP = 2,      # šikmina, objem 1/2 kostky
	DIRT = 3,      # hlína — Han akce 1
	STONE = 4,     # kámen — podléhá gravitaci
	ICE = 5,       # led — jen v nádržích, ukotvený
	WOOD = 6,      # dřevo — spálitelné Setem, podléhá gravitaci
	TARGET = 7,    # cíl
	OUTSIDE = 255, # mimo [0, size) — okraj levelu, §4
}

## Nejvyšší typ, který smí být v souboru levelu (OUTSIDE se nikdy neukládá).
const MAX_STORED_BLOCK := 7

const BLOCK_SOLID := {
	BlockType.EMPTY: false,
	BlockType.WALL: true,
	BlockType.RAMP: true,
	BlockType.DIRT: true,
	BlockType.STONE: true,
	BlockType.ICE: true,
	BlockType.WOOD: true,
	BlockType.TARGET: false,
	BlockType.OUTSIDE: true,
}

const BLOCK_FALLS := {
	BlockType.EMPTY: false,
	BlockType.WALL: false,
	BlockType.RAMP: false,
	BlockType.DIRT: true,
	BlockType.STONE: true,
	BlockType.ICE: false, # led je vždy ukotvený, §5.1 pozn. 1
	BlockType.WOOD: true,
	BlockType.TARGET: false,
	BlockType.OUTSIDE: false,
}

const BLOCK_BURNABLE := {
	BlockType.EMPTY: false,
	BlockType.WALL: false,
	BlockType.RAMP: false,
	BlockType.DIRT: false,
	BlockType.STONE: false,
	BlockType.ICE: true,
	BlockType.WOOD: true,
	BlockType.TARGET: false,
	BlockType.OUTSIDE: false,
}

const BLOCK_DIGGABLE := {
	BlockType.EMPTY: false,
	BlockType.WALL: false,
	BlockType.RAMP: false,
	BlockType.DIRT: true,
	BlockType.STONE: false,
	BlockType.ICE: false,
	BlockType.WOOD: false,
	BlockType.TARGET: false,
	BlockType.OUTSIDE: false,
}

## Kolik půl-kostkových jednotek vody se do buňky vejde (§9.1).
const BLOCK_CAPACITY_UNITS := {
	BlockType.EMPTY: 2,
	BlockType.WALL: 0,
	BlockType.RAMP: 1,
	BlockType.DIRT: 0,
	BlockType.STONE: 0,
	BlockType.ICE: 0,
	BlockType.WOOD: 0,
	BlockType.TARGET: 2,  # cíl na hladině: vodou zaplnitelný stejně jako EMPTY, viz §2.1.5
	BlockType.OUTSIDE: 0,
}

## Jedna kostka = 2 jednotky objemu (§9.1). Plná korba/cisterna = 1 kostka.
const UNITS_PER_CUBE := 2

static func is_solid(block: int) -> bool:
	return bool(BLOCK_SOLID.get(block, true))

static func falls(block: int) -> bool:
	return bool(BLOCK_FALLS.get(block, false))

static func is_burnable(block: int) -> bool:
	return bool(BLOCK_BURNABLE.get(block, false))

static func is_diggable(block: int) -> bool:
	return bool(BLOCK_DIGGABLE.get(block, false))

static func capacity_units(block: int) -> int:
	return int(BLOCK_CAPACITY_UNITS.get(block, 0))

## Buňka, kterou voda smí zaplnit (aspoň zčásti) — používá identifikace nádrží.
static func holds_water(block: int) -> bool:
	return capacity_units(block) > 0 or block == BlockType.ICE

# ── Směry ──────────────────────────────────────────────────────────────────

enum Direction { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3, UP = 4, DOWN = 5 }

const DIR_VECTOR := {
	Direction.NORTH: Vector3i(0, 0, -1), # Godot forward = -Z
	Direction.EAST: Vector3i(1, 0, 0),
	Direction.SOUTH: Vector3i(0, 0, 1),
	Direction.WEST: Vector3i(-1, 0, 0),
	Direction.UP: Vector3i(0, 1, 0),
	Direction.DOWN: Vector3i(0, -1, 0),
}

const UP_VECTOR := Vector3i(0, 1, 0)
const DOWN_VECTOR := Vector3i(0, -1, 0)

## Vodorovné směry v pořadí enumu — deterministický průchod okolí.
const HORIZONTAL_DIRS := [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]

static func dir_vector(dir: int) -> Vector3i:
	return DIR_VECTOR.get(dir, Vector3i.ZERO)

static func turn_left(dir: int) -> int:
	return (dir + 3) % 4

static func turn_right(dir: int) -> int:
	return (dir + 1) % 4

static func turn_around(dir: int) -> int:
	return (dir + 2) % 4

static func is_horizontal(dir: int) -> bool:
	return dir >= 0 and dir < 4

# ── Dílčí kroky (§7.1) ─────────────────────────────────────────────────────

enum Substep {
	DOWN_VERTICAL = -2,
	DOWN_RAMP = -1,
	FORWARD = 0,
	UP_RAMP = 1,
	UP_VERTICAL = 2,
}

## Posun pro robota s orientací `facing` (§7.1).
static func substep_delta(substep: int, facing: int) -> Vector3i:
	var f := dir_vector(facing)
	match substep:
		Substep.FORWARD:
			return f
		Substep.UP_RAMP:
			return f + UP_VECTOR
		Substep.UP_VERTICAL:
			return UP_VECTOR
		Substep.DOWN_RAMP:
			return f + DOWN_VECTOR
		Substep.DOWN_VERTICAL:
			return DOWN_VECTOR
	return Vector3i.ZERO

# ── Voda (§9.5) ────────────────────────────────────────────────────────────

enum WaterDepth { DRY = 0, SHALLOW = 1, DEEP = 2 }

# ── Předměty (§12) ─────────────────────────────────────────────────────────

enum ItemType { FUEL = 0, SERVICE_KIT = 1 }

const NO_ITEM := -1

# ── Roboti (§10) ───────────────────────────────────────────────────────────

enum RobotKind { HAN = 0, DUL = 1, SET = 2, NET = 3, DA = 4, YEO = 5, IL = 6 }

const ROBOT_COUNT := 7

const ROBOT_MASS := {
	RobotKind.HAN: 2,
	RobotKind.DUL: 2,
	RobotKind.SET: 2,
	RobotKind.NET: 2,
	RobotKind.DA: 1,
	RobotKind.YEO: 2,
	RobotKind.IL: 2,
}

const ROBOT_INVENTORY_CAPACITY := {
	RobotKind.HAN: 4,
	RobotKind.DUL: 4,
	RobotKind.SET: 4,
	RobotKind.NET: 4,
	RobotKind.DA: 1,
	RobotKind.YEO: 4,
	RobotKind.IL: 4,
}

## Kdo smí sbírat který předmět (§12). Ostatním je předmět překážkou.
const ITEM_PICKERS := {
	ItemType.FUEL: [RobotKind.SET, RobotKind.NET, RobotKind.DA, RobotKind.YEO],
	ItemType.SERVICE_KIT: [RobotKind.NET, RobotKind.DA, RobotKind.IL],
}

const ROBOT_NAMES := {
	RobotKind.HAN: "Han",
	RobotKind.DUL: "Dul",
	RobotKind.SET: "Set",
	RobotKind.NET: "Net",
	RobotKind.DA: "Da",
	RobotKind.YEO: "Yeo",
	RobotKind.IL: "Il",
}

static func robot_mass(kind: int) -> int:
	return int(ROBOT_MASS.get(kind, 0))

static func inventory_capacity(kind: int) -> int:
	return int(ROBOT_INVENTORY_CAPACITY.get(kind, 0))

static func can_pick_up(kind: int, item: int) -> bool:
	var pickers: Array = ITEM_PICKERS.get(item, [])
	return pickers.has(kind)

## Jediný robot, který smí do hluboké vody (§10).
static func can_enter_deep_water(kind: int) -> bool:
	return kind == RobotKind.DUL

## Da do vody nesmí vůbec (§10).
static func can_enter_water(kind: int) -> bool:
	return kind != RobotKind.DA

static func robot_name(kind: int) -> String:
	return String(ROBOT_NAMES.get(kind, "?"))

# ── Zařízení (§13) ─────────────────────────────────────────────────────────

enum DeviceKind { POWER_CABINET = 0, CONTROL_UNIT = 1 }
enum ControlMode { BUTTON = 0, SWITCH = 1 }

# ── Behavior tree (§7.3) ───────────────────────────────────────────────────

enum BTStatus { SUCCESS, FAIL, RUNNING }

## Tvrdé stropy proti zacyklení (§6.2, §7.3).
const MAX_STEP_ITERATIONS := 128
const MAX_SETTLE_ITERATIONS := 256
