class_name LevelReader
extends RefCounted

## Binární formát → LevelData (§15).
##
## Pravidla čtečky:
##  - neznámý chunk_id se přeskočí (dopředná kompatibilita),
##  - vyšší format_version → odmítnutí s čitelnou chybou,
##  - nesedící crc32 → odmítnutí (poškozený soubor),
##  - po načtení běží validace levelu (§16.2); nevalidní soubor se nenačte.

class ReadResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var level: LevelData = null
	var validation_problems: Array = []

	func _init(p_ok: bool = false, p_error: String = "") -> void:
		ok = p_ok
		error = p_error


static func from_bytes(bytes: PackedByteArray, validate: bool = true) -> ReadResult:
	if bytes.size() < 16:
		return ReadResult.new(false, "soubor je příliš krátký")

	var body := bytes.slice(0, bytes.size() - 4)
	var stored_crc := bytes.slice(bytes.size() - 4).decode_u32(0)
	if Crc32.compute(body) != stored_crc:
		return ReadResult.new(false, "poškozený soubor (nesedí CRC-32)")

	var stream := StreamPeerBuffer.new()
	stream.data_array = body
	stream.seek(0)

	var magic := stream.get_string(4)
	if magic != LevelWriter.MAGIC:
		return ReadResult.new(false, "tohle není soubor levelu NCR")
	var version := stream.get_u16()
	if version > LevelData.FORMAT_VERSION:
		return ReadResult.new(false,
				"soubor je z novější verze hry (formát %d, podporovaný %d)"
				% [version, LevelData.FORMAT_VERSION])
	stream.get_u16() # flags, rezerva
	var chunk_count := stream.get_u32()

	var level := LevelData.new()
	level.format_version = version

	for _i in chunk_count:
		if stream.get_available_bytes() < 8:
			return ReadResult.new(false, "soubor končí uprostřed chunku")
		var chunk_id := stream.get_string(4)
		var length := stream.get_u32()
		if stream.get_available_bytes() < length:
			return ReadResult.new(false, "chunk %s přesahuje konec souboru" % chunk_id)
		var payload := stream.get_data(length)[1] as PackedByteArray
		var error := _read_chunk(level, chunk_id, payload)
		if error != "":
			return ReadResult.new(false, error)

	var result := ReadResult.new(true, "")
	result.level = level
	if validate:
		result.validation_problems = LevelValidator.validate(level)
		if not result.validation_problems.is_empty():
			result.ok = false
			result.error = "nevalidní level: %s" % ", ".join(result.validation_problems)
	return result

static func load_from_file(path: String, validate: bool = true) -> ReadResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ReadResult.new(false, "soubor nelze otevřít: %s" % path)
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return from_bytes(bytes, validate)

# ── Jednotlivé chunky ──────────────────────────────────────────────────────

static func _read_chunk(level: LevelData, chunk_id: String, payload: PackedByteArray) -> String:
	var stream := StreamPeerBuffer.new()
	stream.data_array = payload
	stream.seek(0)
	match chunk_id:
		"DIMS":
			var size := Vector3i(stream.get_u16(), stream.get_u16(), stream.get_u16())
			if size.x <= 0 or size.y <= 0 or size.z <= 0:
				return "level má nulový rozměr"
			var prepared := LevelData.create_empty(size)
			level.size = prepared.size
			level.blocks = prepared.blocks
			level.models = prepared.models
			level.orientations = prepared.orientations
		"BLKS":
			if level.cell_count() == 0:
				return "chunk BLKS přišel dřív než DIMS"
			var index := 0
			var count := level.cell_count()
			while stream.get_available_bytes() >= 6:
				var block := stream.get_u8()
				var model := stream.get_u16()
				var orientation := stream.get_u8()
				var run := stream.get_u16()
				if block > GridTypes.MAX_STORED_BLOCK:
					return "neznámý typ bloku %d" % block
				for _r in run:
					if index >= count:
						return "BLKS obsahuje víc buněk, než je level velký"
					level.blocks[index] = block
					level.models[index] = model
					level.orientations[index] = orientation
					index += 1
			if index != count:
				return "BLKS nepokrývá celý level (%d z %d)" % [index, count]
		"ITEM":
			var count := stream.get_u16()
			for _i in count:
				var item_type := stream.get_u8()
				level.items.append(LevelData.ItemPlacement.new(item_type, _get_cell(stream)))
		"KEY ":
			level.key_position = _get_cell(stream)
		"ROBO":
			var count := stream.get_u8()
			for _i in count:
				var kind := stream.get_u8()
				var cell := _get_cell(stream)
				var facing := stream.get_u8()
				var sequence_index := stream.get_u8()
				level.robots.append(
						LevelData.RobotPlacement.new(kind, cell, facing, sequence_index))
		"RESV":
			var count := stream.get_u16()
			for _i in count:
				var anchor := _get_cell(stream)
				var volume := stream.get_u32()
				var unlimited := stream.get_u8() != 0
				level.reservoirs.append(
						LevelData.ReservoirDef.new(anchor, volume, unlimited))
		"DEVC":
			var count := stream.get_u16()
			for _i in count:
				var kind := stream.get_u8()
				var control_mode := stream.get_u8()
				var cell := _get_cell(stream)
				var access := stream.get_u8()
				var broken := stream.get_u8() != 0
				level.devices.append(
						LevelData.DeviceDef.new(kind, control_mode, cell, access, broken))
		"PLAT":
			var count := stream.get_u16()
			for _i in count:
				var platform := LevelData.PlatformDef.new()
				var cell_count := stream.get_u16()
				for _c in cell_count:
					platform.cells.append(_get_cell(stream))
				platform.pose_a = _get_offset(stream)
				platform.pose_b = _get_offset(stream)
				platform.weight_limit = stream.get_u16()
				var cabinets := stream.get_u16()
				for _c in cabinets:
					platform.linked_cabinets.append(stream.get_u16())
				var units := stream.get_u16()
				for _u in units:
					platform.linked_control_units.append(stream.get_u16())
				level.platforms.append(platform)
		"PUMP":
			var count := stream.get_u16()
			for _i in count:
				var pump := LevelData.PumpDef.new()
				pump.reservoir_a = stream.get_u16()
				pump.reservoir_b = stream.get_u16()
				pump.bidirectional = stream.get_u8() != 0
				pump.default_direction = stream.get_u8()
				var pump_cabinets := stream.get_u16()
				for _c in pump_cabinets:
					pump.linked_cabinets.append(stream.get_u16())
				pump.linked_control_unit = stream.get_16()
				level.pumps.append(pump)
		"META":
			level.level_name = _get_string(stream)
			level.author = _get_string(stream)
			level.created_unix = stream.get_u32()
		"ICAM":
			level.has_intro_camera = stream.get_u8() != 0
			if level.has_intro_camera:
				level.intro_camera_eye = _get_vector3(stream)
				level.intro_camera_target = _get_vector3(stream)
		"DESC":
			level.intro_text = _get_string(stream)
		_:
			pass # neznámý chunk se přeskočí — dopředná kompatibilita
	return ""

static func _get_vector3(stream: StreamPeerBuffer) -> Vector3:
	return Vector3(stream.get_float(), stream.get_float(), stream.get_float())

static func _get_cell(stream: StreamPeerBuffer) -> Vector3i:
	return Vector3i(stream.get_u16(), stream.get_u16(), stream.get_u16())

static func _get_offset(stream: StreamPeerBuffer) -> Vector3i:
	return Vector3i(stream.get_16(), stream.get_16(), stream.get_16())

static func _get_string(stream: StreamPeerBuffer) -> String:
	var length := stream.get_u16()
	if length == 0:
		return ""
	var bytes := stream.get_data(length)[1] as PackedByteArray
	return bytes.get_string_from_utf8()
