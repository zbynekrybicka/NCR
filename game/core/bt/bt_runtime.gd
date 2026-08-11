class_name BTRuntime
extends RefCounted

## Interpret stromu (§7.3, §7.4). Strom je data (P7) — vnořené slovníky
## načtené ze souboru, ne rozvětvený GDScript.
##
## Sémantika uzlů:
##   Sequence — děti postupně; první FAIL → FAIL; první RUNNING → RUNNING
##   Selector — děti postupně; první SUCCESS → SUCCESS; první RUNNING → RUNNING
##   Inverter — prohodí SUCCESS/FAIL, RUNNING propustí
##   Condition — dotaz na sondu, nemutuje
##   Emit — přidá dílčí krok do fronty, posune sondu, vrátí SUCCESS
##   EmitAndContinue — totéž, ale vrátí RUNNING (a nastaví režim smyčky)

static func tick(node: Dictionary, ctx: BTContext) -> int:
	var type_name := String(node.get("type", ""))
	match type_name:
		"sequence":
			for child in node.get("children", []):
				var status := tick(child, ctx)
				if status != GridTypes.BTStatus.SUCCESS:
					return status
			return GridTypes.BTStatus.SUCCESS
		"selector":
			for child in node.get("children", []):
				var status := tick(child, ctx)
				if status != GridTypes.BTStatus.FAIL:
					return status
			return GridTypes.BTStatus.FAIL
		"inverter":
			var status := tick(node.get("child", {}), ctx)
			if status == GridTypes.BTStatus.SUCCESS:
				return GridTypes.BTStatus.FAIL
			if status == GridTypes.BTStatus.FAIL:
				return GridTypes.BTStatus.SUCCESS
			return status
		"condition":
			var expected := bool(node.get("expect", true))
			var value := BTNodes.evaluate(String(node.get("predicate", "")), ctx,
					node.get("arg", null))
			return GridTypes.BTStatus.SUCCESS if value == expected else GridTypes.BTStatus.FAIL
		"emit":
			ctx.emit(int(node.get("substep", 0)))
			return GridTypes.BTStatus.SUCCESS
		"emit_continue":
			ctx.mode = String(node.get("mode", BTContext.MODE_NONE))
			ctx.emit(int(node.get("substep", 0)))
			return GridTypes.BTStatus.RUNNING
		"succeed":
			return GridTypes.BTStatus.SUCCESS
		"fail":
			return GridTypes.BTStatus.FAIL
	push_error("Neznámý typ uzlu ve stromě: %s" % type_name)
	return GridTypes.BTStatus.FAIL

## Statická kontrola tvaru stromu — používá ji test souborů stromů (§18).
static func validate_tree(node: Variant, problems: Array, path: String = "root") -> void:
	if not (node is Dictionary):
		problems.append("%s: uzel není slovník" % path)
		return
	var type_name := String(node.get("type", ""))
	if not BTNodes.is_known_node_type(type_name):
		problems.append("%s: neznámý typ uzlu '%s'" % [path, type_name])
		return
	match type_name:
		"sequence", "selector":
			var children: Array = node.get("children", [])
			if children.is_empty():
				problems.append("%s: %s bez dětí" % [path, type_name])
			for i in children.size():
				validate_tree(children[i], problems, "%s/%s[%d]" % [path, type_name, i])
		"inverter":
			validate_tree(node.get("child", null), problems, path + "/inverter")
		"condition":
			var predicate := String(node.get("predicate", ""))
			if not BTNodes.has_predicate(predicate):
				problems.append("%s: neznámý predikát '%s'" % [path, predicate])
		"emit", "emit_continue":
			var substep := int(node.get("substep", 99))
			if not [-2, -1, 0, 1, 2].has(substep):
				problems.append("%s: neplatný dílčí krok %d" % [path, substep])
