class_name Crc32
extends RefCounted

## CRC-32 (IEEE 802.3, polynom 0xEDB88320) pro patičku souboru levelu (§15).
## Vlastní implementace, aby byl výsledek stejný na všech platformách
## a nezávisel na dostupnosti komprese v enginu.

static var _table: PackedInt64Array = PackedInt64Array()

static func _build_table() -> void:
	if not _table.is_empty():
		return
	_table.resize(256)
	for i in 256:
		var value: int = i
		for _bit in 8:
			if value & 1:
				value = (value >> 1) ^ 0xEDB88320
			else:
				value = value >> 1
		_table[i] = value

static func compute(bytes: PackedByteArray) -> int:
	_build_table()
	var crc: int = 0xFFFFFFFF
	for byte in bytes:
		crc = _table[(crc ^ byte) & 0xFF] ^ (crc >> 8)
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF
