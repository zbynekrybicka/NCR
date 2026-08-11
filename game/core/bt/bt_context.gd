class_name BTContext
extends RefCounted

## Kontext jednoho vyhodnocení stromu kroku (§7.3).
##
## `mode` drží druh právě probíhající RUNNING smyčky (klouzání po ledu,
## šplhání nahoru, sešplhání dolů). Strom se po každém RUNNING vyhodnocuje
## znovu od kořene z posunuté sondy, takže bez tohoto příznaku by nešlo
## odlišit „pokračuju ve šplhání" od „začínám nový krok" — Net by po
## neúspěšném výlezu spadl do větve sešplhání místo FAIL (§7.6, Net).

const MODE_NONE := ""
const MODE_SLIDE := "slide"
const MODE_CLIMB_UP := "climb_up"
const MODE_CLIMB_DOWN := "climb_down"

var probe: GridProbe
var queue: Array = []          # dílčí kroky (GridTypes.Substep)
var mode: String = MODE_NONE

func _init(p_probe: GridProbe) -> void:
	probe = p_probe

func emit(substep: int) -> void:
	queue.append(substep)
	probe.advance(substep)
