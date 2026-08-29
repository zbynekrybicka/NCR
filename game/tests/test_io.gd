class_name TestIo
extends TestSuite

## §15 — round-trip binárního formátu, přeskočení neznámého chunku,
## odmítnutí špatné CRC a vyšší verze.

func _sample_level() -> LevelData:
	var level := LevelBuilder.new() \
		.layer(0, "#####\n#####\n#####") \
		.layer(1, "#####\n#H.T#\n#####") \
		.layer(2, "#####\n#..f#\n#####") \
		.key(Vector3i(2, 1, 1)) \
		.reservoir(Vector3i(1, 1, 1), 4, true) \
		.device(GridTypes.DeviceKind.CONTROL_UNIT, Vector3i(0, 1, 1),
				GridTypes.Direction.EAST, GridTypes.ControlMode.SWITCH, true) \
		.platform([Vector3i(1, 0, 1), Vector3i(2, 0, 1)], Vector3i.ZERO,
				Vector3i(0, 2, -1), 4, [0], [0]) \
		.pump(0, 0, [0, 2], 1, true, 1) \
		.build()
	level.level_name = "Zkušební level"
	level.author = "Zbyněk"
	level.created_unix = 1770000000
	level.has_intro_camera = true
	level.intro_camera_eye = Vector3(1.5, 4.0, -3.25)
	level.intro_camera_target = Vector3(2.0, 1.0, 1.0)
	level.intro_text = "První odstavec.\n\nDruhý odstavec zprávy."
	return level

func test_round_trip() -> void:
	var level := _sample_level()
	var bytes := LevelWriter.to_bytes(level)
	var result := LevelReader.from_bytes(bytes, false)
	t.is_true(result.ok, "soubor se načetl: " + result.error)
	if not result.ok:
		return
	var back: LevelData = result.level

	t.equal(back.size, level.size, "rozměry")
	t.equal(back.blocks, level.blocks, "bloky (RLE round-trip)")
	t.equal(back.orientations, level.orientations, "orientace")
	t.equal(back.models, level.models, "modely")
	t.equal(back.key_position, level.key_position, "klíč")
	t.equal(back.items.size(), level.items.size(), "počet předmětů")
	t.equal(back.items[0].cell, level.items[0].cell, "pozice předmětu")
	t.equal(back.robots.size(), level.robots.size(), "počet robotů")
	t.equal(back.robots[0].kind, level.robots[0].kind, "druh robota")
	t.equal(back.robots[0].facing, level.robots[0].facing, "natočení robota")
	t.equal(back.reservoirs[0].volume_units, 4, "objem nádrže")
	t.is_true(back.reservoirs[0].unlimited, "příznak neomezené nádrže")
	t.equal(back.devices[0].access_direction, GridTypes.Direction.EAST, "přístupový směr")
	t.is_true(back.devices[0].is_broken, "porucha zařízení")
	t.equal(back.platforms[0].cells.size(), 2, "buňky plošiny")
	t.equal(back.platforms[0].pose_b, Vector3i(0, 2, -1), "záporný offset polohy")
	t.equal(back.pumps[0].linked_control_unit, 1, "vazba čerpadla na řídicí jednotku")
	t.equal(back.pumps[0].linked_cabinets, [0, 2], "seznam skříní čerpadla")
	t.is_true(back.pumps[0].bidirectional, "obousměrnost čerpadla")
	t.equal(back.level_name, "Zkušební level", "název levelu (UTF-8)")
	t.equal(back.author, "Zbyněk", "autor (UTF-8)")
	t.equal(back.created_unix, 1770000000, "čas vytvoření")
	t.is_true(back.has_intro_camera, "příznak úvodní pozice kamery")
	t.equal(back.intro_camera_eye, Vector3(1.5, 4.0, -3.25), "pozice oka úvodní kamery")
	t.equal(back.intro_camera_target, Vector3(2.0, 1.0, 1.0), "cíl pohledu úvodní kamery")
	t.equal(back.intro_text, "První odstavec.\n\nDruhý odstavec zprávy.",
			"úvodní text (odstavce, UTF-8)")

func test_intro_camera_defaults_to_absent() -> void:
	var level := _sample_level()
	level.has_intro_camera = false
	var result := LevelReader.from_bytes(LevelWriter.to_bytes(level), false)
	t.is_true(result.ok, "soubor se načetl: " + result.error)
	t.is_false(result.level.has_intro_camera, "bez uložené pozice se příznak nenastaví")

func test_intro_text_defaults_to_empty() -> void:
	var level := _sample_level()
	level.intro_text = ""
	var result := LevelReader.from_bytes(LevelWriter.to_bytes(level), false)
	t.is_true(result.ok, "soubor se načetl: " + result.error)
	t.equal(result.level.intro_text, "", "bez uloženého textu je pole prázdné")

func test_corrupted_file_is_rejected() -> void:
	var bytes := LevelWriter.to_bytes(_sample_level())
	bytes.encode_u8(20, bytes[20] ^ 0xFF)
	var result := LevelReader.from_bytes(bytes, false)
	t.is_false(result.ok, "poškozený soubor se nenačte")
	t.is_true(result.error.contains("CRC"), "a důvodem je CRC: " + result.error)

func test_newer_format_version_is_rejected() -> void:
	var bytes := LevelWriter.to_bytes(_sample_level())
	bytes.encode_u16(4, LevelData.FORMAT_VERSION + 1)
	# CRC se přepočítá, aby test opravdu ověřoval verzi, ne poškození.
	bytes.encode_u32(bytes.size() - 4, Crc32.compute(bytes.slice(0, bytes.size() - 4)))
	var result := LevelReader.from_bytes(bytes, false)
	t.is_false(result.ok, "soubor z novější verze se odmítne")
	t.is_true(result.error.contains("novější"), "s čitelnou chybou: " + result.error)

func test_unknown_chunk_is_skipped() -> void:
	# Dopředná kompatibilita: neznámý chunk se přeskočí, soubor se načte.
	var level := _sample_level()
	var bytes := LevelWriter.to_bytes(level)
	var body := bytes.slice(0, bytes.size() - 4)

	var extra := StreamPeerBuffer.new()
	extra.put_data("ZZZZ".to_ascii_buffer())
	extra.put_u32(3)
	extra.put_data(PackedByteArray([1, 2, 3]))

	var patched := body + extra.data_array
	patched.encode_u32(8, patched.decode_u32(8) + 1)   # chunk_count + 1
	var footer := StreamPeerBuffer.new()
	footer.put_u32(Crc32.compute(patched))
	var result := LevelReader.from_bytes(patched + footer.data_array, false)
	t.is_true(result.ok, "neznámý chunk se přeskočí: " + result.error)
	t.equal(result.level.size, level.size, "zbytek souboru se přečetl správně")

func test_reader_validates_by_default() -> void:
	var level := LevelBuilder.new() \
		.layer(0, "###") \
		.layer(1, ".H.") \
		.build()   # bez cíle → porušuje V2
	var result := LevelReader.from_bytes(LevelWriter.to_bytes(level))
	t.is_false(result.ok, "nevalidní level se nenačte")
	t.is_false(result.validation_problems.is_empty(), "a řekne proč")

func test_crc32_is_stable() -> void:
	t.equal(Crc32.compute("123456789".to_ascii_buffer()), 0xCBF43926,
			"kontrolní vektor CRC-32/IEEE")
