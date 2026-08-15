class_name LevelWriter
extends RefCounted

## LevelData → binární formát (§15). Little-endian, chunkovaná struktura
## (TLV), aby šlo přidávat data bez rozbití starých souborů.

const MAGIC := "NCRL"

static func to_bytes(level: LevelData) -> PackedByteArray:
	var chunks: Array = []
	chunks.append(["DIMS", _chunk_dims(level)])
	chunks.append(["BLKS", _chunk_blocks(level)])
	chunks.append(["ITEM", _chunk_items(level)])
	chunks.append(["KEY ", _chunk_key(level)])
	chunks.append(["ROBO", _chunk_robots(level)])
	chunks.append(["RESV", _chunk_reservoirs(level)])
	chunks.append(["DEVC", _chunk_devices(level)])
	chunks.append(["PLAT", _chunk_platforms(level)])
	chunks.append(["PUMP", _chunk_pumps(level)])
	chunks.append(["META", _chunk_meta(level)])

	var stream := StreamPeerBuffer.new()
	stream.put_data(MAGIC.to_ascii_buffer())
	stream.put_u16(LevelData.FORMAT_VERSION)
	stream.put_u16(0) # flags, rezerva
	stream.put_u32(chunks.size())
	for chunk in chunks:
		var payload: PackedByteArray = chunk[1]
		stream.put_data(String(chunk[0]).to_ascii_buffer())
		stream.put_u32(payload.size())
		stream.put_data(payload)

	var body := stream.data_array
	var footer := StreamPeerBuffer.new()
	footer.put_u32(Crc32.compute(body))
	return body + footer.data_array

static func save_to_file(level: LevelData, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(to_bytes(level))
	file.close()
	return OK

# ── Jednotlivé chunky ──────────────────────────────────────────────────────

static func _chunk_dims(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.size.x)
	stream.put_u16(level.size.y)
	stream.put_u16(level.size.z)
	return stream.data_array

## RLE v iteračním pořadí §4: opakovaně (u8 typ, u16 model, u8 orientace,
## u16 délka běhu).
static func _chunk_blocks(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	var count := level.cell_count()
	var index := 0
	while index < count:
		var block := level.blocks[index]
		var model := level.models[index]
		var orientation := level.orientations[index]
		var run := 1
		while index + run < count and run < 0xFFFF \
				and level.blocks[index + run] == block \
				and level.models[index + run] == model \
				and level.orientations[index + run] == orientation:
			run += 1
		stream.put_u8(block)
		stream.put_u16(model)
		stream.put_u8(orientation)
		stream.put_u16(run)
		index += run
	return stream.data_array

static func _chunk_items(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.items.size())
	for item in level.items:
		stream.put_u8(item.item_type)
		_put_cell(stream, item.cell)
	return stream.data_array

static func _chunk_key(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	_put_cell(stream, level.key_position)
	return stream.data_array

static func _chunk_robots(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u8(level.robots.size())
	for robot in level.robots:
		stream.put_u8(robot.kind)
		_put_cell(stream, robot.cell)
		stream.put_u8(robot.facing)
		stream.put_u8(robot.sequence_index)
	return stream.data_array

static func _chunk_reservoirs(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.reservoirs.size())
	for res in level.reservoirs:
		_put_cell(stream, res.anchor)
		stream.put_u32(res.volume_units)
		stream.put_u8(1 if res.unlimited else 0)
	return stream.data_array

static func _chunk_devices(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.devices.size())
	for device in level.devices:
		stream.put_u8(device.kind)
		stream.put_u8(device.control_mode)
		_put_cell(stream, device.cell)
		stream.put_u8(device.access_direction)
		stream.put_u8(1 if device.is_broken else 0)
	return stream.data_array

static func _chunk_platforms(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.platforms.size())
	for platform in level.platforms:
		stream.put_u16(platform.cells.size())
		for cell in platform.cells:
			_put_cell(stream, cell)
		_put_offset(stream, platform.pose_a)
		_put_offset(stream, platform.pose_b)
		stream.put_u16(platform.weight_limit)
		stream.put_u16(platform.linked_cabinets.size())
		for index in platform.linked_cabinets:
			stream.put_u16(index)
		stream.put_u16(platform.linked_control_units.size())
		for index in platform.linked_control_units:
			stream.put_u16(index)
	return stream.data_array

static func _chunk_pumps(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.put_u16(level.pumps.size())
	for pump in level.pumps:
		stream.put_u16(pump.reservoir_a)
		stream.put_u16(pump.reservoir_b)
		stream.put_u8(1 if pump.bidirectional else 0)
		stream.put_u8(pump.default_direction)
		stream.put_u16(pump.linked_cabinets.size())
		for index in pump.linked_cabinets:
			stream.put_u16(index)
		stream.put_16(pump.linked_control_unit)
	return stream.data_array

static func _chunk_meta(level: LevelData) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	_put_string(stream, level.level_name)
	_put_string(stream, level.author)
	stream.put_u32(level.created_unix)
	return stream.data_array

static func _put_cell(stream: StreamPeerBuffer, cell: Vector3i) -> void:
	stream.put_u16(cell.x)
	stream.put_u16(cell.y)
	stream.put_u16(cell.z)

static func _put_offset(stream: StreamPeerBuffer, offset: Vector3i) -> void:
	stream.put_16(offset.x)
	stream.put_16(offset.y)
	stream.put_16(offset.z)

static func _put_string(stream: StreamPeerBuffer, text: String) -> void:
	var bytes := text.to_utf8_buffer()
	stream.put_u16(bytes.size())
	if bytes.size() > 0:
		stream.put_data(bytes)
