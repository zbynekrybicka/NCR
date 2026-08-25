# Nature Cybernetic Robots — Technický design

Zbyněk Rybička, 2026 · Godot 4.x / GDScript

> **Vztah k design dokumentu.** [design-document.md](design-document.md) je **zdroj pravdy pro pravidla hry**. Tento dokument je zdroj pravdy pro **to, jak se ta pravidla implementují**. Kde se oba dokumenty rozejdou v otázce *co hra dělá*, vyhrává design dokument a technický design se opraví.
>
> **Stav dokumentu.** Živý, doplňuje se souběžně s vývojem.

## Obsah

1. [Účel a rozsah](#1-účel-a-rozsah)
2. [Architektonické principy](#2-architektonické-principy)
3. [Vrstvy a mapa modulů](#3-vrstvy-a-mapa-modulů)
4. [Souřadný systém a konvence mřížky](#4-souřadný-systém-a-konvence-mřížky)
5. [Datový model](#5-datový-model)
6. [Simulační jádro: tah, příkazy, události](#6-simulační-jádro-tah-příkazy-události)
7. [Pohyb: behavior tree a fronta dílčích kroků](#7-pohyb-behavior-tree-a-fronta-dílčích-kroků)
8. [Gravitace a usazování](#8-gravitace-a-usazování)
9. [Vodní systém](#9-vodní-systém)
10. [Specifikace robotů](#10-specifikace-robotů)
11. [Akce](#11-akce)
12. [Inventář a předměty](#12-inventář-a-předměty)
13. [Elektrická zařízení, plošiny, čerpadla](#13-elektrická-zařízení-plošiny-čerpadla)
14. [Klíč, cíl, ukončení levelu](#14-klíč-cíl-ukončení-levelu)
15. [Formát uložení levelu](#15-formát-uložení-levelu)
16. [Editor](#16-editor)
17. [Prezentační vrstva: scény, kamera, vstup, animace](#17-prezentační-vrstva-scény-kamera-vstup-animace)
18. [Testovací strategie](#18-testovací-strategie)
19. [Implementační milníky](#19-implementační-milníky)
20. [Plán implementace v0.1.0](#20-plán-implementace-v010)
21. [Jak je tento dokument stavěný](#21-jak-je-tento-dokument-stavěný)

---

## 1. Účel a rozsah

Dokument popisuje kompletní technickou stavbu hry v rozsahu, který umožňuje implementaci po malých, samostatně ověřitelných krocích (viz [CLAUDE.md](../CLAUDE.md)). Pokrývá:

- datový model levelu a běhový stav simulace,
- pravidla vyhodnocení kroku a akcí jako deterministický algoritmus,
- vodní systém včetně přesné aritmetiky hladin,
- binární formát uložení levelu,
- architekturu editoru,
- napojení simulace na Godot scénu (render, animace, kamera, vstup),
- testovací strategii a pořadí implementace.

Mimo rozsah: art styl, konkrétní modely, zvuk, UI vizuál (dle design dokumentu se řeší od 0.2.0), lokalizace, multiplayer, ukládání postupu hráče mezi levely.

---

## 2. Architektonické principy

Tyto principy jsou závazné. Každé pozdější rozhodnutí, které je poruší, musí být v dokumentu odůvodněné.

**P1 — Simulace je oddělená od zobrazení.**
Veškerá herní logika žije v `core/` jako čisté GDScript třídy (`RefCounted`), které **nedědí z `Node`**, nesahají na `SceneTree`, nevolají `get_node()`, nepoužívají `_process()` ani fyziku. Godot vrstva simulaci pouze *řídí* (posílá příkazy) a *pozoruje* (konzumuje události). Důsledek: celou hru lze odsimulovat headless v testu bez jediné scény.

**P2 — Simulace je plně deterministická a bez plovoucí čárky.**
Hra neobsahuje náhodu ani AI (design dokument §1). Stav i všechny výpočty jsou celočíselné. Objemy vody a hladiny se počítají v celých číslech s porovnáním přes křížové násobení (viz [§9](#9-vodní-systém)) — **nikdy `float`**. Plovoucí čárka existuje pouze v prezentační vrstvě (interpolace animací, kamera).

**P3 — Simulace je synchronní a atomická; animace je asynchronní.**
Příkaz hráče se vyhodnotí a aplikuje celý v jednom okamžiku (nula herních snímků). Výsledkem je seznam **událostí** popisujících, co se stalo. Prezentační vrstva si tyto události přehraje v čase jako animaci. Simulace na animaci nikdy nečeká; vstup je po dobu přehrávání blokovaný na úrovni vstupní vrstvy, ne simulace.

**P4 — Dotazy na svět jdou přes mřížku, ne přes fyziku.**
Design dokument mluví o „raycastech" kolem robota. Implementačně to **nejsou** Godot `RayCast3D`: kolize s fyzikálním enginem není deterministická napříč platformami a je zbytečná, když je svět diskrétní mřížka. Místo toho existuje `GridProbe` — objekt s pozicí a orientací, který čte obsah buněk přímo z datového modelu se stejnou sémantikou, jakou popisuje design dokument („kostka před robotem", „kostka pod ním", „kostka, na kterou by vstoupil").

**P5 — Robot se nemůže zničit; neplatný úkon se neprovede.**
Design dokument §2.1.6. Technicky: každý příkaz má fázi **validace** oddělenou od fáze **aplikace**. Validace nesmí mutovat stav. Když validace neprojde, nemění se nic a nevzniká žádná událost kromě `CommandRejected`.

**P6 — Level je data, ne scéna.**
Level nikdy není `.tscn` s ručně naskládanými uzly. Je to datová struktura načtená ze souboru (viz [§15](#15-formát-uložení-levelu)); Godot uzly pro něj vzniknou až za běhu. Díky tomu je editor a runtime tentýž kód nad týmiž daty.

**P7 — Pravidla robotů jsou data, ne rozvětvené `if`.**
Chování kroku každého robota je definované behavior tree (design dokument §2.1.2). Stromy se ukládají jako samostatné soubory (viz [§7.5](#75-formát-uložení-stromů)), ne jako natvrdo napsaný GDScript per robot. Cíl: strom lze upravit bez zásahu do kódu enginu.

**P8 — Každý nevratný přechod stavu vydá událost.**
Prezentační vrstva, zvuk, statistiky i testy čtou tentýž proud událostí. Nic se nesmí měnit „potichu" pouhou mutací dat, na kterou by se muselo dotazovat pollingem.

---

## 3. Vrstvy a mapa modulů

```
game/
├── project.godot
├── core/                        # VRSTVA 1 — čistá simulace, žádný Node
│   ├── grid/
│   │   ├── grid_types.gd        # enumy: BlockType, Direction, ItemType…
│   │   ├── level_data.gd        # statická definice levelu (co je v souboru)
│   │   └── grid_probe.gd        # dotazování mřížky (náhrada raycastů, P4)
│   ├── sim/
│   │   ├── world_state.gd       # běhový stav (mutovatelný)
│   │   ├── simulation.gd        # vstupní bod: submit_command()
│   │   ├── commands.gd          # definice příkazů
│   │   ├── events.gd            # definice událostí
│   │   ├── gravity.gd           # usazování po změně světa
│   │   ├── water.gd             # nádrže, hladiny, utonutí
│   │   ├── actions/             # jedna třída na akci robota
│   │   └── devices.gd           # skříně, řídicí jednotky, plošiny, čerpadla
│   ├── bt/
│   │   ├── bt_runtime.gd        # interpret stromu (SUCCESS/FAIL/RUNNING)
│   │   ├── bt_nodes.gd          # knihovna uzlů
│   │   └── trees/               # stromy jednotlivých robotů
│   └── io/
│       ├── level_reader.gd      # binární formát → LevelData
│       └── level_writer.gd      # LevelData → binární formát
├── app/                         # VRSTVA 2 — Godot: zobrazení a vstup
│   ├── scenes/                  # main menu, level, editor
│   ├── view/                    # WorldView, animátor událostí, pooling
│   ├── camera/                  # orbitální + first person
│   └── input/                   # mapování akcí → Command
├── editor/                      # VRSTVA 2b — in-game editor nad LevelData
├── assets/                      # modely, materiály (knihovna modelů)
└── tests/                       # headless testy nad core/
```

Závislosti smí vést **pouze jedním směrem**: `app/` a `editor/` → `core/`. `core/` nesmí importovat nic z `app/`. Toto je kontrolovatelné testem (viz [§18](#18-testovací-strategie)).

---

## 4. Souřadný systém a konvence mřížky

Level je kvádr o rozměrech `size = Vector3i(x_len, y_height, z_width)`, kde:

| Osa | Význam | Design dokument |
|---|---|---|
| `X` | délka | „délka" |
| `Y` | výška, roste vzhůru | „výška" — určuje počet úrovní a max. výšku letu Da |
| `Z` | šířka | „šířka" |

Buňky mají celočíselné souřadnice `Vector3i` v rozsahu `[0, size)`. Buňka `c` odpovídá ve světě krychli se středem `Vector3(c) * CELL_SIZE + CELL_SIZE/2`. `CELL_SIZE = 1.0`.

Vše mimo `[0, size)` je *okraj levelu* — neprůchodná hranice (design dokument §2.1.4), technicky se chová jako plná zeď, ale nese vlastní typ, aby ji šlo odlišit při ladění.

**Směry.** Robot má vodorovnou orientaci ze čtyř hodnot; objekty v editoru mohou mít šest.

```gdscript
enum Direction { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3, UP = 4, DOWN = 5 }

const DIR_VECTOR := {
    Direction.NORTH: Vector3i(0, 0, -1),   # Godot forward = -Z
    Direction.EAST:  Vector3i(1, 0, 0),
    Direction.SOUTH: Vector3i(0, 0, 1),
    Direction.WEST:  Vector3i(-1, 0, 0),
    Direction.UP:    Vector3i(0, 1, 0),
    Direction.DOWN:  Vector3i(0, -1, 0),
}
```

Otočení vlevo = `(dir + 3) % 4`, vpravo = `(dir + 1) % 4`, čelem vzad = `(dir + 2) % 4`. Platí jen pro `dir < 4`.

**Iterační pořadí buněk** (závazné pro serializaci i pro jakýkoli deterministický průchod): `X` nejrychleji, pak `Z`, pak `Y`. Index buňky `i = y * (x_len * z_width) + z * x_len + x`.

---

## 5. Datový model

### 5.1 Typy bloků

```gdscript
enum BlockType {
    EMPTY = 0,
    WALL = 1,        # beton/ocel, nepohyblivá, nezničitelná
    RAMP = 2,        # šikmina, objem 1/2 kostky
    DIRT = 3,        # hlína — Han akce 1
    STONE = 4,       # kámen — podléhá gravitaci
    ICE = 5,         # led — jen v nádržích, ukotvený
    WOOD = 6,        # dřevo — zničitelná Setem (spálení), po zničení nezůstává nic; podléhá gravitaci
    TARGET = 7,      # cíl
}
```

Vlastnosti typů jsou tabulka, ne `if`:

| Typ | `solid` | `falls` | `burnable` | `diggable` | `walkable_top` | `capacity_units` |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| `EMPTY` | ne | — | — | — | — | 2 |
| `WALL` | ano | ne | ne | ne | ano | 0 |
| `RAMP` | ano | ne | ne | ne | (přechod) | 1 |
| `DIRT` | ano | ano | ne | ano | ano | 0 |
| `STONE` | ano | ano | ne | ne | ano | 0 |
| `ICE` | ano | ne¹ | ano | ne | ano (klouže) | 0 |
| `WOOD` | ano | ano | ano | ne | ano | 0 |
| `TARGET` | ne² | ne | ne | ne | — | 0 |

¹ Led je vždy ukotvený a nikdy nepadá (design dokument §1.1.6, §2.1.4). Vzniká pouze ve vodě a pouze tehdy, stojí-li Yeo na pevném podkladu nebo na jiné kostce ledu.
² Cíl je neprůchodný, dokud není odemčený; poté průchodný. Není to `solid` blok, je to speciální buňka se stavem.
`capacity_units` = kolik půl-kostkových jednotek vody se do buňky vejde (viz [§9](#9-vodní-systém)).

### 5.2 Statická data levelu (`LevelData`)

Přesně to, co je v souboru. Neměnné za běhu.

```gdscript
class_name LevelData extends RefCounted

var format_version: int
var size: Vector3i
var blocks: PackedByteArray          # block_type na buňku, iterační pořadí §4
var models: PackedInt32Array         # model_id na buňku (knihovna modelů)
var orientations: PackedByteArray    # Direction na buňku
var items: Array[ItemPlacement]      # typ + pozice
var key_position: Vector3i
var robots: Array[RobotPlacement]    # typ, pozice, směr, pořadí v sekvenci
var reservoirs: Array[ReservoirDef]  # počáteční objem, neomezenost
var devices: Array[DeviceDef]        # skříně, řídicí jednotky
var platforms: Array[PlatformDef]
var pumps: Array[PumpDef]
```

Tvar nádrže se **neukládá** — odvozuje se z geometrie zdí při načtení (viz [§9.1](#91-identifikace-nádrží)). Ukládá se jen její identita (kotevní buňka), počáteční objem a příznak neomezené kapacity.

### 5.3 Běhový stav (`WorldState`)

Vše, co se za hru mění. Restart levelu = zahodit `WorldState` a postavit ho znovu z `LevelData`.

```gdscript
class_name WorldState extends RefCounted

var size: Vector3i
var blocks: PackedByteArray           # mutovatelná kopie
var orientations: PackedByteArray     # mutovatelná kopie (natočení šikmin)
var robots: Array[RobotState]
var active_robot_index: int
var robot_sequence: Array[int]        # pořadí přepínání
var items_on_ground: Dictionary       # Vector3i -> ItemType
var key_holder: int                   # index robota, nebo -1
var key_position: Vector3i            # platné, když key_holder == -1
var target_unlocked: bool
var reservoirs: Array[ReservoirState]
var cell_to_reservoir: PackedInt32Array   # buňka -> index nádrže, nebo -1
var devices: Array[DeviceState]
var platforms: Array[PlatformState]
var pumps: Array[PumpState]
var finished_robots: Array[int]       # roboti, kteří prošli cílem
```

```gdscript
class_name RobotState extends RefCounted

var kind: RobotKind                   # HAN, DUL, SET, NET, DA, YEO, IL
var cell: Vector3i
var facing: Direction                 # vždy < 4
var inventory: Array[ItemType]        # kapacita dle §12
var hopper_full: bool                 # Han: korba; Dul: cisterna
var cannot_land_cell: Vector3i        # Da: buňka, kam po odhození předmětu nesmí přistát
var in_target: bool
```

**Invarianty**, které musí platit po každém dokončeném příkazu (kontroluje se v debug buildu a v testech):

- I1: každý robot je uvnitř `[0, size)`.
- I2: v jedné buňce není víc než jeden robot.
- I3: robot nestojí v buňce se `solid` blokem.
- I4: každý robot kromě Dula má hloubku vody ≤ 1/2 kostky (viz [§9.4](#94-kontrola-utonutí)).
- I5: každý robot kromě Da a Dula (ve vodě) stojí na pevném podkladu nebo na šikmině.
- I6: `hopper_full` je `true` jen u Hana a Dula.
- I7: velikost inventáře nepřekračuje kapacitu daného robota.
- I8: v levelu je právě jeden klíč (buď `key_holder >= 0`, nebo platná `key_position`).

---

## 6. Simulační jádro: tah, příkazy, události

### 6.1 Příkazy

Jediný vstup do simulace. Uzavřený výčet — nic jiného stav nemění.

```gdscript
enum CommandType {
    TURN_LEFT, TURN_RIGHT, TURN_AROUND,
    STEP,
    STEP_UP, STEP_DOWN,     # jen Da (kdykoli) a Dul (jen ve vodě), viz §7.7 — vlastní klávesy, mimo BT
    ACTION_1, ACTION_2,
    SWITCH_ROBOT_NEXT,      # Tab
    SWITCH_ROBOT_TO,        # klik v UI, nese cílový index
    RESTART_LEVEL,
}
```

### 6.2 Průběh příkazu

```
submit_command(cmd) -> CommandResult
  1. VALIDACE     — čistá funkce (WorldState, cmd) -> bool + důvod.
                    Nesmí mutovat. Neprojde-li → CommandRejected, konec.
  2. APLIKACE     — mutace WorldState, průběžně se sbírají události.
  3. DOSAZENÍ     — gravitace a usazení vody (§8, §9) až do ustálení.
  4. INVARIANTY   — v debug buildu ověření I1–I8.
  5. POSTPODMÍNKY — kontrola cíle levelu, případně LevelCompleted.
  → CommandResult { accepted: bool, reason: String, events: Array[Event] }
```

Krok 3 běží ve smyčce, dokud se svět nepřestane měnit, s tvrdým limitem iterací (`MAX_SETTLE_ITERATIONS = 256`) jako pojistkou proti chybě v pravidlech; překročení limitu je v debug buildu `assert`, v release se ustálení ukončí a zaloguje.

### 6.3 Události

```gdscript
# Pohyb a stav robota
RobotMoved(robot, from, to, substep_code)
RobotTurned(robot, from_dir, to_dir)
RobotEnteredTarget(robot)
ActiveRobotChanged(from, to)

# Svět
BlockRemoved(cell, block_type)
BlockPlaced(cell, block_type)
BlockFell(from, to, block_type)
ItemPickedUp(robot, item, cell)
ItemDropped(robot, item, cell)
KeyPickedUp(robot, cell)
TargetUnlocked()

# Voda
WaterVolumeChanged(reservoir, old_units, new_units)
IceMelted(cell, reservoir)

# Zařízení
DeviceRepaired(device)
DeviceToggled(device, is_on)       # skříň: Il přepnul napájení
PlatformMoved(platform, from_offset, to_offset)
PumpTransferred(pump, from_reservoir, to_reservoir, units)

# Řízení
CommandRejected(cmd, reason)
LevelCompleted()
```

Události jsou neměnné datové objekty. Pořadí v poli je pořadí, ve kterém se staly, a je závazné pro přehrání animace.

---

## 7. Pohyb: behavior tree a fronta dílčích kroků

Implementuje mechanismus z design dokumentu §2.1.2.

### 7.1 Dílčí kroky

```gdscript
enum Substep { FORWARD = 0, UP_RAMP = 1, UP_VERTICAL = 2, DOWN_RAMP = -1, DOWN_VERTICAL = -2 }
```

Posun pro robota s orientací `f` (`F = DIR_VECTOR[f]`):

| Kód | Posun |
|---|---|
| `0` | `F` |
| `1` | `F + (0,1,0)` |
| `2` | `(0,1,0)` |
| `-1` | `F + (0,-1,0)` |
| `-2` | `(0,-1,0)` |

### 7.2 `GridProbe`

Sonda nese pozici a orientaci a odpovídá na dotazy o okolí. Je to jediný způsob, jak strom čte svět.

```gdscript
class_name GridProbe extends RefCounted

var cell: Vector3i
var facing: Direction

func block_at(offset: Vector3i) -> BlockType       # offset v lokálním rámci sondy
func ahead(n := 1) -> BlockType
func below(n := 1) -> BlockType
func above(n := 1) -> BlockType
func ahead_below() -> BlockType                    # šikmo dolů před sondou
func ahead_above() -> BlockType                    # šikmo nahoru před sondou
func robot_at(offset: Vector3i) -> int             # index robota, nebo -1
func item_at(offset: Vector3i) -> ItemType
func water_depth_at(offset: Vector3i) -> WaterDepth  # DRY / SHALLOW / DEEP
func is_outside(offset: Vector3i) -> bool
func advance(substep: Substep) -> void             # posun sondy pro RUNNING
func behind(n := 1) -> BlockType                   # opak ahead(), pro sestup Neta (§7.6)
```

Lokální rámec: `+X` vpravo, `+Y` nahoru, `-Z` vpřed vzhledem k `facing`. Převod na globální souřadnice dělá sonda.

### 7.3 Interpret stromu

```gdscript
enum BTStatus { SUCCESS, FAIL, RUNNING }

class_name StepEvaluator extends RefCounted

func evaluate(world: WorldState, robot: int) -> Array[Substep]:
    var probe := GridProbe.new(world, world.robots[robot].cell, world.robots[robot].facing)
    var queue: Array[Substep] = []
    var tree := BTLibrary.tree_for(world.robots[robot].kind)
    for i in MAX_STEP_ITERATIONS:                 # tvrdý strop, viz níže
        var status := tree.tick(probe, queue)     # uzly smí přidávat do queue
        match status:
            BTStatus.SUCCESS: return queue        # provede se celá fronta
            BTStatus.FAIL:    return []           # nic se neprovede
            BTStatus.RUNNING: continue            # sonda už je posunutá uzlem
    return []                                     # ochrana proti zacyklení
```

**Klouzání po ledu a „jeden krok".** „Jeden krok" v design dokumentu znamená jeden příkaz hráče (`STEP`), ne jeden dílčí krok. Tento mechanismus to přímo implementuje: dokud strom vrací `RUNNING`, sonda postupuje po ledu dál a `queue` roste; teprve `SUCCESS`/`FAIL` na konci rozhodne, jestli se celá nashromážděná fronta provede, nebo zahodí. Pro led to konkrétně znamená: strom drží stav `RUNNING` (a přidává `Emit(0)` do fronty), dokud sonda stojí nad `ICE`; jakmile dojde na jiný povrch, vrátí `SUCCESS` a robot sklouže celou nasbíranou vzdálenost najednou v jedné animaci. Skončí-li sonda nad propastí (žádný pevný podklad na konci ledové plochy), strom vrátí `FAIL` a krok se neprovede vůbec — kontrola proběhne dopředu, ne až po sklouznutí. Netýká se Yea (chodí po ledu jako po souši, neklouže) ani Da (nepohybuje se po zemi).

`MAX_STEP_ITERATIONS = 128` — horní mez délky jednoho kroku hráče. Reálně ji vyčerpá jen dlouhý skluz po ledu nebo série šikmin přes celý level; smyčka bez postupu je chyba ve stromě a v debug buildu shodí `assert`.

Kontrakt uzlu `RUNNING`: uzel, který vrací `RUNNING`, **musí** přidat alespoň jeden dílčí krok do fronty a posunout sondu — jinak vzniká nekonečná smyčka. Toto vynucuje `bt_runtime.gd` kontrolou, že se délka fronty zvětšila.

### 7.4 Knihovna uzlů

| Uzel | Sémantika |
|---|---|
| `Sequence` | děti postupně; první `FAIL` → `FAIL`; první `RUNNING` → `RUNNING`; jinak `SUCCESS` |
| `Selector` | děti postupně; první `SUCCESS` → `SUCCESS`; první `RUNNING` → `RUNNING`; jinak `FAIL` |
| `Inverter` | prohodí `SUCCESS`/`FAIL`, `RUNNING` propustí |
| `Condition(predicate)` | dotaz na sondu, `SUCCESS`/`FAIL`, nemutuje |
| `Emit(substep)` | přidá dílčí krok do fronty, posune sondu, vrátí `SUCCESS` |
| `EmitAndContinue(substep)` | totéž, ale vrátí `RUNNING` (opakuje vyhodnocení z nové pozice) |
| `Succeed` / `Fail` | terminály |

Predikáty pro `Condition` jsou pojmenované a registrované v jedné tabulce (`bt_nodes.gd`), aby je bylo možné referencovat ze souboru stromu jménem: `ahead_is_solid`, `ahead_is_ice`, `ahead_has_item`, `below_is_solid`, `behind_is_solid`, `behind_is_ice`, `ahead_is_ramp_facing_me`, `ahead_below_is_ramp_facing_away`, `ahead_below_is_ice`, `ahead_below_is_solid`, `ahead_is_passable`, `landing_is_safe`, `ahead_water_is_deep`, `ahead_water_is_boardable`, `here_is_water`, `here_water_is_deep`, `carrying_at_most(n)`, …

### 7.5 Formát uložení stromů

Stromy se ukládají jako **JSON** v `core/bt/trees/`. Soubor nese jeden strom jako vnořené slovníky (`{"type": "sequence", "children": [...]}`); uzly a predikáty se odkazují jménem podle tabulek v [§7.4](#74-knihovna-uzlů).

> **Změna proti původnímu návrhu (`.tres`).** Ruční psaní `.tres` s vnořenými resources je křehké a mimo Godot inspektor se špatně kontroluje; JSON nese tatáž data, dá se validovat samostatným testem ([§18](#18-testovací-strategie)) a čte se v diffu stejně dobře. Požadavek P7 (pravidla jsou data, ne kód) zůstává splněný.

Souborů je pět, ne sedm — sdílený základ chůze ([§7.6.0](#7600-sdílený-základ-chůze-han-set-il-dul-po-souši)) je jeden soubor, ne tři kopie:

| Soubor | Kdo ho používá |
|---|---|
| `walk_base.json` | Han, Set, Il |
| `walk_yeo.json` | Yeo |
| `net.json` | Net (základ chůze + šplhání) |
| `da.json` | Da (vodorovný let) |
| `dul.json` | Dul (souš i voda v jednom stromě) |

**Proč má Dul jeden strom, a ne dva.** Strom se vybírá jednou na začátku kroku. Dulův krok ale umí prostředí uprostřed změnit — sklouznout po ledu do vody, nebo vylézt z vody na led a klouzat dál (design dok. §1.1.2). Výběr podle „je právě ve vodě" by takový krok nikdy nedokončil: strom plavání o ledu neví a sdílený základ neumí plavat. Cenou je, že `dul.json` opakuje větve sdíleného základu; formát stromů nemá mechanismus vkládání a Dulův strom se od základu skutečně liší.

**Režim smyčky (`mode`).** Strom se po každém `RUNNING` vyhodnocuje znovu od kořene z posunuté sondy, takže z pozice samotné nejde poznat, jestli jde o začátek kroku, nebo o pokračování skluzu/šplhání. Uzel `EmitAndContinue` proto nese pole `mode` (`slide`, `ramp`, `climb_up`, `climb_down`) a větve se gatují predikátem `mode_in`. Bez toho by Net po neúspěšném výlezu spadl do větve sešplhání místo `FAIL`.

Režim `ramp` znamená „sonda stojí na šikmině". Na šikmině nelze setrvat (design dok. §2.1.4), takže v tomto režimu nesmí žádná větev krok ukončit bez dalšího dílčího kroku — proto v něm chybí větev „konec skluzu o překážku" a proto obě větve šikmin vracejí `RUNNING`. Není-li kam pokračovat, propadne `Selector` až na `Fail` a celý krok se zahodí; robot na šikminu ani nevstoupí. Pojistkou proti větvím, které by robota na šikmině složily jinudy (rovná chůze na horní hranu, výlez Neta, vylezení Dula z vody), je kontrola v `StepEvaluator`: `SUCCESS`, po kterém by sonda stála na šikmině, se překlopí na odmítnutý krok. „Stát na šikmině" je přitom obojí — být v buňce šikminy (sestup) i v buňce nad ní (výstup, viz [V6](#162-validace-levelu)); výjimku mají Da (letí) a Dul ve vodě (plave), stejně jako v usazování ([§8](#8-gravitace-a-usazování)).

### 7.6 Stromy jednotlivých robotů

Následující bloky definují krok a rozhodovací logiku akcí pro každého robota.

#### 7.6.0 Sdílený základ chůze (Han, Set, Il, Dul po souši)

Podmínky větví se vzájemně vylučují (viz predikát `ahead_below_is_ice` explicitně vyloučený z „rovná chůze" — bez toho by kolidoval s větví „led", protože `ICE` má `solid = ano`, viz [§5.1](#51-typy-bloků)), pořadí větví v `Selectoru` proto nehraje roli. Výjimkou je dvojice „šikmina dolů" / „rovná chůze", která se překrývá (viz [O2](#207-otevřené-otázky-z-implementace)) — tam rozhoduje pořadí.

```
Selector "krok":
  Sequence "led":
    Condition mode_in ["", "slide", "ramp"]
    Condition ahead_is_passable
    Condition ahead_below_is_ice        → TRUE
    EmitAndContinue(0, mode=slide)   # RUNNING; opakuje se z posunuté pozice,
                          # dokud ahead_below_is_ice; skončí Emit(0)+Succeed na
                          # pevné (neledové) zemi, Fail nad propastí (§7.3)
  Sequence "konec skluzu o překážku":
    Condition mode_in ["slide"]      # v režimu "ramp" schválně ne — na
    Condition ahead_is_passable → FALSE   # šikmině se zastavit nedá
    Succeed
  Sequence "šikmina nahoru":
    Condition mode_in ["", "slide", "ramp"]
    Condition ahead_is_ramp_facing_me
    Condition ahead_above_is_passable
    EmitAndContinue(1, mode=ramp)    # RUNNING: na šikmině nelze setrvat,
                          # za výstupem musí následovat další dílčí krok
  Sequence "šikmina dolů":
    Condition mode_in ["", "slide", "ramp"]
    Condition ahead_is_passable
    Condition ahead_below_is_ramp_facing_away
    Condition ahead_below_free_for_robot
    EmitAndContinue(-1, mode=ramp)   # RUNNING ze stejného důvodu
  Sequence "rovná chůze":
    Condition mode_in ["", "slide", "ramp"]   # "ramp" = sesednutí ze šikminy
    Condition ahead_is_passable
    Condition ahead_below_is_solid      → TRUE
    Condition ahead_below_is_ice        → FALSE   (jinak kolize s „led")
    Emit(0)
  Fail
```

Série šikmin za sebou je proto jeden příkaz hráče, stejně jako skluz po ledu: režim `ramp` propouští obě větve šikmin i větev led, takže se výstupy/sestupy řetězí a krok skončí až sesednutím na rovinu (nebo skluzem po ledu, u Dula vstupem do vody).

`ahead_is_passable(robot)` — sdílený predikát: kostka před robotem (na výšce robota) není `solid`, **a** pokud na ní leží předmět, robot ho buď smí sebrat (je v seznamu povolených sběračů daného `ItemType`, [§12](#12-inventář-a-předměty)) a má v inventáři volné místo, nebo tam předmět není. Jinak je předmět překážka a `ahead_is_passable` vrací `FALSE`. Sbírání do inventáře samo je efekt aplikační fáze (`ItemPickedUp`), strom pouze rozhoduje o průchodnosti.

Tento strom používají beze změny **Han**, **Set** a **Il** — žádný z nich nemá pohybové rozšíření nad rámec kroku vpřed / šikminy / klouzání po ledu; jejich robot-specifické rozdíly jsou jen v akcích ([§11](#11-akce)), ne v kroku. **Yeo** používá variantu níže, **Dul** vlastní strom (tytéž větve plus voda).

#### 7.6.0b Varianta pro YEO (chůze po ledu bez klouzání)

Yeo nemá samostatnou větev „led" s `RUNNING` smyčkou — led je pro něj jen další pevný povrch:

```
Selector "krok":
  Sequence "šikmina nahoru":
    Condition mode_in ["", "ramp"]
    Condition ahead_is_ramp_facing_me
    Condition ahead_above_is_passable
    EmitAndContinue(1, mode=ramp)
  Sequence "šikmina dolů":
    Condition mode_in ["", "ramp"]
    Condition ahead_is_passable
    Condition ahead_below_is_ramp_facing_away
    Condition ahead_below_free_for_robot
    EmitAndContinue(-1, mode=ramp)
  Sequence "rovná chůze":
    Condition mode_in ["", "ramp"]
    Condition ahead_is_passable
    Condition ahead_below_is_solid      → TRUE
    Emit(0)
  Fail
```

Jediný rozdíl proti sdílenému základu: chybí větev „led" a „rovná chůze" nemá vylučovací podmínku na led — `ahead_below_is_solid` zahrnuje led i normální zem stejně.

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: HAN
     ════════════════════════════════════════════════════════════════════
     Han: sdílený základ chůze, viz §7.6.0. Beze změny.
     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: DUL (po souši i ve vodě)
     ════════════════════════════════════════════════════════════════════
     Jeden strom na souš i vodu (`dul.json`), protože krok umí prostředí
     uprostřed změnit — viz §7.5. Svisle ve vodě (nahoru/dolů) zůstává
     mimo BT: STEP_UP/STEP_DOWN, viz §7.7. Dul plave volně, bez nutnosti
     pevného podkladu pod sebou (I5 výjimka, §5.3) a bez limitu ponoru (§10).

     Prvních šest větví je sdílený základ chůze (§7.6.0) plus „plavání
     vpřed" na začátku; zbytek je voda:

     Selector "krok":
       Sequence "plavání vpřed / doplavání do vody":
         Condition mode_in ["", "slide", "ramp"]
         Condition ahead_is_passable   → TRUE   (u Dula prakticky vždy
                                           „bez předmětu a bez solid bloku" —
                                           Dul není sběratel žádného ItemType,
                                           §12, takže predikát se chová stejně
                                           jako holý ahead_is_solid == FALSE)
         Condition ahead_is_water      → TRUE
         Emit(0)
       ... větve „led", „konec skluzu", „šikmina nahoru/dolů",
           „rovná chůze" — beze změny ze sdíleného základu (§7.6.0),
           včetně režimu „ramp" (šikmina je pro Dula cesta do nádrže,
           jejíž hladina je moc nízko na vstup ze břehu, design dok. §2.1.4).
           Větev „led" slouží zároveň jako výlez z vody na led v rovině
           hladiny, větev „rovná chůze" jako výlez na břeh v téže rovině.
       Sequence "výlez na ledový břeh o patro výš":
         Condition ahead_is_solid
         Condition ahead_is_ice
         Condition here_water_is_deep
         Condition ahead_above_is_passable
         EmitAndContinue(1, mode=slide)   # dál se klouže až na konec ledu
       Sequence "výlez na břeh o patro výš":
         Condition ahead_is_solid
         Condition here_water_is_deep
         Condition ahead_above_is_passable
         Emit(1)
       Sequence "vstup do vody ze břehu / z konce ledu / ze šikminy":
         Condition mode_in ["", "slide", "ramp"]
         Condition ahead_is_passable
         Condition ahead_water_is_boardable
         Emit(0)                          # do vody dosedne usazením, §8
       Fail

     Podmínka hladiny (design dok. §1.1.2 + tolerance §2.1.4: hladina smí
     být pod rovinou podkladu, ale méně než o půl kostky) je ve dvou
     predikátech:

       ahead_water_is_boardable — hladina nádrže před robotem sahá do
         roviny, po které se robot pohybuje (`probe.cell.y`), případně
         méně než půl kostky pod ni. Celočíselně: hladina leží ve vrstvě
         `y_top` se zbytkem `remaining`; stačí `y_top >= floor_y`, nebo
         `y_top == floor_y - 1 && 2 * remaining > capacity_of_layer(y_top)`.
       here_water_is_deep — pro výlez o patro výš je „hladina v rovině
         horní hrany té zdi" totéž jako „voda v mé buňce je hlubší než půl
         kostky": horní hrana leží přesně o kostku výš než dno mé buňky.
         Je-li cílová buňka nad zdí ještě pod hladinou, není to výlez, ale
         plavání šikmo vzhůru — což je taky správně.


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: SET
     ════════════════════════════════════════════════════════════════════
     Set: sdílený základ chůze, viz §7.6.0. Beze změny.
     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: NET (včetně šplhání nahoru a dolů)
     ════════════════════════════════════════════════════════════════════

     Net sdílí základ chůze (§7.6.0: rovná chůze, šikmina, klouzání po ledu
     — Net po ledu klouže stejně jako ostatní, viz §10). Šplhání jsou dvě
     další větve, které se zkusí až po ramp/led/rovné chůzi, těsně před
     finálním Fail — tzn. spouští se jen tehdy, když normální krok nejde.
     Obě jsou gatované `mode_in [""]`: šplhat jde jen z roviny, ne ze
     šikminy ani uprostřed skluzu (viz O12 v §20.7).

     Šplhání NAHORU (spouští se, když je vpředu zeď, kam by normální krok
     nemohl vstoupit):

     Sequence "šplhání nahoru":
       Condition ahead_is_solid              → TRUE
       Condition carrying_at_most(2)         → TRUE
       Condition ahead_is_ice                → FALSE   (kostka zdi na aktuální výšce)
       EmitAndContinue(2)    # RUNNING — sonda stoupá podél zdi (x,z beze změny)

     Další tiky (z posunuté pozice, stejné x,z, vyšší y) — týž strom, znovu
     vyhodnocený z nové pozice sondy, se rozhodne mezi třemi větvemi:
       - ahead_is_solid a NE ahead_is_ice     → EmitAndContinue(2), šplhá dál
       - ahead_is_solid a ahead_is_ice        → Fail (led kdekoli ve zdi cestou
                                                  nahoru shodí celou nashromážděnou
                                                  frontu — stejný mechanismus jako
                                                  u ledové plochy, §7.3)
       - NE ahead_is_solid (zeď skončila)     → zkontroluj přistání:
           Condition ahead_below_is_solid → TRUE  → Emit(0), Succeed (vstup na vrchol)
           Condition ahead_below_is_solid → FALSE → Fail (otvor/strop bez pevného
                                                       přistání, ne skutečný vrchol)

     Šplhání DOLŮ (spouští se, když je vpředu propast — normální krok by
     selhal, protože ahead_below není solid):

     Sequence "sešplhání dolů":
       Condition ahead_is_passable           → TRUE
       Condition ahead_below_is_solid        → FALSE
       EmitAndContinue(0)   # krok vpřed do prázdna (nová pozice, stejná výška), RUNNING

     Další tiky (z posunuté pozice) — kontrola probíhá proti sloupci ZA
     Netem (tj. hraně, odkud přišel, teď v zádech), ne před ním:
       - below_is_solid                      → TRUE  → Succeed (queue už končí
                                                  na téhle buňce, přistání)
       - below_is_solid FALSE a behind_is_solid TRUE a NE behind_is_ice
                                              → EmitAndContinue(-2), klesá dál
       - behind_is_solid FALSE, NEBO behind_is_ice TRUE
                                              → Fail (stěna, po které šplhá,
                                                  cestou zmizela nebo je z ledu)

     Na sešplhání dolů neplatí `carrying_at_most` (design dokument: „dolů bez
     limitu předmětů").

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: DA (let vodorovně i svisle)
     ════════════════════════════════════════════════════════════════════
     Svisle (nahoru/dolů): STEP_UP/STEP_DOWN, mimo BT, viz §7.7.

     Vodorovně (STEP dopředu za letu) — vlastní, triviální strom (žádná
     fronta, žádný RUNNING), stejně jednoduchý jako u Dula ve vodě, ale
     s přísnější podmínkou na předměty: Da NEsmí použít sdílený predikát
     ahead_is_passable, protože ten by mu dovolil sebrat předmět i ze
     strany — Da sbírá jen shora (§12), vodorovně je pro něj předmět vždy
     překážka bez ohledu na to, že by ho jinak sbírat směl a měl by místo
     v inventáři:

     Selector "krok (let)":
       Sequence "let vpřed":
         Condition ahead_is_solid      → FALSE
         Condition ahead_has_item      → FALSE   (na rozdíl od ahead_is_passable
                                           ignoruje, zda by Da předmět směl sebrat)
         Emit(0)
       Fail


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: YEO (včetně chůze po ledu bez klouzání)
     ════════════════════════════════════════════════════════════════════
     Yeo: viz varianta §7.6.0b (chůze po ledu bez klouzání).
     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: IL (včetně klouzání po ledu)
     ════════════════════════════════════════════════════════════════════
     Il: sdílený základ chůze, viz §7.6.0 (klouzání po ledu je jeho součástí). Beze změny.
     ════════════════════════════════════════════════════════════════════ -->

Rozhodovací logika je potřeba i mimo krok. Design dokument §2.1.2 ji zmiňuje u akcí Hana a Seta; stejný zápis se používá i pro ostatní situace níže:

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: HAN (nahrábnutí)
     výběr cílové kostky: před / pod / šikmo dolů před
     kontrola robota pod odebíranou kostkou
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.1: tři možné cíle podle polohy vůči Hanovi;
     hlavní/běžný případ je "ahead_below" (kostka šikmo dolů před ním,
     když je přímo před ním prázdno). Priorita mezi třemi cíli je stejná
     jako pořadí větví ve sdílené chůzi (§7.6.0):

     Sequence "akce 1 han":
       Condition hopper_is_empty              → TRUE   (nelze hrabat s plnou korbou)
       Selector "výběr cíle":
         Sequence "před":
           Condition ahead_is_dirt             → TRUE
           Condition no_robot_below(ahead)     → TRUE   (robot přímo pod
                                                    odebíranou kostkou, ne pod Hanem)
           Emit(DigTarget.AHEAD)
         Sequence "pod":
           Condition below_is_dirt             → TRUE
           Condition no_robot_below(below)      → TRUE
           Emit(DigTarget.BELOW)               # Han se posune o úroveň níž,
                                                 # stejný mírný pád jako u
                                                 # spadu věže (§8), jde-li
                                                 # o kostku pod jeho vlastníma
                                                 # nohama
         Sequence "šikmo dolů před":
           Condition ahead_is_passable         → TRUE   ("prázdný prostor" před ním)
           Condition ahead_below_is_dirt       → TRUE
           Condition no_robot_below(ahead_below) → TRUE
           Emit(DigTarget.AHEAD_BELOW)
         Fail
       # Emit výše neznamená substep kroku, ale cíl pro apply() akce —
       # apply() odstraní danou kostku, naplní korbu (hopper_full = true),
       # spustí gravitační usazení (§8), které samo posune věž i případného
       # robota na jejím vrcholu o úroveň níž bez zničení.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: HAN (vysypání korby)
     hledání místa dopadu za robotem, dopad do vody, kontrola utonutí
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.1:

     Sequence "akce 2 han":
       Condition hopper_is_full                → TRUE
       Condition has_free_space_behind(robot)   → TRUE   (ne přímo zeď za ním)
       # landing_cell_for_drop hledá od buňky za robotem dolů první buňku,
       # kde kostka spočine — pevný podklad, nebo hladina vody, viz §8
       var landing := landing_cell_for_drop(behind(1))
       Condition no_robot_at(landing)           → TRUE   (na dopad nikdo nestojí)
       Selector "cíl dopadu":
         Sequence "dopad na sucho":
           Condition landing_is_dry             → TRUE
           Emit(DropTarget.DRY, landing)
         Sequence "dopad do vody":
           Condition landing_is_water           → TRUE
           Condition raising_water_is_safe(reservoir_at(landing), 2)  → TRUE
                                                   # FALSE i pro zcela plnou
                                                   # (ne unlimited) nádrž —
                                                   # tam už není kam kostka
                                                   # vešla, viz §9.3 pozn. ³
           Emit(DropTarget.WATER, landing)
         Fail
       # apply(): vytvoří DIRT na landing; u vody navíc -1 kapacita a +2
       # volume_units (§9.3), BlockPlaced + WaterVolumeChanged.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: SET (zapálení dřeva / roztavení ledu)
     priorita cíle dřeva: vodorovně → šikmo → svisle
     led: jen ahead_below, s kontrolou plovoucí kry
     kontrola robota pod ničenou kostkou
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.3. Dřevo a led mají
     různý dosah — dřevo prioritu míst, led jen jedno konkrétní místo:

     Sequence "akce 1 set":
       Condition has_item(robot, FUEL)          → TRUE
       Selector "cíl":
         Sequence "dřevo":
           Selector "priorita dřeva":
             Sequence "vodorovně":  Condition ahead_is_wood → TRUE
                                     Emit(BurnTarget.AHEAD)
             Sequence "šikmo":      Condition ahead_below_is_wood → TRUE
                                     Emit(BurnTarget.AHEAD_BELOW)
             Sequence "svisle":     Condition above_is_wood → TRUE
                                     Emit(BurnTarget.ABOVE)
             Fail
           Condition no_robot_below(<vybraná kostka>)  → TRUE
         Sequence "led":
           Condition ahead_below_is_ice          → TRUE
           Condition no_floating_ice_raft(ahead_below)  → TRUE
                                                    # led, který by po
                                                    # roztavení zůstal
                                                    # nespojený s pevným
                                                    # podkladem — BFS nad
                                                    # grafem sousedících
                                                    # ICE buněk až po pevný
                                                    # podklad
           Emit(BurnTarget.ICE_AHEAD_BELOW)
         Fail
       # apply(): FUEL se spotřebuje vždy při úspěchu. Dřevo: BlockRemoved,
       # spustí gravitační usazení (§8) — mírný pád, i s robotem na vrcholu.
       # Led: BlockRemoved(ICE) → BlockPlaced(EMPTY jako voda), kapacita +2
       # a volume_units +2 (§9.3, pozn. ¹), IceMelted. Žádná kontrola
       # utonutí — hladina se roztavením nehýbe.
       # Nic k zapálení/roztavení v dosahu → celý strom FAIL, "pálení
       # naprázdno" se neprovede a FUEL se nespotřebuje.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: DUL (načerpání vody)
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.2: ze břehu jen když je
     nádrž zaplněná > 50 %, ponořený (mělká i hluboká voda) bez omezení.

     Sequence "akce 1 dul":
       Condition hopper_is_empty                → TRUE
       Selector "kde":
         Sequence "ponořený":
           Condition water_depth_here != DRY     → TRUE   (Dul stojí ve vodě)
           Emit(PumpSource.HERE)
         Sequence "ze břehu":
           Condition water_depth_here == DRY      → TRUE
           Condition reservoir_within_reach(ahead) != -1  → TRUE
                                                     # nádrž před robotem: buď
                                                     # v jeho rovině, nebo o patro
                                                     # níž — na běžném břehu dutina
                                                     # k rovině nohou nesahá (§9.1),
                                                     # stejná úvaha jako u predikátu
                                                     # water_ahead_is_boardable.
                                                     # Přes pevný blok (i led) se
                                                     # nedosáhne.
           Condition reservoir_fill_ratio(ahead) > 1/2   → TRUE
                                                     # celočíselně: 2 * volume_units
                                                     # > capacity_units, stejný
                                                     # vzorec jako §9.4. Jak vysoko
                                                     # hladina sahá, řeší jen tenhle
                                                     # poměr — ne poloha buňky, do
                                                     # které Dul kouká.
           Emit(PumpSource.AHEAD)
         Fail
       # apply(): volume_units -2 v dané nádrži (plná cisterna = 2 jednotky,
       # §9.3), hopper_full = true, WaterVolumeChanged. Nádrž unlimited:
       # volume_units se nemění, čerpání i tak uspěje (§13.3).

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: DUL (vypuštění cisterny)
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.2: vypuštění dozadu,
     ze břehu i přímo do nádrže, s kontrolou utonutí.

     Sequence "akce 2 dul":
       Condition hopper_is_full                 → TRUE
       Condition reservoir_within_reach(behind) != -1  → TRUE
                                                    (ze břehu i z vody za sebou —
                                                    "behind" zahrnuje i pozici, kde
                                                    Dul sám stojí ve vodě, a stejně
                                                    jako u akce 1 i nádrž o patro
                                                    níž, tzn. jámu pod hranou břehu.
                                                    Voda v nádrži být nemusí —
                                                    vypouští se i do prázdné oblasti
                                                    určené k zatopení.)
       Condition raising_water_is_safe(reservoir_within_reach(behind), 2)  → TRUE
                                                    # FALSE, pokud by některý
                                                    # jiný robot v nádrži
                                                    # (kromě Dula) utonul, §9.4
       Emit(PumpTarget.BEHIND)
       # apply(): volume_units +2 (§9.3), hopper_full = false,
       # WaterVolumeChanged. Nádrž unlimited: volume_units se nemění,
       # vypuštění i tak uspěje bez kontroly utonutí (§13.3).

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: YEO (vytvoření ledové kostky)
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.6: žádné bezpečnostní
     omezení kromě mít co zmrazit — na rozdíl od Setova roztavení ledu
     (§7.6 výše) nemá vlastní safety-check jako je plovoucí kra, protože
     vznik ledu nikdy nic neodpojuje od podkladu.

     Sequence "akce 1 yeo":
       Condition has_item(robot, FUEL)          → TRUE
       Condition standing_on_solid_or_ice        → TRUE   (pevný podklad,
                                                    nebo jiná kostka ledu)
       Condition water_cell_within_reach(ahead) != NO_CELL  → TRUE
                                                    # mrazí se "ze břehu i
                                                    # z mělké vody" (design
                                                    # dok. §1.1.6): buňka
                                                    # s vodou buď v rovině
                                                    # robota, nebo o patro
                                                    # níž — na břehu je buňka
                                                    # v rovině nohou jen
                                                    # vzduch nad nádrží (§9.1),
                                                    # stejný dosah jako
                                                    # u Dulovy hadice výše.
                                                    # Přes pevný blok (i led)
                                                    # se nedosáhne.
       Condition reservoir_fill_ratio(target) > 1/2  → TRUE
                                                    # "hladina vyšší než do
                                                    # poloviny okrajové
                                                    # kostky", stejný vzorec
                                                    # jako u Dulova čerpání
                                                    # ze břehu (§7.6 výše)
       Emit(FreezeTarget = ta buňka s vodou)
       # apply(): FUEL se spotřebuje, cílová buňka -> ICE (kotvená k podkladu
       # pod ní, capacity_units = 0), volume_units -2 a kapacita -2 ve
       # stejné nádrži (§9.3, pozn. ¹), BlockPlaced + WaterVolumeChanged.
       # Ze břehu tak vznikne led, jehož horní hrana je v rovině nohou —
       # robot na něj rovnou vkročí (ledová cesta, design dok. §1.1.6).
       # Není co zmrazit (žádná voda splňující podmínku výše) → FAIL,
       # akce se neprovede a FUEL zůstává.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1/2: IL (oprava, sepnutí panelu, odložení kitu)
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.7. Na rozdíl od ostatních
     akcí tu není žádný BT nad GridProbe — jde jen o krátké rozhodnutí nad
     WorldState (stejně jako §7.7 u STEP_UP/STEP_DOWN), protože nejde o
     pohyb ani frontu dílčích kroků:

     Akce 1 (ACTION_1):
       Selector "akce 1 il":
         Sequence "oprava":
           Condition ahead_is_device            → TRUE
           Condition device_is_broken(ahead)     → TRUE
           Condition has_item(robot, SERVICE_KIT) → TRUE
           Emit(RepairDevice(ahead))              # kit se spotřebuje,
                                                    # DeviceRepaired
         Sequence "rozbité bez kitu":
           Condition ahead_is_device            → TRUE
           Condition device_is_broken(ahead)     → TRUE
           Fail                                   # nelze opravit ani sepnout
         Sequence "sepnutí panelu":
           Condition ahead_is_device            → TRUE
           Condition device_is_broken(ahead)     → FALSE
           Condition ahead_facing_access_direction → TRUE   (§13.1: Il musí
                                                    stát ve správném směru)
           Condition device_input_would_do_something(ahead) → TRUE
           Emit(DeviceInput(ahead))               # skříň: přepnutí napájení
                                                    # + DeviceToggled;
                                                    # jednotka: PlatformMoved
                                                    # / PumpTransferred
         Fail

     Akce 2 (ACTION_2):
       Sequence "odložení kitu":
         Condition has_item(robot, SERVICE_KIT)  → TRUE
         Condition has_free_space_behind(robot)   → TRUE
         Emit(DropItem(SERVICE_KIT, behind(1)))

     Žádný „režim ovládání zařízení" neexistuje: jeden stisk Akce 1 je jedno
     sepnutí panelu, robot si mezi příkazy nedrží žádnou vazbu na zařízení
     (design dokument §1.1.7). Il proto nemá ani zvláštní případ pro
     `is_safe_to_leave` ([§10](#10-specifikace-robotů)) — přepnutí pryč
     z Ila je vždy bezpečné, protože žádný mezistav trvající přes hranici
     mezi příkazy hráče u něj nevzniká.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — ODLOŽENÍ PŘEDMĚTU ZA SEBE (Set, Net, Yeo, Il)
     ════════════════════════════════════════════════════════════════════
     Design dokument §2.1.3 "Odhazování předmětů".
     Sdílená logika pro čtyři roboty (Da má vlastní variantu níže — odhazuje
     pod sebe, ne za sebe). Stejná kontrola místa dopadu jako u Hanova
     vysypání korby (§7.6 výše), ale bez omezení na plnou nádrž — předmět
     nemá vlastní objem, nezabírá kapacitu nádrže:

     Sequence "odložení předmětu":
       Condition has_item(robot, item)          → TRUE
       Condition has_free_space_behind(robot)    → TRUE
       var landing := landing_cell_for_drop(behind(1))
       Condition no_robot_at(landing)            → TRUE
       Emit(DropItem(item, landing))
       # apply(): ItemDropped. Dopad do vody: povoleno bez další kontroly,
       # WaterVolumeChanged se NEvydává — hladina se nezvýší (na rozdíl od
       # Hanovy hlíny). Vylovit předmět z vody zpět nejde (Dul předměty
       # nesbírá) — design dokument to označuje jako nedoporučené, ne jako
       # zakázané; strom to nijak nevaruje/neblokuje.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: DA (odhození předmětu pod sebe)
     ════════════════════════════════════════════════════════════════════
     Design dokument §1.1.5: odhození jde jen dolů,
     minimálně o jednu kostku, a po odhození nesmí Da na místě přistát bez
     opětovného sebrání. Stejná no_robot_at kontrola dopadu jako výše.

     Sequence "akce 2 da":
       Condition has_item(robot, item)          → TRUE
       Condition below_is_passable                → TRUE   (aspoň jedna
                                                    kostka volného prostoru
                                                    pod Da — "alespoň o
                                                    jednu kostku")
       var landing := landing_cell_for_drop(below(1))
       Condition no_robot_at(landing)             → TRUE
       Emit(DropItem(item, landing))
       # apply(): ItemDropped na landing (dopad do vody: bez WaterVolumeChanged,
       # stejně jako u ostatních robotů výše). Da zůstává na svém místě ve
       # vzduchu — nesestupuje s předmětem. Cíl pod Da se navíc označuje jako
       # "cannot_land" (Da na něj nesmí bez opětovného sebrání předmětu
       # přistát), viz is_safe_to_leave a STEP_DOWN (§7.7). Příznak drží
       # RobotState v poli `cannot_land_cell`.

     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — PODMÍNKA „ROBOT JE V BEZPEČÍ" PRO PŘEPNUTÍ
     design dokument §2.1.2: Da, Il, Net
     ════════════════════════════════════════════════════════════════════
     Da: musí stát na pevném podkladu (design dokument §2.1.2),
     viz §10 tabulka. Toto je jediný skutečný `is_safe_to_leave` predikát —
     jediný robot, u kterého existuje mezistav trvající přes hranici mezi
     příkazy hráče, ve kterém by přepnutí nebylo bezpečné.

     Il: přepnutí je vždy bezpečné — sepnutí panelu je jednorázová akce
     bez jakéhokoli navazujícího stavu, viz Il akce 1/2 výše
     (design dokument §1.1.7).

     Net na stěně během šplhání: přepnutí je vždy bezpečné, protože
     šplhání (nahoru i dolů) se nikdy nezastaví v mezistavu viditelném
     mezi příkazy hráče — je to od začátku do konce **jeden** `STEP`,
     stejně jako klouzání po ledu (design dokument §2.1.2). Technicky: `evaluate()` ([§7.3](#73-interpret-stromu))
     smyčku `RUNNING` dořeší celou uvnitř jednoho vyhodnocení `submit_command`
     — `queue` substepů se sbírá a provede najednou, žádný z mezikroků
     nikdy nevznikne jako stav, na kterém by `WorldState` čekal na další
     vstup hráče. `is_safe_to_leave(robot)` je tedy nutné definovat jen
     pro Da; pro všechny ostatní roboty vrací triviálně `true`.

     ════════════════════════════════════════════════════════════════════ -->

### 7.7 Přímé vertikální kroky (mimo behavior tree): Da a Dul ve vodě

`STEP_UP` a `STEP_DOWN` ([§6.1](#61-příkazy)) mají vlastní klávesy a **neprochází stromem ani frontou dílčích kroků** — na rozdíl od `STEP` je to jednoduchý přímý příkaz s validací v jednom kroku (žádné `RUNNING`, žádná fronta), protože žádné výjimečné situace (šikmina, led, šplhání) tu nemohou nastat. Platí jen pro Da (kdykoli) a Dula (jen když stojí ve vodě — `water_depth_at(Vector3i.ZERO) != WaterDepth.DRY`); pro ostatní roboty a pro Dula mimo vodu je příkaz vždy `CommandRejected`.

Validace `STEP_UP` (cíl = `cell + (0,1,0)`):

- cíl uvnitř `[0, size)`,
- cíl bez robota (`robot_at`),
- cíl **není** `solid`,
- cíl **není** součástí nádrže (voda) — platí pro Da i Dula stejně: Da nesmí do vody vůbec ([§10](#10-specifikace-robotů)), Dul smí plavat vzhůru jen tehdy, dokud je pořád ve vodě, ne aby vyplaval nad hladinu tímto příkazem (vynoření řeší normální `STEP` na břeh).

Validace `STEP_DOWN` (cíl = `cell + (0,-1,0)`): stejné podmínky, jen v opačném směru — cíl uvnitř `[0, size)`, bez robota, není `solid`, a stejně tak není u Da součástí nádrže (Da nesmí do vody, ani shora). U Dula podmínka „cíl je voda" logicky platí skoro vždy (Dul se ve vodě potápí), takže jediné reálné omezení je dno nádrže (`solid`).

Obě varianty mění jen `cell.y`, orientace (`facing`) se neotáčí. Žádná z nich neprochází `GridProbe`/BT mechanismem ([§7.2](#72-gridprobe))-tyto kontroly dělá validace příkazu přímo nad `WorldState`, stejně jako u akcí ([§11](#11-akce)).

---

## 8. Gravitace a usazování

Po každé změně, která uvolní prostor pod blokem nebo předmětem, se svět usadí.

**Algoritmus.** Opakuj, dokud se něco mění (max. `MAX_SETTLE_ITERATIONS`):

1. Projdi buňky v pořadí **odspodu nahoru** (rostoucí `Y`, pak `Z`, pak `X`).
2. Pro každý blok s `falls == true`, pod kterým je `EMPTY` (a není to voda nesoucí led — led nepadá): posuň ho o jednu úroveň dolů, vydej `BlockFell`.
3. Pro každý předmět bez podpory: totéž.
4. Dopad do vody → přepočet objemu nádrže ([§9.3](#93-změna-objemu)).

Průchod odspodu nahoru zaručuje, že sloupec bloků spadne v jednom průchodu jako celek a nezůstanou mezery.

**Blok padající na robota.** Design dokument řeší tuto situaci **prevencí**: Han (akce 1), Set (akce 1) i Han (akce 2) kontrolují robota pod cílovou kostkou / v místě dopadu ještě před provedením akce. Gravitační krok proto na robota narazit nemá; pokud narazí, je to chyba v pravidlech a v debug buildu se to hlásí `assert`. Nedefinovat zde „co se stane, když blok robota přesto zavalí" je záměr — ta situace nemá vzniknout.

---

## 9. Vodní systém

Nejchoulostivější část specifikace, protože hladiny jsou z podstaty **zlomkové** (design dokument §1.1.2: „má-li zatopená oblast hladinu o rozloze pěti kostek, hladina klesne o jednu pětinu výšky kostky"). Řešení bez `float`:

### 9.1 Identifikace nádrží

Při načtení levelu (a po každé změně geometrie v editoru) se nádrže odvodí z geometrie:

1. Najdi všechny buňky, které nejsou `solid` a jsou uzavřené ze stran tak, že voda nemůže vytéct (flood-fill z každé neobsazené buňky do stran; dutina, která se dotkne bočního okraje levelu nebo jinak neuzavřené stěny, není nádrž). Dno levelu (spodní hrana mřížky, `y = 0`) se pro vodu chová jako plná zeď — nádrž tak nemusí mít vlastní podlahu z kostek, stačí, že leží na dně levelu.
2. Buňky patřící téže dutině dostanou stejný `reservoir_index`, uložený do `cell_to_reservoir`.
3. Kapacita každé buňky v jednotkách: `EMPTY` = 2, `RAMP` = 1 (šikmina zabírá půl kostky, design dokument §2.1.4). Jednotka = **půl kostky**, aby byla šikmina reprezentovatelná celým číslem.

Nádrže s příznakem `unlimited` nemění hladinu a nelze z nich čerpat (design dokument §2.2.1). Technicky: přijímají i vydávají libovolný objem, `volume_units` se u nich neaktualizuje.

### 9.2 Reprezentace hladiny

```gdscript
class_name ReservoirState extends RefCounted

var cells: Array[Vector3i]             # buňky dutiny, seřazené podle Y
var layer_capacity: Dictionary         # y -> součet capacity_units v této vrstvě
var layer_order: Array[int]            # seřazené hodnoty y odspodu
var volume_units: int                  # aktuální objem, celé číslo
var unlimited: bool
```

**Výška hladiny** se odvozuje plněním vrstev odspodu:

```gdscript
# Vrátí (y_top, remaining_units) — hladina leží uvnitř vrstvy y_top
# ve zlomkové výšce remaining_units / layer_capacity[y_top].
func surface(res: ReservoirState) -> Array:
    var left := res.volume_units
    for y in res.layer_order:
        var cap: int = res.layer_capacity[y]
        if left < cap:
            return [y, left]
        left -= cap
    return [res.layer_order[-1] + 1, 0]   # nádrž je plná až po okraj
```

Hladina se **nikdy neukládá jako číslo** — je to vždy odvozená veličina z `volume_units`. Tím je vyloučená desynchronizace mezi objemem a hladinou.

### 9.3 Změna objemu

| Operace | Změna `volume_units` |
|---|---|
| Dul — načerpání (akce 1) | `-2` (plná cisterna = 1 kostka = 2 jednotky) |
| Dul — vypuštění (akce 2) | `+2` |
| Han — vysypání korby do vody | `+2`, a zároveň buňka dopadu ztratí kapacitu³ |
| Set — roztavení ledu | `+2`, a zároveň buňka získává kapacitu `+2` — hladina beze změny¹ |
| Yeo — vytvoření ledu | buňka ztrácí kapacitu; objem beze změny¹ |
| Han — vykopání díry v mělčině | dutina získá kapacitu, hladina klesne² |
| Čerpadlo | `-N` ve zdrojové, `+N` v cílové |

¹ Zmrazením se kapacita nádrže zmenší o jednu kostku (2 jednotky) a zároveň se o stejné 2 jednotky zmenší `volume_units` — kapacita i objem klesnou 1:1, takže hladina zbytku vody zůstane přesně na místě. Buňka s `ICE` má `capacity_units = 0`. Roztavení (Set, akce 1) je přesná reverze téhož vztahu — kapacita i objem stoupnou o stejné 2 jednotky, hladina se opět nepohne; na rozdíl od vypuštění cisterny (Dul), kde kapacita zůstává a přibývá jen objem, tedy hladina tam skutečně stoupá.
² Design dokument §1.1.1: „voda ihned zaplní vyhrabanou díru a celková hladina klesne". Kapacita dutiny vzroste o 2, objem se nemění → hladina klesne sama z výpočtu. Žádný zvláštní kód.
³ Design dokument §1.1.1: vysypání se validuje před provedením — neprovede se, pokud by kostka dopadla na jiného robota, nebo do zcela plné (a ne `unlimited`) nádrže. Do `unlimited` nádrže dopadnout může vždy, `volume_units` se u ní neaktualizuje (§9.1).

Po každé změně objemu následuje přepočet hladiny a kontrola utonutí ([§9.4](#94-kontrola-utonutí)) — ale **až ve fázi validace**, ne po aplikaci: operace, která by někoho utopila, se vůbec neprovede.

### 9.4 Kontrola utonutí

Design dokument §2.1.4: žádný robot kromě Dula nesmí být tam, kde hladina přesáhne 50 % objemu dna, tj. hloubka u robota > 1/2 kostky.

Robot stojí v buňce `y_r`. Hladina je `(y_top, remaining)` s kapacitou vrstvy `cap`. Hloubka v kostkách je

```
depth = (y_top - y_r) + remaining / cap
```

Podmínka utonutí `depth > 1/2` se vyhodnotí **celočíselně** vynásobením `2 * cap`:

```gdscript
func would_drown(res: ReservoirState, robot_y: int) -> bool:
    var s := surface(res)
    var y_top: int = s[0]
    var remaining: int = s[1]
    var cap: int = res.layer_capacity.get(y_top, 1)
    # depth > 1/2  ⟺  2 * ((y_top - robot_y) * cap + remaining) > cap
    return 2 * ((y_top - robot_y) * cap + remaining) > cap
```

Žádné dělení, žádný `float`, žádná tolerance.

**Kdy se kontroluje.** Ve validaci každé operace, která zvedá hladinu: Dul akce 2, Han akce 2 (vysypání do vody), přenos čerpadlem, a rovněž při kroku robota do nádrže. Kontrolují se **všichni** roboti v dané nádrži kromě Dula.

Set roztavení ledu (akce 1) hladinu nezvedá (kapacita i objem rostou 1:1, [§9.3](#93-změna-objemu)), takže tuhle konkrétní kontrolu neprochází. Řeší ale jiné riziko: než Set kostku roztaje, ověří se, že daná kostka ledu není jediná, která nese jiné kostky ledu bez spojení s pevným podkladem (kontrola plovoucí kry, [§11](#11-akce)) — jinak by roztavením vznikl na hladině osamocený kus ledu.

**Automatická čerpadla.** Design dokument říká, že limit platí i pro vestavěná čerpadla. Čerpadlo, jehož přenos by někoho utopil, přenos **neprovede vůbec** — zastaví se celý, neprovede se ani jeho „bezpečná" část. Stejně tak Dulovo vypuštění cisterny do nádrže s jiným robotem, kde by hladina překročila limit, se neprovede.

### 9.5 Hloubka pro pohyb

```gdscript
enum WaterDepth { DRY, SHALLOW, DEEP }
```

`SHALLOW` = hloubka > 0 a ≤ 1/2 kostky (vstup povolen všem). `DEEP` = > 1/2 (jen Dul). Používá stejné celočíselné porovnání jako [§9.4](#94-kontrola-utonutí).

---

## 10. Specifikace robotů

Přepis design dokumentu §1.1 do implementovatelné tabulky. **Sloupec „hmotnost" je hmotnost samotného robota** — nesené předměty se do ní nepočítají (design dokument §1).

| Robot | Hmotnost | Inventář | Vstup do vody | Led | Akce 1 | Akce 2 |
|---|:--:|:--:|---|---|---|---|
| Han | 2 | 4 | jen `SHALLOW` | klouže | Nahrábnutí | Vysypání korby |
| Dul | 2 | 4 | `SHALLOW` i `DEEP` | klouže | Načerpání vody | Vypuštění cisterny |
| Set | 2 | 4 | jen `SHALLOW` | klouže | Zapálení | Odložení kanystru |
| Net | 2 | 4 | jen `SHALLOW` | klouže | — | Odložení předmětu |
| Da | 1 | 1 | ne | letí nad | — | Odhození předmětu |
| Yeo | 2 | 4 | jen `SHALLOW` | **chodí** | Vytvoření ledu | Odložení kanystru |
| Il | 2 | 4 | jen `SHALLOW` | klouže | Interakce/oprava | Odložení kitu |

**Zvláštní schopnosti mimo krok:**

- **Dul** — jediný smí do `DEEP`; do vody vstoupí a z vody vyleze jen tam, kde je hladina ve výšce jeho podkladu (smí být níž, ale méně než o půl kostky — design dok. §1.1.2 a §2.1.4); ve vodě se pohybuje i svisle, bez limitu ponoru.
- **Net** — šplhá po svislých stěnách; nahoru jen s ≤ 2 předměty a jen když stěna neobsahuje `ICE` a končí pevným podkladem (ne stropem); dolů bez limitu předmětů, ale pod stěnou musí být pevný podklad (ne vzduch, ne voda).
- **Da** — létá volně vodorovně i svisle; nesmí zůstat ve vzduchu při přepnutí; předmět sbírá jen shora.
- **Yeo** — po ledu chodí jako po souši, což je jediná výjimka z klouzání.

**Přepínání aktivního robota.** Sekvence je pevná a cyklická (`robot_sequence`). `SWITCH_ROBOT_NEXT` posune index; `SWITCH_ROBOT_TO` skočí přímo. Obojí validuje podmínku „robot je v bezpečí", implementovanou jako predikát `is_safe_to_leave(robot)`. Da musí stát na pevném podkladu; pro všechny ostatní roboty vrací `true` bez dalších podmínek — Il sepne panel jednorázově a nedrží si k němu žádnou vazbu (§13.1) a Net nikdy nezůstává v mezistavu šplhání mezi příkazy hráče (§7.6), takže tam žádný ekvivalent Daova letu nevzniká.

---

## 11. Akce

Každá akce je samostatná třída v `core/sim/actions/` se dvěma metodami:

```gdscript
func validate(world: WorldState, robot: int) -> Validation   # čistá, nemutuje
func apply(world: WorldState, robot: int, out_events: Array) -> void
```

Sdílené validační predikáty (jedna implementace, používá je víc akcí):

| Predikát | Použití |
|---|---|
| `has_free_space_behind(robot)` | Han a2, Set a2, Net a2, Yeo a2, Il a2 |
| `no_robot_below(cell)` | Han a1, Set a1 (dřevo) |
| `landing_cell_for_drop(cell)` | Han a2, Set/Net/Yeo/Il a2 (odložení předmětu), Da a2 — kam předmět/kostka dopadne |
| `no_robot_at(cell)` | Han a2, Set/Net/Yeo/Il a2, Da a2 (místo dopadu) |
| `raising_water_is_safe(res, units)` | Dul a2, Han a2 do vody, čerpadla |
| `has_item(robot, type)` | Set a1, Yeo a1, Il a1 (oprava) |
| `inventory_has_room(robot)` | sbírání předmětů |
| `no_floating_ice_raft(cell)` | Set a1 (led) — kostka ledu, kterou by roztavení odpojilo od pevného podkladu, viz [§7.6](#76-stromy-jednotlivých-robotů) |

Akce se **nikdy** nesmí implementovat jako mutace uprostřed validace. Toto je vynucené code review a testem, který každou akci spustí na neplatném vstupu a porovná hash stavu před/po.

---

## 12. Inventář a předměty

Design dokument §2.1.2 a §2.1.3.

```gdscript
enum ItemType { FUEL = 0, SERVICE_KIT = 1 }
```

- Kapacita: 4 předměty pro všechny roboty, **1 pro Da**.
- Sbírání je **automatické vstupem na buňku** předmětu, není to samostatná akce.
- Plný inventář → předmět se pro robota chová jako **překážka** (krok na jeho buňku selže). To musí zohlednit behavior tree kroku, ne až akce.
- **Da** sbírá jen shora: vstup na buňku předmětu shora sebere, vstup ze strany selže jako o překážku.
- **Kdo co smí sbírat:** `FUEL` → Set, Net, Da, Yeo. `SERVICE_KIT` → Net, Da, Il. Pro ostatní roboty je předmět překážkou i s prázdným inventářem.
- **Klíč** není `ItemType` — nemá hmotnost, nezabírá slot, nelze ho odložit. Je to vlastní stav `key_holder`.

---

## 13. Elektrická zařízení, plošiny, čerpadla

### 13.1 Zařízení

```gdscript
class_name DeviceState extends RefCounted
var kind: DeviceKind        # POWER_CABINET, CONTROL_UNIT
var control_mode: int       # CONTROL_UNIT: BUTTON | SWITCH
var cell: Vector3i
var access_direction: Direction   # z jaké strany se dá ovládat
var is_broken: bool
var is_on: bool
```

**Zařízení v mřížce.** Zařízení zabírá vlastní buňku, která se chová jako zeď (design dokument §2.2.1). Technicky to **není** vlastní `BlockType`: buňka nese obyčejný `WALL` a `DeviceDef`/`DeviceState` na ni odkazuje souřadnicí. Díky tomu se zařízení automaticky chová správně vůči všem pravidlům, která už se zdí počítají (průchodnost, gravitace, voda, chůze po vrchu), a nepřibývá typ bloku do formátu ani do tabulek v [§5.1](#51-typy-bloků). Editor při položení zařízení tuto zeď rovnou vytvoří a při smazání ji odebere ([§16.3](#163-nástroje-pro-mechanismy)).

Il musí stát v sousední buňce ve směru `access_direction` a být otočený k zařízení. `access_direction` je proto vždy vodorovný (validace V15, [§16.2](#162-validační-pravidla)).

Akce 1 Ila:
- zařízení `is_broken == true` a Il má `SERVICE_KIT` → oprava, kit se spotřebuje, `DeviceRepaired`; u skříně se přitom nastaví i `is_on = true` — opravená skříň je rovnou pod napětím, stejně jako skříň bez poruchy po `DeviceSystem.initialize` (design dokument §1.1.7). Samotné `is_broken = false` nestačí: `cabinets_powered` vyžaduje obojí, takže by napojené automatické čerpadlo/plošina po opravě zůstaly stát;
- zařízení `is_broken == true` a Il nemá kit → odmítnuto;
- zařízení funkční a Il stojí ve směru `access_direction` → **sepnutí zařízení** (`DeviceSystem.device_input`), viz sémantika níže. Nemá-li sepnutí co udělat, je akce odmítnutá.

Akce 2 Ila: odložení service kitu za sebe (sdílená akce `DropItem`, [§11](#11-akce)).

**Žádný „režim ovládání zařízení" neexistuje.** Jeden stisk Akce 1 = jedno sepnutí; `RobotState` si mezi příkazy nedrží žádnou vazbu na zařízení a neexistuje ani samostatný příkaz `DEVICE_INPUT` — je to jen vnitřní krok akce 1. (Dřívější návrh počítal s převzetím kontroly, zvláštním příkazem pro vstup do ovládaného zařízení a jeho opuštěním Akcí 2; to bylo z designu zrušeno jako zbytečné.)

Sémantika sepnutí:

- **Skříň (`POWER_CABINET`):** sepnutí přepne napájení (`is_on = not is_on`), `DeviceToggled`.
- **Plošina + `BUTTON`:** jednorázový přejezd do druhé polohy.
- **Plošina + `SWITCH`:** plošina jezdí střídavě do polohy A i B (přepínač).
- **Čerpadlo + `BUTTON`:** jednorázové přečerpání předem daným směrem (`default_direction`).
- **Čerpadlo + `SWITCH`:** přečerpává střídavě jedním i druhým směrem. Jedno sepnutí = jeden přenos **a** prohození zdrojové a cílové nádrže (`current_direction`), obojí najednou. Prohození je ale **důsledek provedeného přenosu**, ne samostatná akce: nesplní-li se podmínky `pump_can_transfer` (prázdný zdroj, málo místa v cíli, hrozící utonutí, skříň bez napětí), nepřečerpá se nic, směr zůstane a akce se odmítne — odmítnutý příkaz nesmí měnit stav (P5). U jednosměrného čerpadla (`bidirectional == false`) se přepínač chová jako tlačítko.

Jestli sepnutí něco udělá, závisí na stavu plošin a čerpadel napojených na zařízení. Validace akce 1 se proto ptá `DeviceSystem.device_input_validate` — čisté kontroly `platform_can_move` / `pump_can_transfer` ve stejném pořadí, v jakém pak `device_input` jednotlivé přejezdy a přenosy provádí. Neprojde-li ani jedna, je akce `CommandRejected` a stav se nezmění (P5). Protože validace nic nemutuje, je první úspěšná položka v aplikační fázi táž jako ve validační — přijatá akce tedy vždy něco udělá. Dřív bylo sepnutí zvláštní **výjimkou z dělení validace/aplikace** ([§6.2](#62-průběh-příkazu)); po zrušení režimu ovládání už výjimka není potřeba a `_apply` nemá návratovou hodnotu.

### 13.2 Transportní plošiny

Design dokument i editor používají jednotně název „transportní plošina". Plošina se může pohybovat vodorovně, svisle i diagonálně: `pose_a`/`pose_b` jsou libovolné offsety, datový model žádné omezení na „jen svisle" neklade.

```gdscript
class_name PlatformState extends RefCounted
var cells: Array[Vector3i]        # členské buňky (nemusí sousedit)
var pose_a: Vector3i              # dvě koncové polohy jako offsety (libovolný směr: vodorovně/svisle/diagonálně)
var pose_b: Vector3i
var current_pose: int             # 0 = A, 1 = B
var weight_limit: int
var linked_cabinets: Array[int]
var linked_control_units: Array[int]   # prázdné → automatická plošina
```

`weight_limit` je **spouštěcí práh**, ne horní mez nosnosti (design dokument §2.2.1): `platform_can_move` odmítne přejezd, když je náklad **menší** než práh; větší náklad plošinu nikdy nezastaví. Práh platí pro obě varianty:

- **Automatická** (jen skříň): rozjede se sama na náběžné hraně splnění prahu (`trigger_latched`); práh musí být ≥ 1 (V16), jinak by se rozjela hned na startu levelu.
- **Manuální** (skříň + řídicí jednotka): pohyb spouští hráč přes Ila; práh platí i tak (práh 0 znamená „jede i prázdná").

Hmotnost na plošině = součet hmotností robotů stojících na jejích buňkách (předměty se nepočítají, viz [§10](#10-specifikace-robotů)). Robot stojící na plošině se s ní posune.

Členské buňky jsou zdi (design dokument §2.2.1) a smí mezi nimi být i buňka se **zařízením** — to je pevnou součástí plošiny a jede s ní. `move_platform` proto kromě bloku a orientace posune i `DeviceState.cell` každého zařízení, které v převážené buňce sedí; `access_direction` se nemění (plošina se neotáčí). Zvláštní událost pro to nevzniká: zařízení je v prezentační vrstvě obyčejná zeď, kterou překreslí `PlatformMoved` ([§17.2](#172-přehrávání-událostí)).

Editor validuje, že dráha mezi `pose_a` a `pose_b` neprochází statickými objekty ani při plném vytížení (design dokument §2.2.1).

### 13.3 Čerpadla

```gdscript
class_name PumpState extends RefCounted
var reservoir_a: int
var reservoir_b: int
var bidirectional: bool
var default_direction: int
var linked_cabinets: Array[int]   # jedna i víc skříní, stejně jako u plošiny
var linked_control_unit: int      # -1 → automatické
var trigger_latched: bool         # náběžná hrana automatiky
```

Jedno sepnutí přenese **celý** obsah zdroje: `units = source.volume_units` (design dokument §2.2.1). Čerpadlo nemá pevnou velikost dávky, proto na `PumpState` žádná konstanta typu `TRANSFER_UNITS` není — dávka se počítá při každé validaci znovu. Podmínky v `pump_can_transfer`:

1. `cabinets_powered` — **všechny** napojené skříně opravené a zapnuté (tutéž funkci používá i plošina);
2. zdroj není `unlimited` (neměl by definovaný „celý obsah"; vynucuje i editor, V10);
3. `units > 0` — ve zdroji je nějaká voda (i zbytek pod celou kostkou se čerpá);
4. `target.total_capacity() - target.volume_units >= units` — volná kapacita cíle stačí na **celý** obsah zdroje; `unlimited` cíl projde vždy;
5. `raising_water_is_safe(target, units)` — přenos nikoho neutopí ([§9.4](#94-kontrola-utonutí)).

Přenos je **all-or-nothing**: nesplní-li se kterákoli podmínka, nepřečerpá se nic — ani část, která by se do cíle vešla. Stejný princip jako u kontroly utonutí; `Validation` proto nese hotové `units` a `transfer` už jen aplikuje.

**Automatické čerpadlo** (bez řídicí jednotky) sepne jednou na náběžné hraně splnění právě těchto podmínek. Ověřuje je `pump_can_transfer`, takže automatika jen sleduje náběžnou hranu jejího výsledku (`trigger_latched`) — žádná druhá, samostatně psaná sada podmínek neexistuje. Protože sepnutí zdroj vyprázdní (`volume_units == 0`), podmínka 3 hned poté sama padne a zámek se uvolní; `trigger_latched` je tak u čerpadla už jen pojistka a zabránit opakovanému sepnutí v jednom dosazení nemusí.

Přenos respektuje kontrolu utonutí ([§9.4](#94-kontrola-utonutí)). Nádrž s `unlimited` nikdy nemění hladinu, ať už se do ní čerpá, nebo se z ní čerpá. Editor nedovolí nastavit **čerpadlo** tak, aby čerpalo *z* nádrže s `unlimited` (do ní čerpat lze bez omezení) — to se vynucuje jako validační pravidlo editoru (V10, [§16.2](#162-validační-pravidla)). Toto omezení se týká jen čerpadel: **Dul** z `unlimited` nádrže čerpat smí (jeho akce 1 čerpadlem není), a stejně tak do ní smí vypustit cisternu — v obou případech se `volume_units` nádrže neaktualizuje.

---

## 14. Klíč, cíl, ukončení levelu

- V levelu je **právě jeden** klíč (design dokument §2.1.5) — validuje se při načtení i v editoru.
- Klíč se sbírá automaticky vstupem na jeho buňku; `key_holder` = index robota.
- Cíl je zpočátku **neprůchodný**. Odemkne se, když do něj vstoupí robot s klíčem → `TargetUnlocked`. Poté je průchodný pro všechny.
- Robot, který vstoupí do cíle, dostane `in_target = true` a přidá se do `finished_robots`.
- Level je dokončený, když `finished_robots.size() == robots.size()` → `LevelCompleted`.

**Robot v cíli.** Robot, který vejde do cíle, **zmizí ze scény** a hra rovnou přepne aktivního robota na dalšího v `robot_sequence`, jako by přepnutí vyvolal hráč (`ActiveRobotChanged`, viz [§6.3](#63-události)). Dokončený robot se zároveň **odstraní z `robot_sequence`** — `SWITCH_ROBOT_NEXT` i cyklické přepínání ho dál přeskakují. Robot v cíli už nijak nepomáhá ostatním, ani kdyby to level vyžadoval — hráč musí zajistit správné pořadí dokončování sám. Toto přepnutí **neprochází** kontrolou `is_safe_to_leave` ([§10](#10-specifikace-robotů)) — vstup do cíle je vždy bezpečný odchod.

**Restart** = zahození `WorldState` a nová stavba z `LevelData`. Žádný „undo". Protože je simulace deterministická a příkazy tvoří uzavřený výčet, stačilo by pro pozdější undo logovat příkazy a přehrát je od začátku — poznámka do budoucna, **není v rozsahu**.

---

## 15. Formát uložení levelu

Design dokument §2.2.2: binární, aby nešel snadno editovat mimo editor. **Toto je obfuskace, ne zabezpečení** — nespoléhej na ni jinak než jako na překážku náhodnému hrabání.

Little-endian. Chunkovaná struktura (TLV), aby šlo přidávat data bez rozbití starých souborů.

```
Hlavička (12 B):
  magic            4 B   "NCRL"
  format_version   u16   aktuálně 1
  flags            u16   rezerva, 0
  chunk_count      u32

Chunk (opakuje se chunk_count×):
  chunk_id         4 B   ASCII
  payload_length   u32
  payload          payload_length B

Patička (4 B):
  crc32            u32   CRC-32 všeho od začátku souboru po konec posledního chunku
```

| Chunk | Obsah |
|---|---|
| `DIMS` | `u16 x_len, u16 y_height, u16 z_width` |
| `BLKS` | RLE bloků v iteračním pořadí §4: opakovaně `u8 block_type, u16 model_id, u8 orientation, u16 run_length` |
| `ITEM` | `u16 count`, pak `u8 item_type, u16 x, u16 y, u16 z` |
| `KEY ` | `u16 x, u16 y, u16 z` |
| `ROBO` | `u8 count`, pak `u8 robot_kind, u16 x, u16 y, u16 z, u8 facing, u8 sequence_index` |
| `RESV` | `u16 count`, pak `u16 anchor_x, u16 anchor_y, u16 anchor_z, u32 volume_units, u8 unlimited` |
| `DEVC` | `u16 count`, pak `u8 kind, u8 control_mode, u16 x,y,z, u8 access_dir, u8 is_broken` |
| `PLAT` | `u16 count`, pak `u16 cell_count`, buňky, `pose_a`, `pose_b`, `u16 weight_limit`, seznamy vazeb |
| `PUMP` | `u16 count`, pak `u16 res_a, u16 res_b, u8 bidirectional, u8 default_dir, u16 cabinet_count`, skříně (`u16`), `i16 control_unit` |
| `META` | volitelné: název levelu, autor, čas vytvoření (UTF-8, délkově prefixované) |

**Pravidla čtečky:**

- Neznámý `chunk_id` se **přeskočí**, ne že soubor selže — dopředná kompatibilita.
- `format_version` vyšší než podporovaná → odmítnutí s čitelnou chybou.
- Nesedící `crc32` → odmítnutí (poškozený soubor).
- Po načtení běží **validace levelu** (tytéž kontroly, jaké vynucuje editor, [§16.2](#162-validační-pravidla)). Nevalidní soubor se nenačte; hra nesmí spoléhat, že data v souboru dávají smysl.

`RESV` odkazuje na nádrž kotevní buňkou, protože tvar se odvozuje z geometrie ([§9.1](#91-identifikace-nádrží)). Po flood-fillu se nádrž identifikuje jako ta, která tuto buňku obsahuje. Pokud kotevní buňka po načtení do žádné nádrže nepatří (geometrie se změnila), je soubor nevalidní.

---

## 16. Editor

### 16.1 Architektura

Editor pracuje nad **týmž `LevelData`**, které používá runtime (P6). Nemá vlastní paralelní reprezentaci světa.

```
EditorSession
├── level: LevelData            # editovaný level
├── selection: Array[Vector3i]
├── tool: EditorTool            # umísťování, mazání, výběr, tažení
├── undo_stack: Array[EditorOperation]
└── validator: LevelValidator
```

Editor **má** undo (na rozdíl od hry) — jako zásobník operací s `apply()`/`revert()`.

Náhled (`playtest`) spustí simulaci nad kopií `LevelData`; ukončení náhledu kopii zahodí a vrátí se k editaci. Editovaná data se náhledem nikdy nezmění.

### 16.2 Validační pravidla

Editor je nesmí dovolit porušit; čtečka levelu je kontroluje znovu při načtení.

| # | Pravidlo | Zdroj |
|---|---|---|
| V1 | Právě jeden klíč | design dok. §2.1.5 |
| V2 | Právě jeden cíl | odvozeno z §2.1.5 |
| V3 | 1–7 robotů, každý typ nejvýše jednou | §2.2.1 |
| V4 | Roboti jen na zemi nebo ploché zdi; Dul i ve vodě | §2.2.1 |
| V5 | Objekty (kromě zdí a šikmin) nesmí viset ve vzduchu | §2.2.1 |
| V6 | Na šikminu nelze nic umístit | §2.1.4, §2.2.1 |
| V7 | Led jen uvnitř nádrže | §2.1.4 |
| V8 | Dráha plošiny neprochází statickými objekty ani při plném vytížení | §2.2.1 |
| V9 | Každá plošina má ≥ 1 elektrickou skříň | §2.2.1 |
| V10 | Čerpadlo odkazuje na dvě různé existující nádrže a má ≥ 1 elektrickou skříň; zdrojová nádrž nesmí mít `unlimited` (cílová smí) | §2.2.1 |
| V11 | Nádrž je uzavřená dutina (neteče z ní) | odvozeno z §9.1 |
| V12 | Sekvence robotů je úplná permutace umístěných robotů | §2.1.1 |
| V13 | Počáteční objem nádrže ≤ její kapacita | odvozeno |
| V14 | Žádný robot nezačíná v hloubce `DEEP` (kromě Dula) | §2.1.4 |
| V15 | Zařízení sedí ve vlastní buňce s `WALL`, má pod sebou pevný podklad, vodorovný `access_direction`, nesdílí buňku s jiným zařízením ani robotem | §2.2.1 |
| V16 | Plošina se skládá jen ze zdí, nepřekrývá se s jinou plošinou a automatická plošina má práh ≥ 1 | §2.2.1 |
| V17 | Vazby plošin a čerpadel míří na existující zařízení správného druhu (skříň vs. řídicí jednotka) | §2.2.1 |

Zmenšení rozměrů levelu vyžaduje potvrzení a smaže zasažené objekty (design dokument §2.2.1); po smazání se validace pouští znovu. Protože se zařízení i nádrže odkazují **číslem** (plošiny, čerpadla), musí každá operace, která je odebírá, odkazy přemapovat — jinak by level zůstal nevalidní (V10, V17). Dělá to `RemoveDevice`, `RemoveReservoir` i `Resize` ([§16.3](#163-nástroje-pro-mechanismy)).

### 16.3 Nástroje pro mechanismy

Editor staví mechanismy ze [§13](#13-elektrická-zařízení-plošiny-čerpadla) přes `EditorOperation` stejně jako bloky — každá operace je vratná (undo, [§16.1](#161-architektura)).

| Nástroj / operace | Co dělá |
|---|---|
| `PlaceDevice` | položí skříň/jednotku a **současně** `WALL` do téže buňky ([§13.1](#131-zařízení)); přístupový směr je aktuální orientace nástroje (klávesa R) |
| `RemoveDevice` | odebere zařízení i jeho zeď a přečísluje vazby plošin a čerpadel |
| `SetReservoir` | označí kotevní buňku uzavřené dutiny jako nádrž a nastaví počáteční objem a `unlimited`; klik do buňky, která už do nějaké nádrže patří, jen upraví její nastavení |
| `RemoveReservoir` | odebere nádrž, přečísluje odkazy čerpadel a čerpadla, která o nádrž přišla, odstraní |
| `AddPlatform` / `RemovePlatform` | vytvoří plošinu z vybraných zdí (`pose_a = 0`, `pose_b` = posun druhé polohy), s prahem a vazbami na skříně a jednotky |
| `AddPump` / `RemovePump` | propojí dvě nádrže, nastaví obousměrnost, skříně a případnou řídicí jednotku |

Editor se na tvar nádrží ptá přes tentýž `WorldState`, jaký postaví runtime (`EditorSession.preview_world()`), takže autor levelu vidí hladinu přesně tam, kde ji uvidí hráč — hladina se nikde neukládá ([§9.2](#92-reprezentace-hladiny)). `EditorSession.cell_is_in_closed_cavity()` používá `WaterSystem.find_closed_cavities()`, aby editor odmítl založit nádrž v dutině, ze které by voda vytekla (V11).

---

## 17. Prezentační vrstva: scény, kamera, vstup, animace

### 17.1 Scény

```
Main (autoload: GameContext)
├── MainMenu
├── LevelScene
│   ├── WorldView          # instancuje uzly podle WorldState
│   ├── CameraRig
│   ├── HUD                # panel robotů, přepínání klikem
│   └── LevelController    # drží Simulation, převádí vstup na Command
└── EditorScene
```

`WorldView` staví scénu z `WorldState` **jednou** při načtení a dál ji upravuje jen podle událostí. Nikdy se nepřestavuje celá ani se nedotazuje pollingem. Bloky se renderují přes `MultiMeshInstance3D` po typech/modelech; roboti, předměty a zařízení jsou samostatné uzly.

### 17.2 Přehrávání událostí

```
Simulation.submit_command() → CommandResult.events
                                     ↓
                            EventAnimator (fronta)
                                     ↓
              Tween/AnimationPlayer, jedna událost po druhé
```

Po dobu přehrávání je vstup blokovaný (`LevelController.input_locked = true`). Blokuje se **vstup**, ne simulace — stav je už dávno finální. Hráč musí mít možnost animaci **přeskočit** (klávesa nebo rychlé opakované zadání), což jen dokončí tweeny okamžitě.

Mapování událostí na animace, orientačně:

| Událost | Animace |
|---|---|
| `RobotMoved` | posun po dráze dle `substep_code` (šikmina = plynulý sklon, svisle = šplhání/let) |
| `RobotTurned` | rotace o 90/180° |
| `BlockFell` | pád s krátkým dorazem |
| `WaterVolumeChanged` | interpolace výšky vodní hladiny (jediné místo, kde se zlomek převádí na `float`) |
| `CommandRejected` | krátký „náraz" + zvuk, robot se nehne |

### 17.3 Kamera

Design dokument §2.1.1. Dva režimy:

- **Orbitální** — sleduje aktivního robota, myš otáčí vodorovně i svisle, kolečko přibližuje. **Nesmí projít kostkou:** implementováno *sférickým dotazem po mřížce* od cíle k požadované pozici kamery — najde první buňku se `solid` blokem a kameru posadí před ni. Opět bez fyziky (P4), aby chování bylo stejné všude.
- **First person** — z pohledu robota ve směru `facing`. Přepínatelný klávesou.

Při `ActiveRobotChanged` se cíl kamery plynule přesune na nového robota.

### 17.4 Vstup

Akce v `project.godot` (všechny přemapovatelné, design dokument §2.1.2):

| Akce | Výchozí | Command |
|---|---|---|
| `turn_left` | A / ← | `TURN_LEFT` |
| `turn_right` | D / → | `TURN_RIGHT` |
| `turn_around` | S / ↓ | `TURN_AROUND` |
| `step` | W / ↑ | `STEP` |
| `step_up` | Mezerník / PageUp | `STEP_UP` |
| `step_down` | Levý Shift / PageDown | `STEP_DOWN` |
| `action_1` | Q | `ACTION_1` |
| `action_2` | E | `ACTION_2` |
| `switch_robot` | Tab | `SWITCH_ROBOT_NEXT` |
| `camera_first_person` | F | — (jen view) |
| `restart_level` | R (s potvrzením) | `RESTART_LEVEL` |

`step_up` / `step_down` jsou svislý pohyb Da (kdykoli) a Dula (jen ve vodě), viz [§7.7](#77-přímé-vertikální-kroky-mimo-behavior-tree-da-a-dul-ve-vodě). Klávesy jsou aktivní vždy — u ostatních robotů (a u Dula mimo vodu) simulace vrátí `CommandRejected` a UI zobrazí důvod; vstupní vrstva pravidla nezná (P1, P5). Ostatní roboti svislý pohyb nemají a žádnou klávesu na něj nepotřebují.

---

## 18. Testovací strategie

Protože je simulace oddělená a deterministická (P1, P2), je testovatelná **bez Godot scény**. To je hlavní praktický zisk celé architektury.

**Úrovně testů:**

1. **Jednotkové** — `water.gd` (aritmetika hladin, hraniční případy přesně na 1/2 kostky), `gravity.gd`, predikáty akcí, čtečka/zapisovač formátu (round-trip).
2. **Scénářové** — malý level postavený v kódu, sekvence příkazů, kontrola očekávaného stavu a událostí. Toto je hlavní typ testu pro pravidla robotů.
3. **Zlaté (golden)** — level ze souboru + zapsaná sekvence příkazů + očekávaný hash koncového stavu. Chytá neúmyslné změny pravidel. Determinismus dělá tenhle test smysluplným.
4. **Invariantní** — po každém příkazu ve scénářových testech se ověří I1–I8.
5. **Architektonický** — grep/parse `core/` na výskyt `extends Node`, `get_node`, `get_tree`, `randf`, `float` v simulačních cestách. Selhání = porušení P1/P2.

**Testovací fixtury.** Levely pro testy se staví přes `LevelBuilder` s textovým zápisem po vrstvách, aby byl test čitelný:

```gdscript
var level := LevelBuilder.new().layer(0, """
    WWWWW
    W...W
    W.H.W
    W...W
    WWWWW
""").layer(1, "...").build()
```

Framework: vlastní minimální runner spouštěný přes `godot --headless --script tests/run_all.gd` — méně závislostí a pro čistý GDScript bez scén plně dostačuje.

**Pravidlo:** každá mechanika dostane test **dřív**, než se napojí na vizuál. Vizuál se pak ladí proti už ověřeným pravidlům, ne současně s nimi.

---

## 19. Implementační milníky

Pořadí je navržené tak, aby každý krok šel samostatně spustit a ověřit, v souladu s [CLAUDE.md](../CLAUDE.md). Milník se nezačíná, dokud předchozí nemá testy.

| # | Milník | Hotovo, když |
|---|---|---|
| M0 | Kostra projektu: `project.godot`, adresáře, headless test runner | prázdný test projde |
| M1 | Mřížka a `LevelData`/`WorldState`, `LevelBuilder` | test postaví level a přečte buňky |
| M2 | Renderer mřížky (`WorldView`) bez interakce | statický level je vidět v 3D |
| M3 | Kamera (orbit + kolize s mřížkou + first person) | lze si level prohlédnout |
| M4 | Příkazy otáčení + přepínání robota + HUD | robot se otáčí, Tab přepíná |
| M5 | BT runtime + **první strom (Han, po rovině)** | Han udělá krok; test scénáře prochází |
| M6 | Gravitace a usazování | vykopaný sloupec spadne správně |
| M7 | Han akce 1 a 2 (bez vody) | hlínu lze přenést; kontrola robota pod kostkou |
| M8 | Vodní systém: nádrže, hladiny, `DRY`/`SHALLOW`/`DEEP`, utonutí | jednotkové testy aritmetiky |
| M9 | Dul (krok po souši i ve vodě, akce 1 a 2) | čerpání mění hladinu; utonutí se blokuje |
| M10 | Předměty a inventář | sbírání vstupem, plný inventář = překážka |
| M11 | Set, Yeo (zapálení, led) + `WOOD` | překážky lze zničit/vytvořit |
| M12 | Net (šplhání), Da (let) | limity šplhání a přistání fungují |
| M13 | Klíč, cíl, dokončení levelu | level lze dohrát |
| M14 | Elektrická zařízení, plošiny, čerpadla, Il | Il ovládá plošinu |
| M15 | Binární formát: zápis a čtení | round-trip test, level se načte ze souboru |
| M16 | Editor: umísťování, výběr, undo, validace | level lze v editoru vytvořit a uložit |
| M17 | Náhled z editoru, menu, restart | plný cyklus vytvoř → hraj |

Milníky M5, M9, M11 a M12 stojí na stromech kroku i akcí z [§7.6](#76-stromy-jednotlivých-robotů) — ty jsou specifikované v plném rozsahu, takže je lze implementovat v uvedeném pořadí bez dalších vstupů.

---

## 20. Plán implementace v0.1.0

[§19](#19-implementační-milníky) říká, **v jakém pořadí** se milníky staví. Tato kapitola říká, **co přesně je verze 0.1.0**, kdy je milník hotový, co v každém z nich vzniká za soubory a testy, a kde se plán nejspíš zadrhne.

### 20.1 Rozsah verze 0.1.0

Cíl verze: **level jde vytvořit a jde ho dohrát.** Editor je součástí hry od 0.1.0 (design dokument §2.2.2) ne jako bonus — levely oficiální hry vznikají v něm, takže bez editoru není co hrát.

| V rozsahu 0.1.0 | Mimo rozsah (0.2.0 a dál) |
|---|---|
| Všech 7 robotů, kompletní pravidla kroku i akcí ([§7.6](#76-stromy-jednotlivých-robotů), [§11](#11-akce)) | Art styl, finální modely, knihovna modelů |
| Gravitace a usazování ([§8](#8-gravitace-a-usazování)) | Zvuk |
| Vodní systém včetně utonutí ([§9](#9-vodní-systém)) | Vizuál UI a HUD nad rámec funkčnosti |
| Předměty, inventář, klíč, cíl, dokončení levelu ([§12](#12-inventář-a-předměty), [§14](#14-klíč-cíl-ukončení-levelu)) | Výběr levelů, postup hráče mezi levely |
| Elektrická zařízení, plošiny, čerpadla ([§13](#13-elektrická-zařízení-plošiny-čerpadla)) | Intro/cutscény (design dokument TODO) |
| Binární formát — čtení i zápis ([§15](#15-formát-uložení-levelu)) | Lokalizace |
| Editor včetně validace a náhledu ([§16](#16-editor)) | Undo ve hře (jen v editoru, [§14](#14-klíč-cíl-ukončení-levelu)) |
| Kamera, vstup, přehrávání událostí ([§17](#17-prezentační-vrstva-scény-kamera-vstup-animace)) | Multiplayer, cloud, statistiky |
| Headless testy dle [§18](#18-testovací-strategie) | |

**Placeholder vizuál je záměr, ne dluh.** 0.1.0 renderuje bloky jako barevné krychle a roboty jako rozlišitelné primitivy. Data už teď nesou `model_id` na buňku ([§5.2](#52-statická-data-levelu-leveldata)), takže naplnění knihovny modelů v 0.2.0 je výměna assetů, ne zásah do simulace ani do formátu.

### 20.2 Definice hotového milníku

Milník je hotový, teprve když platí **všechny** body:

1. Kód leží v adresáři podle [§3](#3-vrstvy-a-mapa-modulů) a neporušuje směr závislostí (`app/`, `editor/` → `core/`, nikdy naopak).
2. Testy pro danou mechaniku ([§18](#18-testovací-strategie)) prochází headless.
3. Architektonický test ([§18](#18-testovací-strategie), bod 5) prochází — v `core/` není `Node`, `get_tree`, náhoda ani `float`.
4. Scénářové testy milníku ověřují invarianty I1–I8 ([§5.3](#53-běhový-stav-worldstate)) po každém příkazu.
5. Co se při implementaci ukázalo jinak, než dokument říká, je v dokumentu **opravené** — chybějící *pravidlo* se doplní do design dokumentu, chybějící *postup* sem.
6. Commit obsahuje jen tento milník.

Pravidlo „test dřív než vizuál" ([§18](#18-testovací-strategie)) má tady konkrétní podobu: milníky v `core/` mají testy ve stejném commitu a jsou bez nich neúplné; milníky v `app/` a `editor/` se ověřují ručním spuštěním a povinné automatické testy nemají (výjimka: validátor editoru, [§16.2](#162-validační-pravidla), je čistá logika a testy má).

### 20.3 Etapy

Milníky se skládají do pěti etap, z nichž každá končí něčím, co jde ukázat:

| Etapa | Milníky | Demonstrovatelný výsledek |
|---|---|---|
| **E1 — Kostra a viditelný svět** | M0–M3 | Level postavený v kódu je vidět ve 3D a jde si ho prohlédnout kamerou. |
| **E2 — První robot, který se hýbe** | M4–M7 | Han chodí, otáčí se, kope a vysypává; hlína padá správně. |
| **E3 — Voda a zbytek robotů** | M8–M12 | Všech 7 robotů má kompletní pravidla kroku i akcí. |
| **E4 — Hratelný level** | M13–M15 | Level se načte ze souboru a dá se dohrát do konce. |
| **E5 — Editor** | M16–M17 | Uzavřený cyklus vytvoř → zahraj → uprav. |

**Proč vizuál (M2, M3) předbíhá pravidla, když §18 říká „test dřív než vizuál".** Rozpor v tom není. Renderer a kamera vznikají brzy jako **ladicí nástroj** — chyba v behavior tree se v 3D pohledu najde za vteřinu a v logu za půl hodiny. Pravidlo z §18 se týká **mechanik**: každá mechanika má test dřív, než se na ni vizuál napojí. E1 žádnou mechaniku neobsahuje, je to čistá infrastruktura.

### 20.4 Rozpis kroků

Sloupec „stojí na" říká, které kapitoly stačí přečíst před začátkem milníku — ne celý dokument.

| # | Vzniká | Testy | Stojí na | Stav |
|---|---|---|---|:--:|
| M0 | `project.godot`, adresáře dle §3, `tests/run_all.gd`, minimální runner | prázdný běh runneru skončí úspěchem | [§3](#3-vrstvy-a-mapa-modulů) |☑ |
| M1 | `core/grid/grid_types.gd`, `level_data.gd`, `core/sim/world_state.gd`, `tests/level_builder.gd` | `LevelBuilder` postaví level, iterační pořadí a indexace buněk sedí | [§4](#4-souřadný-systém-a-konvence-mřížky), [§5](#5-datový-model) |☑ |
| M2 | `app/scenes/level_scene.tscn`, `app/view/world_view.gd` (MultiMesh po typech) | ručně: statický level je vidět | [§17.1](#171-scény) | ☐ |
| M3 | `app/camera/` — orbit, kolize s mřížkou, first person | ručně: kamera neprojde kostkou | [§17.3](#173-kamera) | ☐ |
| M4 | `core/sim/commands.gd`, `events.gd`, `simulation.gd`, `app/input/`, HUD s panelem robotů | otáčení, `SWITCH_ROBOT_NEXT`/`_TO`, `is_safe_to_leave` | [§6](#6-simulační-jádro-tah-příkazy-události), [§10](#10-specifikace-robotů) | ☐ |
| M5 | `core/grid/grid_probe.gd`, `core/bt/bt_runtime.gd`, `bt_nodes.gd`, `trees/han.tres` | rovná chůze, obě šikminy, skluz po ledu, FAIL nad propastí na konci ledu | [§7.1](#71-dílčí-kroky)–[§7.6.0](#7600-sdílený-základ-chůze-han-set-il-dul-po-souši) |☑ |
| M6 | `core/sim/gravity.gd` | sloupec spadne v jednom průchodu; robot na vrcholu věže klesne bez zničení | [§8](#8-gravitace-a-usazování) |☑ |
| M7 | `core/sim/actions/han_dig.gd`, `han_dump.gd` | tři cíle nahrábnutí a jejich priorita, robot pod kostkou blokuje, hledání místa dopadu | [§7.6](#76-stromy-jednotlivých-robotů), [§11](#11-akce) |☑ |
| M8 | `core/sim/water.gd` — nádrže, `surface()`, `would_drown()` | aritmetika hladin, hranice **přesně** 1/2 kostky, `unlimited`, flood-fill nádrží | [§9](#9-vodní-systém) |☑ |
| M9 | `trees/dul.tres` + varianta pro plavání, `actions/dul_pump.gd`, `dul_release.gd` | čerpání mění hladinu o 2 jednotky, výběr stromu podle „je ve vodě", utonutí blokuje akci | [§7.6](#76-stromy-jednotlivých-robotů), [§9.4](#94-kontrola-utonutí) |☑ |
| M10 | Inventář a předměty v `world_state.gd` + `ahead_is_passable` | sbírání vstupem, plný inventář = překážka, kdo co smí sbírat, Da jen shora | [§12](#12-inventář-a-předměty) |☑ |
| M11 | `actions/set_burn.gd`, `yeo_freeze.gd`, `trees/set.tres`, `yeo.tres`, blok `WOOD` | priorita cílů dřeva, plovoucí kra (BFS), hladina se zmrazením/roztavením **nehne** | [§7.6](#76-stromy-jednotlivých-robotů), [§9.3](#93-změna-objemu) |☑ |
| M12 | `trees/net.tres`, `da.tres`, `STEP_UP`/`STEP_DOWN` mimo BT | limit ≤ 2 předměty nahoru, led ve zdi = FAIL, sešplhání proti sloupci za robotem, `is_safe_to_leave(Da)`, `cannot_land_cell` | [§7.6](#76-stromy-jednotlivých-robotů), [§7.7](#77-přímé-vertikální-kroky-mimo-behavior-tree-da-a-dul-ve-vodě) |☑ |
| M13 | Klíč, cíl a ukončení v `simulation.gd` | odemčení klíčem, odchod robota ze sekvence, `LevelCompleted` | [§14](#14-klíč-cíl-ukončení-levelu) |☑ |
| M14 | `core/sim/devices.gd` — skříně, jednotky, plošiny, čerpadla, akce Ila | Il ovládá plošinu, hmotnostní limit, přenos čerpadlem s kontrolou utonutí (celý, ne částečný) | [§13](#13-elektrická-zařízení-plošiny-čerpadla) |☑ |
| M15 | `core/io/level_reader.gd`, `level_writer.gd` | round-trip, přeskočení neznámého chunku, odmítnutí špatné CRC a vyšší verze, první golden test | [§15](#15-formát-uložení-levelu) |☑ |
| M16 | `editor/` — nástroje, výběr, undo, `LevelValidator` | V1–V14 headless; undo/redo vrátí přesně původní `LevelData` | [§16](#16-editor) |☑ |
| M17 | Náhled z editoru, hlavní menu, restart | ručně: vytvoř → hraj → restartuj → vrať se do editoru bez ztráty dat | [§16.1](#161-architektura), [§14](#14-klíč-cíl-ukončení-levelu) | ☐ |

Stavový sloupec se udržuje v tomto dokumentu (`☐` → `☑`), aby bylo z jediného místa vidět, co je další užitečný krok. `☑` mají milníky, jejichž kritérium ověřuje procházející headless test; M2, M3, M4 a M17 stojí na ručním spuštění hry, takže zůstávají `☐`, dokud je autor neprojde v editoru a ve hře.

**Aktuální stav.** Headless runner **běží** (`godot --headless --path game --script tests/run_all.gd`): 15 sad, 145 testů, vše prochází. Kód všech milníků M0–M16 existuje včetně testů; M16 má hotový i editorové UI včetně nástrojů na mechanismy ([§16.3](#163-nástroje-pro-mechanismy)). M17 má hotový restart i náhled z editoru, chybí plnohodnotné menu a výběr levelů.

> **Poznámka k prvnímu spuštění testů.** Runner do té doby vůbec nešel spustit — `tests/test_architecture.gd` obsahoval `sim is Node`, což GDScript odmítne už při překladu (statická analýza ví, že `Simulation` `Node` být nemůže), a padal celý soubor `run_all.gd`. Kontrola se přepsala na `is_instance_of(sim, Node)`. Poučení pro postup ([§20.6](#206-pracovní-postup)): „napsané testy" a „procházející testy" jsou dva různé stavy a milník je hotový až v tom druhém.

### 20.7 Otevřené otázky z implementace

Díry, které vyplavaly až při přepisu pravidel do kódu ([§21](#21-jak-je-tento-dokument-stavěný), bod 2). Každá má v kódu provizorní řešení a komentář; **rozhodnutí patří do design dokumentu**, ne sem.

| # | Otázka | Co dělá kód teď |
|---|---|---|
| O1 | **Hanovo vysypání do vody.** [§9.3](#93-změna-objemu) říká `+2` k objemu *a zároveň* ztrátu kapacity buňky; design dokument §1.1.1 mluví jen o ztrátě kapacity. Objem kostky se tak započítá dvakrát a hladina stoupne o dvě kostky místo jedné. | Podle §9.3 (`+2` i ztráta kapacity), protože technický design je zdroj pravdy pro implementaci. Podezření na chybu — potřebuje rozhodnout. |
| O2 | **Geometrie šikminy.** Výstup (`Emit(1)`) končí v buňce *nad* šikminou, sestup (`Emit(-1)`) končí *v* buňce šikminy — nesymetrické, a z buňky nad šikminou nešlo krokem zpět dolů. Zároveň neplatí tvrzení §7.6.0 o vzájemné výlučnosti větví — „šikmina dolů" a „rovná chůze" se překrývají, rozhoduje pořadí v `Selectoru`. | **Z větší části vyřešeno** — design dok. §2.1.4: na šikmině nelze setrvat, takže krok na ni nesmí být poslední. Obě větve šikmin vracejí `RUNNING` (režim `ramp`), krok pokračuje až na rovinu za šikminou a bez pokračování celý `FAIL`ne; kontrola v `StepEvaluator` to hlídá i pro ostatní větve. Asymetrie mezních buněk tím přestala být pozorovatelná — robot v žádné z nich nekončí. Zůstává překryv větví: pořadí v `Selectoru` je významné (šikmina dolů je před rovnou chůzí). Invariant I3 nechává výjimku pro `RAMP`, protože sonda buňkou šikminy prochází. |
| O3 | **První krok sešplhání Neta.** Kontrola „stěna za sondou" po prvním kroku přes hranu nikdy neprojde — stěna je v tu chvíli teprve *šikmo* za sondou. | Přidán predikát `behind_below_is_solid` jako alternativa k `behind_is_solid`. |
| O4 | ~~**Dulův vstup do vody a výlez z ní.**~~ Design dokument §1.1.2 to podmiňuje tím, že hladina je ve výšce podkladu, na kterém Dul stojí; §2.1.4 k tomu dává toleranci necelé půlkostky a §1.1.2 dořešilo i rozhraní s ledem. | Vyřešeno. Podmínka je v predikátech `ahead_water_is_boardable` a `here_water_is_deep`, viz [§7.6](#76-stromy-jednotlivých-robotů). Dul má proto jeden strom na souš i vodu — krok umí prostředí uprostřed změnit. |
| O5 | **Konec skluzu o překážku.** Design dokument §2.1.4 říká, že robot klouže „než narazí na překážku"; §7.3 popisuje jen konec na jiném povrchu a `FAIL` nad propastí. | Přidána větev „konec skluzu o překážku": je-li vpředu neprůchodná buňka, nashromážděná fronta se provede a robot zastaví na ledu. |
| O6 | **Splynutí nádrží za běhu.** Han může vykopat příčku mezi dvěma nádržemi. Formát i čerpadla odkazují na nádrž indexem. | Voda se slije do nádrže s nižším indexem, druhá zůstane prázdná. Chování není v žádném dokumentu. |
| O7 | ~~**Spouštění automatiky.** „Jakmile je limit splněn" nedefinuje, jestli se plošina hýbe opakovaně každý tah.~~ **Vyřešeno** — design dokument §2.2.1: náběžná hrana u plošiny i čerpadla; u čerpadla je podmínkou celý přenos (napájení, voda ve zdroji, místo v cíli, bezpečná hladina). | Náběžná hrana (`trigger_latched`) u plošin i čerpadel. |
| O8 | **Napájení elektrické skříně.** `is_on` má stav, ale žádné pravidlo neříká, co ho mění. | Skříň bez poruchy startuje zapnutá; Akce 1 Ila u funkční skříně napájení přepíná ([§13.1](#131-zařízení)). |
| O11 | ~~**Zařízení na plošině.** Zařízení je zeď plus odkaz souřadnicí ([§13.1](#131-zařízení)); `move_platform` posouvá jen blok, takže by se zařízení „odtrhlo" od své zdi.~~ **Vyřešeno** — design dokument §2.2.1: zařízení v kostce plošiny je její pevnou součástí a jede s ní. | `move_platform` posouvá i `DeviceState.cell` ([§13.2](#132-transportní-plošiny)). |
| O9 | ~~**Okraj levelu vůči vodě.**~~ [§4](#4-souřadný-systém-a-konvence-mřížky) říká, že okraj se chová jako plná zeď; [§9.1](#91-identifikace-nádrží) říkalo, že dutina dotýkající se okraje není nádrž. | Částečně vyřešeno (autorovo zadání): dno levelu (`y = 0`) se teď pro vodu chová jako okraj z §4 — plná zeď, nádrž na dně nemusí mít vlastní podlahu. Boční okraj levelu se pro vodu i nadále chová jako díra — nádrž musí mít vlastní boční stěny; ty se z geometrie odvodit nedají (za okrajem nic není). |
| O12 | **Šplhání Neta ze šikminy.** Krok na šikminu musí pokračovat dalším dílčím krokem ([O2](#207-otevřené-otázky-z-implementace)). Design dokument neříká, jestli tím pokračováním smí být Netovo vyšplhání po stěně za šikminou (resp. sešplhání do propasti za ní). | Zatím ne — obě šplhací větve jsou gatované `mode_in [""]`, takže Net na šikminu, za kterou je jen stěna nebo propast, nevstoupí. Konzervativní volba: nedomýšlet pravidlo, které v design dokumentu není. |
| O10 | **`LevelValidator` v `core/`, ne v `editor/`.** Pravidla V1–V14 potřebuje i čtečka levelu ([§15](#15-formát-uložení-levelu)), a `core/` nesmí záviset na `editor/` ([§3](#3-vrstvy-a-mapa-modulů)). | Validátor leží v `core/grid/level_validator.gd`, editor ho jen volá. |

### 20.5 Kde se plán nejspíš zadrhne

Podrobnost dokumentu kopíruje rozložení rizika; totéž platí pro pozornost při implementaci.

**M8 — voda.** Jediné místo se zlomky. Skutečné riziko není aritmetika (ta je v [§9.4](#94-kontrola-utonutí) hotová), ale to, že `layer_capacity` se **mění za běhu** — led vznikne a zmizí, Han vykope díru v mělčině. Každá změna kapacity musí vrstvy přepočítat. Pojistka je v návrhu: hladina není nikdy uložený stav ([§9.2](#92-reprezentace-hladiny)), takže chyba se projeví okamžitě v testu, ne postupným rozjížděním dvou čísel.

**M9 a M12 — stromy s `RUNNING`.** Dul (skluz po ledu do vody a z vody na led) i Net (šplhání) drží `RUNNING` napříč mnoha tiky, a Dulův krok navíc uprostřed mění prostředí. Strom se proto u obou vybírá jen podle druhu robota — výběr podle stavu by takový krok nedokončil. Riziko je nekonečná smyčka nebo fronta, která se provede jen zčásti. Pojistky jsou v [§7.3](#73-interpret-stromu): kontrakt uzlu `RUNNING` (musí přidat dílčí krok i posunout sondu) a `MAX_STEP_ITERATIONS`.

**M14 — plošiny.** ~~Jediné místo, kde se najednou pohybuje víc buněk **i s roboty na nich**, a jediné, kde se potkává pohyb s gravitací a vodou.~~ Pravidlo doplněno do design dokumentu ([§2.2.1](../docs/design-document.md#221-ovládací-panel)): dráha plošiny musí být z principu vždy prázdná (kontrola v editoru, blok v dráze tedy za běhu nemůže nastat) a hrozí-li přejezdem utonutí robota jiného než Dula, plošina se zablokuje bez ohledu na splnění ostatních podmínek spuštění. Zbývá to promítnout do implementace M14, ale interakce už není nedořešená.

**M16 — editor.** Největší objem UI práce v celé 0.1.0 a jediná část, kde headless testy nepomůžou. Zmírnění: validátor ([§16.2](#162-validační-pravidla)) je čistá logika nad `LevelData` — vzniká **před** editorovým UI a testuje se samostatně. UI pak jen volá hotová pravidla.

### 20.6 Pracovní postup

Postup vychází z druhého cíle projektu — odnést si opakovatelný způsob práce ([CLAUDE.md](../CLAUDE.md)), ne jen hotovou hru.

- **Jeden milník = jedno zadání = jeden commit.** Milník, který se nevejde do jedné rozumné dávky práce, se má rozdělit — ne rozšířit dávka.
- **Před začátkem se čtou jen kapitoly ze sloupce „stojí na".** Dokument je psaný tak, aby to stačilo; když nestačí, je to chyba dokumentu a opraví se.
- **Chybí-li pravidlo, práce se zastaví.** Doplní se design dokument, teprve pak vzniká kód. Domyšlené pravidlo je nejdražší druh chyby — vypadá jako hotová funkce.
- **Milník se nezačíná, dokud předchozí nemá testy** ([§19](#19-implementační-milníky)). Rozestavěné milníky jsou horší než pomalý postup, protože rozbité pravidlo se pak hledá ve dvou vrstvách naráz.

---

## 21. Jak je tento dokument stavěný

Tahle část není o hře, ale o metodě — protože jedním z cílů projektu je odnést si opakovatelný postup ([CLAUDE.md](../CLAUDE.md)).

**1. Technický design má jednu jasnou hranici vůči design dokumentu.** Design dokument odpovídá na *co*, technický na *jak*. Jakmile se ty dvě role smíchají, vzniká dokument, který nikdo neudržuje, protože není jasné, kdo ho smí měnit. Explicitní věta o tom, který dokument vyhrává ve sporu, ušetří spoustu pozdějších diskusí.

**2. Nevymýšlej pravidla, když ti chybí.** Nejsilnější věc, kterou technický design může udělat, je **najít díry ve specifikaci** — vzniknou tím, že se každé pravidlo zkusí přepsat do kódu a některá nejdou. Když se místo toho „domyslí", díra se ztratí a vyplave až jako bug o tři měsíce později.

**3. Pravidlo zapiš jednou a natvrdo.** Každé rozhodnutí v tomto dokumentu je formulované jako platné pravidlo, ne jako návrh k diskusi. Čtenář nemusí dohledávat, co ještě platí.

**4. Principy před detaily.** [§2](#2-architektonické-principy) je nejdůležitější kapitola. Když je princip zapsaný a očíslovaný, je na co se odvolat při code review („tohle porušuje P2") a nová rozhodnutí se dají odvodit místo vyjednávat.

**5. Architekturu volí povaha problému.** Tahle hra je deterministická, diskrétní a tahová, takže oddělení simulace od zobrazení není akademická čistota — je to to, co dělá hru testovatelnou bez scény a zlaté testy vůbec možnými. Vždycky se ptej, jakou vlastnost domény můžeš proměnit v technickou výhodu.

**6. Nejtěžší část specifikuj nejpodrobněji.** Vodní systém dostal vlastní kapitolu s konkrétní aritmetikou, protože je to jediné místo, kde design dokument implikuje zlomky. Podrobnost dokumentu má kopírovat rozložení rizika, ne rozložení textu v design dokumentu.

**7. Tabulky místo prózy, kde to jde.** Vlastnosti bloků, mapování kláves, chunky formátu — tabulka se dá číst i doplňovat a je vidět, když v ní chybí buňka.

**8. Piš pořadí implementace do dokumentu.** [§19](#19-implementační-milníky) mění spec na plán. Bez ní má člověk (i AI) tendenci začít od nejzajímavější části místo od té, na které ostatní stojí.

**9. Řekni u každého milníku, na čem stojí.** Z [§19](#19-implementační-milníky) je vidět, která kapitola musí být hotová dřív, než se milník začne. Dokument tak sám říká, co je právě teď další užitečný krok.

**10. Rozhodovací logiku drž pohromadě.** Všechny stromy kroku i akcí jsou v [§7.6](#76-stromy-jednotlivých-robotů) v jednom tvaru zápisu, takže se dají porovnávat vedle sebe a je hned vidět, co mají roboti společné a čím se liší.
