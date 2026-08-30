class_name WaterSystem
extends RefCounted

## Vodní systém (§9). Veškerá aritmetika je celočíselná — jednotka je půl
## kostky, porovnání zlomků se dělá křížovým násobením (P2). Žádný `float`.

# ── 9.1 Identifikace nádrží ────────────────────────────────────────────────

## Odvodí nádrže z geometrie a naplní `world.reservoirs` a
## `world.cell_to_reservoir`. Nádrží se stane jen ta dutina, která obsahuje
## kotevní buňku některé definice (§15) — ostatní uzavřené dutiny jsou suché.
static func identify_reservoirs(world: WorldState, defs: Array) -> void:
	var components := find_closed_cavities(world)
	world.reservoirs.clear()
	world.cell_to_reservoir = PackedInt32Array()
	world.cell_to_reservoir.resize(world.cell_count())
	world.cell_to_reservoir.fill(-1)

	# Indexy nádrží musí 1:1 odpovídat pořadí definic — čerpadla na ně
	# odkazují číslem (§15). Nádrž bez dutiny proto vznikne prázdná
	# a nevalidní level ohlásí LevelValidator (V11, §16.2).
	for def in defs:
		var component := _component_containing(components, def.anchor)
		var res := ReservoirState.new()
		res.cells = component
		res.anchor = def.anchor
		res.unlimited = def.unlimited
		res.volume_units = def.volume_units
		var index := world.reservoirs.size()
		world.reservoirs.append(res)
		for cell in component:
			world.cell_to_reservoir[world.cell_index(cell)] = index
		recompute_capacity(world, index)

## Přepočet členství buněk v nádržích po změně geometrie za běhu — Han vykope
## díru v mělčině, Set roztaví led, Yeo zmrazí vodu (§9.1, §9.3, §20.5 M8).
## Objem, kotva i příznak `unlimited` zůstávají; mění se jen tvar a kapacita.
static func reidentify(world: WorldState) -> void:
	if world.reservoirs.is_empty():
		return
	var components := find_closed_cavities(world)
	world.cell_to_reservoir.fill(-1)
	var claimed := {}
	for i in world.reservoirs.size():
		var res: ReservoirState = world.reservoirs[i]
		var component := _component_for_reservoir(components, res)
		if component.is_empty():
			res.cells = []
			res.recompute_capacity(func(cell: Vector3i) -> int: return world.block_at(cell))
			continue
		var key: Vector3i = component[0]
		if claimed.has(key):
			# Dvě nádrže splynuly v jednu dutinu (např. Han prokopal příčku).
			# Voda se slije do nádrže s nižším indexem; druhá zůstane prázdná.
			# Design dokument tenhle případ neřeší — viz hlášení k implementaci.
			var target: ReservoirState = world.reservoirs[claimed[key]]
			if not target.unlimited and not res.unlimited:
				target.volume_units += res.volume_units
			res.volume_units = 0
			res.cells = []
			res.recompute_capacity(func(cell: Vector3i) -> int: return world.block_at(cell))
			continue
		claimed[key] = i
		res.cells = component
		for cell in component:
			world.cell_to_reservoir[world.cell_index(cell)] = i
		res.recompute_capacity(func(cell: Vector3i) -> int: return world.block_at(cell))

## Najde komponentu, do které nádrž patří. Zkusí nejdřív kotvu; ta ale může
## přestat držet vodu, aniž by dutina zanikla (Han vysype korbu přesně na
## kotevní buňku — ta zpevní na hlínu, ale zbytek nádrže zůstává plný vody).
## V tom případě se hledá podle libovolné buňky, kterou nádrž měla předtím.
static func _component_for_reservoir(components: Array, res: ReservoirState) -> Array:
	var component := _component_containing(components, res.anchor)
	if not component.is_empty():
		return component
	for cell in res.cells:
		component = _component_containing(components, cell)
		if not component.is_empty():
			return component
	return []

static func _component_containing(components: Array, cell: Vector3i) -> Array:
	for component in components:
		if component.has(cell):
			return component
	return []

## Vrátí seznam uzavřených dutin (každá jako pole buněk). Dutina je uzavřená,
## když z ní voda nemůže vytéct — tj. žádná její buňka nevede vodorovně ven
## z levelu nebo do jiné, netěsné buňky. Dno levelu (buňka bez sousední buňky
## pod sebou v rámci mřížky) funguje jako plná zeď — nádrž tak nemusí mít
## vlastní dno z kostek, stačí spodní hrana levelu. Boční okraj levelu se
## pro vodu naopak chová jako díra, ne jako zeď — nádrž musí mít vlastní
## boční stěny (§9.1: dutina dotýkající se bočního okraje levelu nebo jinak
## neuzavřené stěny není nádrž).
static func find_closed_cavities(world: WorldState) -> Array:
	var n := world.cell_count()
	var leaky := PackedByteArray()
	leaky.resize(n)
	leaky.fill(0)

	# 1) Semínka: buňka, ze které voda uteče přímo mimo level (vodorovně —
	#    dolů z levelu uniknout nejde, dno levelu je plná zeď).
	var queue: Array = []
	for index in n:
		var cell := world.index_to_cell(index)
		if not _holds_water(world, cell):
			continue
		var escapes := false
		for dir in GridTypes.HORIZONTAL_DIRS:
			if not world.is_inside(cell + GridTypes.dir_vector(dir)):
				escapes = true
				break
		if escapes:
			leaky[index] = 1
			queue.append(cell)

	# 2) Zpětné šíření: netěsná je i každá buňka, která do netěsné vede.
	#    Voda teče vodorovně a dolů → zpětně: vodorovní sousedé a buňka nad.
	while not queue.is_empty():
		var cell: Vector3i = queue.pop_back()
		var sources: Array = []
		for dir in GridTypes.HORIZONTAL_DIRS:
			sources.append(cell + GridTypes.dir_vector(dir))
		sources.append(cell + GridTypes.UP_VECTOR)
		for source in sources:
			if not world.is_inside(source):
				continue
			if not _holds_water(world, source):
				continue
			var si := world.cell_index(source)
			if leaky[si] == 1:
				continue
			leaky[si] = 1
			queue.append(source)

	# 3) Zbylé buňky seskup do komponent (souvislost vodorovná i svislá).
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var components: Array = []
	for index in n:
		if leaky[index] == 1 or seen[index] == 1:
			continue
		var start := world.index_to_cell(index)
		if not _holds_water(world, start):
			continue
		var component: Array = []
		var stack: Array = [start]
		seen[index] = 1
		while not stack.is_empty():
			var cell: Vector3i = stack.pop_back()
			component.append(cell)
			for dir in [GridTypes.Direction.NORTH, GridTypes.Direction.EAST,
					GridTypes.Direction.SOUTH, GridTypes.Direction.WEST,
					GridTypes.Direction.UP, GridTypes.Direction.DOWN]:
				var next := cell + GridTypes.dir_vector(dir)
				if not world.is_inside(next):
					continue
				var ni := world.cell_index(next)
				if seen[ni] == 1 or leaky[ni] == 1:
					continue
				if not _holds_water(world, next):
					continue
				seen[ni] = 1
				stack.append(next)
		component.sort_custom(_cell_order)
		components.append(component)
	return components

static func _cell_order(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x

## Buňka, kterou voda může (aspoň zčásti) zaplnit. Led je členem nádrže
## s nulovou kapacitou, aby ho šlo roztavit zpátky na vodu (§9.3 pozn. 1).
static func _holds_water(world: WorldState, cell: Vector3i) -> bool:
	return GridTypes.holds_water(world.block_at(cell))

# ── 9.2 Reprezentace hladiny ───────────────────────────────────────────────

static func recompute_capacity(world: WorldState, reservoir_index: int) -> void:
	var res: ReservoirState = world.reservoirs[reservoir_index]
	res.recompute_capacity(func(cell: Vector3i) -> int: return world.block_at(cell))

## Vrátí [y_top, remaining]: hladina leží uvnitř vrstvy `y_top` ve zlomkové
## výšce remaining / layer_capacity[y_top].
static func surface(res: ReservoirState) -> Array:
	return surface_for_volume(res, res.volume_units)

## Čistá varianta pro „co by se stalo, kdyby byl objem jiný" — validace
## nikdy nesmí mutovat stav (P5).
static func surface_for_volume(res: ReservoirState, volume_units: int) -> Array:
	if res.layer_order.is_empty():
		return [0, 0]
	var left := volume_units
	for y in res.layer_order:
		var cap := res.capacity_of_layer(y)
		if left < cap:
			return [y, left]
		left -= cap
	return [int(res.layer_order[-1]) + 1, 0]

# ── 9.4 Kontrola utonutí ───────────────────────────────────────────────────

## depth > 1/2 kostky ⟺ 2 * ((y_top - robot_y) * cap + remaining) > cap
static func would_drown(res: ReservoirState, robot_y: int) -> bool:
	return would_drown_at_volume(res, robot_y, res.volume_units)

static func would_drown_at_volume(res: ReservoirState, robot_y: int, volume_units: int) -> bool:
	var s := surface_for_volume(res, volume_units)
	var y_top: int = s[0]
	var remaining: int = s[1]
	var cap := res.capacity_of_layer(y_top)
	if cap <= 0:
		cap = 1
	return 2 * ((y_top - robot_y) * cap + remaining) > cap

## Je bezpečné zvednout hladinu nádrže o `units`? Kontrolují se všichni
## roboti v nádrži kromě Dula (§9.4). Neomezená nádrž hladinu nemění.
static func raising_water_is_safe(world: WorldState, reservoir_index: int, units: int) -> bool:
	if reservoir_index < 0 or reservoir_index >= world.reservoirs.size():
		return false
	var res: ReservoirState = world.reservoirs[reservoir_index]
	if res.unlimited:
		return true
	var new_volume := res.volume_units + units
	if new_volume > res.total_capacity():
		return false # do zcela plné nádrže se už nic nevejde (§9.3 pozn. 3)
	for i in world.robots.size():
		var robot: RobotState = world.robots[i]
		if robot.in_target:
			continue
		if robot.kind == GridTypes.RobotKind.DUL:
			continue
		if not res.has_cell(robot.cell):
			continue
		if would_drown_at_volume(res, robot.cell.y, new_volume):
			return false
	return true

## Je v nádrži dost vody na odebrání `units`?
static func lowering_water_is_possible(world: WorldState, reservoir_index: int, units: int) -> bool:
	if reservoir_index < 0 or reservoir_index >= world.reservoirs.size():
		return false
	var res: ReservoirState = world.reservoirs[reservoir_index]
	if res.unlimited:
		return true
	return res.volume_units >= units

## Změna objemu + událost. Neomezená nádrž hladinu nikdy nemění (§13.3).
static func change_volume(world: WorldState, reservoir_index: int, delta: int,
		out_events: Array) -> void:
	var res: ReservoirState = world.reservoirs[reservoir_index]
	if res.unlimited or delta == 0:
		return
	var old_units := res.volume_units
	res.volume_units = maxi(0, res.volume_units + delta)
	out_events.append(Event.water_volume_changed(reservoir_index, old_units, res.volume_units))

# ── 9.5 Hloubka pro pohyb ──────────────────────────────────────────────────

static func depth_at(world: WorldState, cell: Vector3i) -> int:
	var reservoir_index := world.reservoir_at(cell)
	if reservoir_index == -1:
		return GridTypes.WaterDepth.DRY
	var res: ReservoirState = world.reservoirs[reservoir_index]
	var s := surface(res)
	var y_top: int = s[0]
	var remaining: int = s[1]
	if cell.y > y_top:
		return GridTypes.WaterDepth.DRY
	if cell.y == y_top and remaining <= 0:
		return GridTypes.WaterDepth.DRY
	if would_drown(res, cell.y):
		return GridTypes.WaterDepth.DEEP
	return GridTypes.WaterDepth.SHALLOW

static func has_water_at(world: WorldState, cell: Vector3i) -> bool:
	return depth_at(world, cell) != GridTypes.WaterDepth.DRY

## Poměr zaplnění nádrže > 1/2 — celočíselně (Dul akce 1 ze břehu, Yeo akce 1).
static func fill_ratio_over_half(res: ReservoirState) -> bool:
	if res.unlimited:
		return true
	return 2 * res.volume_units > res.total_capacity()

# ── Plovoucí kra (§11, Set akce 1) ─────────────────────────────────────────

## Vrátí true, pokud by roztavení `cell` zanechalo led bez spojení s pevným
## podkladem. BFS nad grafem sousedících ICE buněk až po pevný podklad.
static func would_leave_floating_ice_raft(world: WorldState, melted: Vector3i) -> bool:
	var neighbours := [
		GridTypes.Direction.NORTH, GridTypes.Direction.EAST, GridTypes.Direction.SOUTH,
		GridTypes.Direction.WEST, GridTypes.Direction.UP, GridTypes.Direction.DOWN,
	]
	# Každá kostka ledu sousedící s roztávanou musí mít po roztátí cestu
	# ledem k pevnému (neledovému) podkladu.
	for dir in neighbours:
		var start := melted + GridTypes.dir_vector(dir)
		if world.block_at(start) != GridTypes.BlockType.ICE:
			continue
		if not _ice_group_is_anchored(world, start, melted):
			return true
	return false

static func _ice_group_is_anchored(world: WorldState, start: Vector3i, ignored: Vector3i) -> bool:
	var seen := {start: true}
	var stack: Array = [start]
	var neighbours := [
		GridTypes.Direction.NORTH, GridTypes.Direction.EAST, GridTypes.Direction.SOUTH,
		GridTypes.Direction.WEST, GridTypes.Direction.UP, GridTypes.Direction.DOWN,
	]
	while not stack.is_empty():
		var cell: Vector3i = stack.pop_back()
		var below := cell + GridTypes.DOWN_VECTOR
		var below_block := world.block_at(below)
		if below != ignored and below_block != GridTypes.BlockType.ICE \
				and GridTypes.is_solid(below_block):
			return true # kotva na pevném podkladu
		for dir in neighbours:
			var next := cell + GridTypes.dir_vector(dir)
			if next == ignored or seen.has(next):
				continue
			if world.block_at(next) != GridTypes.BlockType.ICE:
				continue
			seen[next] = true
			stack.append(next)
	return false
