class_name Event
extends RefCounted

## Neměnný popis toho, co se stalo (§6.3). Pořadí událostí v poli je pořadí,
## ve kterém se staly, a je závazné pro přehrání animace (P8).

enum EventType {
	# Pohyb a stav robota
	ROBOT_MOVED,
	ROBOT_TURNED,
	ROBOT_ENTERED_TARGET,
	ACTIVE_ROBOT_CHANGED,
	# Svět
	BLOCK_REMOVED,
	BLOCK_PLACED,
	BLOCK_FELL,
	ITEM_PICKED_UP,
	ITEM_DROPPED,
	KEY_PICKED_UP,
	TARGET_UNLOCKED,
	# Voda
	WATER_VOLUME_CHANGED,
	ICE_MELTED,
	# Zařízení
	DEVICE_REPAIRED,
	DEVICE_CONTROL_TAKEN,
	DEVICE_CONTROL_RELEASED,
	PLATFORM_MOVED,
	PUMP_TRANSFERRED,
	# Řízení
	COMMAND_REJECTED,
	LEVEL_COMPLETED,
	LEVEL_RESTARTED,
}

var type: int
var data: Dictionary

func _init(p_type: int, p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data

func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)

func type_name() -> String:
	return EventType.keys()[type]

func _to_string() -> String:
	return "%s%s" % [type_name(), data]

# ── Továrny ────────────────────────────────────────────────────────────────

static func robot_moved(robot: int, from: Vector3i, to: Vector3i, substep: int) -> Event:
	return Event.new(EventType.ROBOT_MOVED,
			{"robot": robot, "from": from, "to": to, "substep": substep})

static func robot_turned(robot: int, from_dir: int, to_dir: int) -> Event:
	return Event.new(EventType.ROBOT_TURNED,
			{"robot": robot, "from_dir": from_dir, "to_dir": to_dir})

static func robot_entered_target(robot: int, cell: Vector3i) -> Event:
	return Event.new(EventType.ROBOT_ENTERED_TARGET, {"robot": robot, "cell": cell})

static func active_robot_changed(from: int, to: int) -> Event:
	return Event.new(EventType.ACTIVE_ROBOT_CHANGED, {"from": from, "to": to})

static func block_removed(cell: Vector3i, block: int) -> Event:
	return Event.new(EventType.BLOCK_REMOVED, {"cell": cell, "block": block})

static func block_placed(cell: Vector3i, block: int) -> Event:
	return Event.new(EventType.BLOCK_PLACED, {"cell": cell, "block": block})

static func block_fell(from: Vector3i, to: Vector3i, block: int) -> Event:
	return Event.new(EventType.BLOCK_FELL, {"from": from, "to": to, "block": block})

static func item_picked_up(robot: int, item: int, cell: Vector3i) -> Event:
	return Event.new(EventType.ITEM_PICKED_UP, {"robot": robot, "item": item, "cell": cell})

static func item_dropped(robot: int, item: int, cell: Vector3i) -> Event:
	return Event.new(EventType.ITEM_DROPPED, {"robot": robot, "item": item, "cell": cell})

static func key_picked_up(robot: int, cell: Vector3i) -> Event:
	return Event.new(EventType.KEY_PICKED_UP, {"robot": robot, "cell": cell})

static func target_unlocked() -> Event:
	return Event.new(EventType.TARGET_UNLOCKED, {})

static func water_volume_changed(reservoir: int, old_units: int, new_units: int) -> Event:
	return Event.new(EventType.WATER_VOLUME_CHANGED,
			{"reservoir": reservoir, "old_units": old_units, "new_units": new_units})

static func ice_melted(cell: Vector3i, reservoir: int) -> Event:
	return Event.new(EventType.ICE_MELTED, {"cell": cell, "reservoir": reservoir})

static func device_repaired(device: int) -> Event:
	return Event.new(EventType.DEVICE_REPAIRED, {"device": device})

static func device_control_taken(robot: int, device: int) -> Event:
	return Event.new(EventType.DEVICE_CONTROL_TAKEN, {"robot": robot, "device": device})

static func device_control_released(robot: int, device: int) -> Event:
	return Event.new(EventType.DEVICE_CONTROL_RELEASED, {"robot": robot, "device": device})

static func platform_moved(platform: int, from_offset: Vector3i, to_offset: Vector3i) -> Event:
	return Event.new(EventType.PLATFORM_MOVED,
			{"platform": platform, "from_offset": from_offset, "to_offset": to_offset})

static func pump_transferred(pump: int, from_reservoir: int, to_reservoir: int,
		units: int) -> Event:
	return Event.new(EventType.PUMP_TRANSFERRED,
			{"pump": pump, "from": from_reservoir, "to": to_reservoir, "units": units})

static func command_rejected(command_type: int, reason: String) -> Event:
	return Event.new(EventType.COMMAND_REJECTED, {"command": command_type, "reason": reason})

static func level_completed() -> Event:
	return Event.new(EventType.LEVEL_COMPLETED, {})

static func level_restarted() -> Event:
	return Event.new(EventType.LEVEL_RESTARTED, {})
