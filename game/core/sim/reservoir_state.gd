class_name ReservoirState
extends RefCounted

## Zatopená oblast (§9.2). Hladina se NIKDY neukládá jako číslo — je to vždy
## odvozená veličina z `volume_units` a aktuálních kapacit vrstev.

var cells: Array = []              # Vector3i, buňky dutiny
var layer_capacity: Dictionary = {} # y -> součet capacity_units v této vrstvě
var layer_order: Array = []        # seřazené hodnoty y odspodu
var volume_units: int = 0
var unlimited: bool = false
var anchor: Vector3i = Vector3i.ZERO

func total_capacity() -> int:
	var sum := 0
	for y in layer_order:
		sum += int(layer_capacity[y])
	return sum

func has_cell(cell: Vector3i) -> bool:
	return cells.has(cell)

func capacity_of_layer(y: int) -> int:
	return int(layer_capacity.get(y, 0))

## Přepočet kapacit vrstev z aktuálních typů bloků. Kapacita se mění za běhu
## (led vznikne/zmizí, Han vykope díru v mělčině) — §20.5 M8.
func recompute_capacity(blocks_reader: Callable) -> void:
	layer_capacity.clear()
	layer_order.clear()
	for cell in cells:
		var block: int = blocks_reader.call(cell)
		var cap := GridTypes.capacity_units(block)
		layer_capacity[cell.y] = int(layer_capacity.get(cell.y, 0)) + cap
		if not layer_order.has(cell.y):
			layer_order.append(cell.y)
	layer_order.sort()

func duplicate_state() -> ReservoirState:
	var copy := ReservoirState.new()
	copy.cells = cells.duplicate()
	copy.layer_capacity = layer_capacity.duplicate()
	copy.layer_order = layer_order.duplicate()
	copy.volume_units = volume_units
	copy.unlimited = unlimited
	copy.anchor = anchor
	return copy
