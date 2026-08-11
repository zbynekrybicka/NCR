class_name TestWater
extends TestSuite

## §9 — aritmetika hladin, hraniční případy přesně na 1/2 kostky, utonutí,
## neomezená nádrž, flood-fill nádrží. Vše celočíselně (P2).

## Nádrž 3×2 buňky (dvě vrstvy po 3 buňkách, kapacita 6 jednotek na vrstvu).
func _basin(volume: int, unlimited: bool = false, with_robot: bool = false) -> WorldState:
	var interior := "#H..#" if with_robot else "#...#"
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n" + interior + "\n#####") \
		.layer(2, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 1, 1), volume, unlimited) \
		.build()
	return WorldState.from_level(level)

func test_cavity_detection() -> void:
	var world := _basin(0)
	t.equal(world.reservoirs.size(), 1, "jedna nádrž")
	var res: ReservoirState = world.reservoirs[0]
	t.equal(res.cells.size(), 6, "šest buněk dutiny")
	t.equal(res.total_capacity(), 12, "kapacita 12 jednotek")
	t.equal(res.capacity_of_layer(1), 6, "spodní vrstva 6 jednotek")
	t.equal(world.reservoir_at(Vector3i(0, 1, 1)), -1, "zeď do nádrže nepatří")
	t.equal(world.reservoir_at(Vector3i(2, 1, 1)), 0, "vnitřek do nádrže patří")

func test_open_cavity_is_not_a_reservoir() -> void:
	# Bez podlahy voda vyteče ven z levelu → dutina není nádrž (§9.1).
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#...#\n#####") \
		.layer(1, "#####\n#...#\n#####") \
		.reservoir(Vector3i(1, 0, 1), 0) \
		.build()
	var world := WorldState.from_level(level)
	t.equal(world.reservoirs[0].cells.size(), 0, "netěsná dutina není nádrž")

func test_surface_arithmetic() -> void:
	var res: ReservoirState = _basin(3).reservoirs[0]
	var surface := WaterSystem.surface(res)
	t.equal(surface[0], 1, "hladina leží ve spodní vrstvě")
	t.equal(surface[1], 3, "zbytek 3 jednotky z 6")

	res = _basin(6).reservoirs[0]
	surface = WaterSystem.surface(res)
	t.equal(surface[0], 2, "plná spodní vrstva posune hladinu do horní")
	t.equal(surface[1], 0, "žádný zbytek")

	res = _basin(12).reservoirs[0]
	surface = WaterSystem.surface(res)
	t.equal(surface[0], 3, "plná nádrž — hladina až nad okraj")

func test_depth_boundary_exactly_half() -> void:
	# 3 z 6 jednotek = přesně 1/2 kostky → ještě se neutopí (§9.4).
	var world := _basin(3)
	t.equal(world.water_depth_at(Vector3i(1, 1, 1)), GridTypes.WaterDepth.SHALLOW,
			"přesně půl kostky je mělčina")
	world = _basin(4)
	t.equal(world.water_depth_at(Vector3i(1, 1, 1)), GridTypes.WaterDepth.DEEP,
			"o jednotku víc už je hloubka")
	world = _basin(0)
	t.equal(world.water_depth_at(Vector3i(1, 1, 1)), GridTypes.WaterDepth.DRY,
			"prázdná nádrž je suchá")

func test_would_drown() -> void:
	var res: ReservoirState = _basin(3).reservoirs[0]
	t.is_false(WaterSystem.would_drown(res, 1), "přesně půl kostky není utonutí")
	res = _basin(4).reservoirs[0]
	t.is_true(WaterSystem.would_drown(res, 1), "víc než půl kostky je utonutí")
	res = _basin(12).reservoirs[0]
	t.is_true(WaterSystem.would_drown(res, 2),
			"v úplně plné nádrži je i horní vrstva pod hladinou")

func test_raising_water_is_safe_checks_robots() -> void:
	var world := _basin(3, false, true)
	t.equal(world.robots[0].cell, Vector3i(1, 1, 1), "Han stojí v nádrži")
	t.is_true(WaterSystem.raising_water_is_safe(world, 0, 0),
			"beze změny je hladina bezpečná")
	t.is_false(WaterSystem.raising_water_is_safe(world, 0, GridTypes.UNITS_PER_CUBE),
			"o kostku výš by se Han utopil")

func test_full_reservoir_rejects_more_water() -> void:
	var world := _basin(12)
	t.is_false(WaterSystem.raising_water_is_safe(world, 0, GridTypes.UNITS_PER_CUBE),
			"do zcela plné nádrže se nic nevejde")

func test_unlimited_reservoir_never_changes() -> void:
	var world := _basin(4, true)
	var events: Array = []
	WaterSystem.change_volume(world, 0, GridTypes.UNITS_PER_CUBE, events)
	t.equal(world.reservoirs[0].volume_units, 4, "neomezená nádrž objem nemění")
	t.is_true(events.is_empty(), "a nevydává událost o změně hladiny")
	t.is_true(WaterSystem.raising_water_is_safe(world, 0, 99), "vejde se do ní cokoli")
	t.is_true(WaterSystem.fill_ratio_over_half(world.reservoirs[0]),
			"neomezená nádrž je vždy nad polovinou")

func test_fill_ratio_over_half() -> void:
	t.is_false(WaterSystem.fill_ratio_over_half(_basin(6).reservoirs[0]),
			"přesně polovina není víc než polovina")
	t.is_true(WaterSystem.fill_ratio_over_half(_basin(7).reservoirs[0]),
			"o jednotku víc už ano")

func test_capacity_follows_geometry() -> void:
	# Kapacita se mění za běhu — led ubere, roztátí vrátí (§20.5 M8).
	var world := _basin(4)
	world.set_block(Vector3i(1, 1, 1), GridTypes.BlockType.ICE)
	t.equal(world.reservoirs[0].total_capacity(), 10, "led ubral kapacitu 2")
	world.set_block(Vector3i(1, 1, 1), GridTypes.BlockType.EMPTY)
	t.equal(world.reservoirs[0].total_capacity(), 12, "roztátí kapacitu vrátilo")

func test_floating_ice_raft_detection() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "###.") \
		.layer(1, ".#II") \
		.build()
	var world := WorldState.from_level(level)
	# Led na (3,1,0) visí jen na ledu (2,1,0), pod kterým je zeď.
	t.is_true(WaterSystem.would_leave_floating_ice_raft(world, Vector3i(2, 1, 0)),
			"roztavení nosné kostky by nechalo kru na vodě")
	t.is_false(WaterSystem.would_leave_floating_ice_raft(world, Vector3i(3, 1, 0)),
			"roztavení krajní kostky nikoho neodpojí")
