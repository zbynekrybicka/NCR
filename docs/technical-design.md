# Nature Cybernetic Robots — Technický design

Zbyněk Rybička, 2026 · Godot 4.x / GDScript

> **Vztah k design dokumentu.** [design-document.md](design-document.md) je **zdroj pravdy pro pravidla hry**. Tento dokument je zdroj pravdy pro **to, jak se ta pravidla implementují**. Kde se oba dokumenty rozejdou v otázce *co hra dělá*, vyhrává design dokument a technický design se opraví. Kde design dokument mlčí o pravidle, technický design si pravidlo **nevymýšlí** — zapíše ho do [§20 Otevřené otázky](#20-otevřené-otázky-a-mezery-v-design-dokumentu) a implementace čeká.
>
> **Stav dokumentu.** Živý, doplňuje se souběžně s vývojem. Každé rozhodnutí je označené jako **[R]** rozhodnuto / **[N]** návrh k potvrzení / **[O]** otevřené.

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
20. [Otevřené otázky a mezery v design dokumentu](#20-otevřené-otázky-a-mezery-v-design-dokumentu)
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

**P1 — Simulace je oddělená od zobrazení. [R]**
Veškerá herní logika žije v `core/` jako čisté GDScript třídy (`RefCounted`), které **nedědí z `Node`**, nesahají na `SceneTree`, nevolají `get_node()`, nepoužívají `_process()` ani fyziku. Godot vrstva simulaci pouze *řídí* (posílá příkazy) a *pozoruje* (konzumuje události). Důsledek: celou hru lze odsimulovat headless v testu bez jediné scény.

**P2 — Simulace je plně deterministická a bez plovoucí čárky. [R]**
Hra neobsahuje náhodu ani AI (design dokument §1). Stav i všechny výpočty jsou celočíselné. Objemy vody a hladiny se počítají v celých číslech s porovnáním přes křížové násobení (viz [§9](#9-vodní-systém)) — **nikdy `float`**. Plovoucí čárka existuje pouze v prezentační vrstvě (interpolace animací, kamera).

**P3 — Simulace je synchronní a atomická; animace je asynchronní. [R]**
Příkaz hráče se vyhodnotí a aplikuje celý v jednom okamžiku (nula herních snímků). Výsledkem je seznam **událostí** popisujících, co se stalo. Prezentační vrstva si tyto události přehraje v čase jako animaci. Simulace na animaci nikdy nečeká; vstup je po dobu přehrávání blokovaný na úrovni vstupní vrstvy, ne simulace.

**P4 — Dotazy na svět jdou přes mřížku, ne přes fyziku. [R]**
Design dokument mluví o „raycastech" kolem robota. Implementačně to **nejsou** Godot `RayCast3D`: kolize s fyzikálním enginem není deterministická napříč platformami a je zbytečná, když je svět diskrétní mřížka. Místo toho existuje `GridProbe` — objekt s pozicí a orientací, který čte obsah buněk přímo z datového modelu se stejnou sémantikou, jakou popisuje design dokument („kostka před robotem", „kostka pod ním", „kostka, na kterou by vstoupil"). Tuto výměnu považuj za technické rozhodnutí uvnitř mého mandátu; pokud autor trvá na skutečných raycastech, je to změna v tomto bodě.

**P5 — Robot se nemůže zničit; neplatný úkon se neprovede. [R]**
Design dokument §2.1.6. Technicky: každý příkaz má fázi **validace** oddělenou od fáze **aplikace**. Validace nesmí mutovat stav. Když validace neprojde, nemění se nic a nevzniká žádná událost kromě `CommandRejected`.

**P6 — Level je data, ne scéna. [R]**
Level nikdy není `.tscn` s ručně naskládanými uzly. Je to datová struktura načtená ze souboru (viz [§15](#15-formát-uložení-levelu)); Godot uzly pro něj vzniknou až za běhu. Díky tomu je editor a runtime tentýž kód nad týmiž daty.

**P7 — Pravidla robotů jsou data, ne rozvětvené `if`. [N]**
Chování kroku každého robota je definované behavior tree (design dokument §2.1.2), který dodá autor. Stromy se ukládají jako samostatné soubory (viz [§7.5](#75-formát-uložení-stromů)), ne jako natvrdo napsaný GDScript per robot. Cíl: autor může strom upravit bez zásahu do kódu enginu.

**P8 — Každý nevratný přechod stavu vydá událost. [R]**
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
│   │   └── trees/               # ← STROMY JEDNOTLIVÝCH ROBOTŮ (dodá autor)
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

**[R]** Level je kvádr o rozměrech `size = Vector3i(x_len, y_height, z_width)`, kde:

| Osa | Význam | Design dokument |
|---|---|---|
| `X` | délka | „délka" |
| `Y` | výška, roste vzhůru | „výška" — určuje počet úrovní a max. výšku letu Da |
| `Z` | šířka | „šířka" |

Buňky mají celočíselné souřadnice `Vector3i` v rozsahu `[0, size)`. Buňka `c` odpovídá ve světě krychli se středem `Vector3(c) * CELL_SIZE + CELL_SIZE/2`. `CELL_SIZE = 1.0`. **[R]**

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

Otočení vlevo = `(dir + 3) % 4`, vpravo = `(dir + 1) % 4`, čelem vzad = `(dir + 2) % 4`. Platí jen pro `dir < 4`. **[R]**

**Iterační pořadí buněk** (závazné pro serializaci i pro jakýkoli deterministický průchod): `X` nejrychleji, pak `Z`, pak `Y`. Index buňky `i = y * (x_len * z_width) + z * x_len + x`. **[R]**

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
    WOOD = 6,        # dřevo — hořlavé (viz §20/O-1: v design dok. nedefinováno)
    TARGET = 7,      # cíl
}
```

Vlastnosti typů jsou tabulka, ne `if`: **[R]**

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

¹ Led vytvořený Yeem je ukotvený a nepadá (design dokument §1.1.6). Design dokument ho ale zmiňuje mezi padajícími kostkami — viz [O-2](#20-otevřené-otázky-a-mezery-v-design-dokumentu).
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

Tvar nádrže se **neukládá** — odvozuje se z geometrie zdí při načtení (viz [§9.1](#91-identifikace-nádrží)). Ukládá se jen její identita (kotevní buňka), počáteční objem a příznak neomezené kapacity. **[R]**

### 5.3 Běhový stav (`WorldState`)

Vše, co se za hru mění. Restart levelu = zahodit `WorldState` a postavit ho znovu z `LevelData`. **[R]**

```gdscript
class_name WorldState extends RefCounted

var size: Vector3i
var blocks: PackedByteArray           # mutovatelná kopie
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
var controlling_device: int           # Il: index ovládaného zařízení, nebo -1
var in_target: bool
```

**Invarianty**, které musí platit po každém dokončeném příkazu (kontroluje se v debug buildu a v testech): **[R]**

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

Jediný vstup do simulace. Uzavřený výčet — nic jiného stav nemění. **[R]**

```gdscript
enum CommandType {
    TURN_LEFT, TURN_RIGHT, TURN_AROUND,
    STEP,
    ACTION_1, ACTION_2,
    SWITCH_ROBOT_NEXT,      # Tab
    SWITCH_ROBOT_TO,        # klik v UI, nese cílový index
    DEVICE_INPUT,           # vstup do zařízení, které Il právě ovládá
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

Krok 3 běží ve smyčce, dokud se svět nepřestane měnit, s tvrdým limitem iterací (`MAX_SETTLE_ITERATIONS = 256`) jako pojistkou proti chybě v pravidlech; překročení limitu je v debug buildu `assert`, v release se ustálení ukončí a zaloguje. **[R]**

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
DeviceControlTaken(robot, device)
DeviceControlReleased(robot, device)
PlatformMoved(platform, from_offset, to_offset)
PumpTransferred(pump, from_reservoir, to_reservoir, units)

# Řízení
CommandRejected(cmd, reason)
LevelCompleted()
```

Události jsou neměnné datové objekty. Pořadí v poli je pořadí, ve kterém se staly, a je závazné pro přehrání animace. **[R]**

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

Sonda nese pozici a orientaci a odpovídá na dotazy o okolí. Je to jediný způsob, jak strom čte svět. **[R]**

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

`MAX_STEP_ITERATIONS = 128` **[N]** — horní mez délky jednoho kroku hráče. Reálně ji vyčerpá jen dlouhý skluz po ledu nebo série šikmin přes celý level; smyčka bez postupu je chyba ve stromě a v debug buildu shodí `assert`.

Kontrakt uzlu `RUNNING`: uzel, který vrací `RUNNING`, **musí** přidat alespoň jeden dílčí krok do fronty a posunout sondu — jinak vzniká nekonečná smyčka. Toto vynucuje `bt_runtime.gd` kontrolou, že se délka fronty zvětšila. **[R]**

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

Predikáty pro `Condition` jsou pojmenované a registrované v jedné tabulce (`bt_nodes.gd`), aby je bylo možné referencovat ze souboru stromu jménem: `ahead_is_solid`, `below_is_solid`, `ahead_is_ramp_facing_me`, `ahead_below_is_ice`, `landing_is_safe`, `ahead_water_is_deep`, `carrying_at_most(n)`, …

### 7.5 Formát uložení stromů

**[N]** Stromy se ukládají jako Godot `Resource` (`.tres`) v `core/bt/trees/`, jeden soubor na robota (`han.tres`, `dul.tres`, …). Textový `.tres` je čitelný i v diffu a editovatelný v Godot inspektoru. Alternativa (jednodušší na ruční psaní, hůř na editaci v GUI) je malý textový DSL — rozhodnout až podle toho, jak autor stromy reálně píše.

### 7.6 Místo pro stromy — vyplní autor

Následující bloky jsou **záměrně prázdné**. Design dokument §2.1.2 říká, že konkrétní stromy dodá autor ručně; dokud tu nejsou, příslušný robot se nesmí implementovat.

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: HAN
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: DUL (po souši i ve vodě)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: SET
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: NET (včetně šplhání nahoru a dolů)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: DA (let vodorovně i svisle)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: YEO (včetně chůze po ledu bez klouzání)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     BEHAVIOR TREE — KROK: IL (včetně klouzání po ledu)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

Rozhodovací logika je potřeba i mimo krok. Design dokument §2.1.2 to zmiňuje u akcí Hana a Seta; tady je místo i pro ostatní situace, kde se autor rozhodne strom použít:

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: HAN (nahrábnutí)
     výběr cílové kostky: před / pod / šikmo dolů před
     kontrola robota pod odebíranou kostkou
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: HAN (vysypání korby)
     hledání místa dopadu za robotem, dopad do vody, kontrola utonutí
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: SET (zapálení)
     priorita cíle: vodorovně → šikmo → svisle
     kontrola robota pod ničenou kostkou
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: DUL (načerpání vody)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: DUL (vypuštění cisterny)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1: YEO (vytvoření ledové kostky)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 1/2: IL (převzetí kontroly, oprava, opuštění)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — ODLOŽENÍ PŘEDMĚTU ZA SEBE (Set, Net, Il)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — AKCE 2: DA (odhození předmětu pod sebe)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — PODMÍNKA „ROBOT JE V BEZPEČÍ" PRO PŘEPNUTÍ
     design dokument §2.1.2: zatím specifikováno jen pro Da
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

<!-- ════════════════════════════════════════════════════════════════════
     ROZHODOVACÍ STROM — VOLNÁ REZERVA (situace, které vyjdou najevo
     až při implementaci; přidávej sem další bloky stejného tvaru)
     ════════════════════════════════════════════════════════════════════
     [ VOLNÉ MÍSTO — DOPLNÍ AUTOR ]


     ════════════════════════════════════════════════════════════════════ -->

---

## 8. Gravitace a usazování

Po každé změně, která uvolní prostor pod blokem nebo předmětem, se svět usadí. **[R]**

**Algoritmus.** Opakuj, dokud se něco mění (max. `MAX_SETTLE_ITERATIONS`):

1. Projdi buňky v pořadí **odspodu nahoru** (rostoucí `Y`, pak `Z`, pak `X`).
2. Pro každý blok s `falls == true`, pod kterým je `EMPTY` (a není to voda nesoucí led — led nepadá): posuň ho o jednu úroveň dolů, vydej `BlockFell`.
3. Pro každý předmět bez podpory: totéž.
4. Dopad do vody → přepočet objemu nádrže ([§9.3](#93-změna-objemu)).

Průchod odspodu nahoru zaručuje, že sloupec bloků spadne v jednom průchodu jako celek a nezůstanou mezery. **[R]**

**Blok padající na robota.** Design dokument řeší tuto situaci **prevencí**: Han (akce 1), Set (akce 1) i Han (akce 2) kontrolují robota pod cílovou kostkou / v místě dopadu ještě před provedením akce. Gravitační krok proto na robota narazit nemá; pokud narazí, je to chyba v pravidlech a v debug buildu se to hlásí `assert`. **[R]** Nedefinovat zde „co se stane, když blok robota přesto zavalí" je záměr — ta situace nemá vzniknout.

---

## 9. Vodní systém

Nejchoulostivější část specifikace, protože hladiny jsou z podstaty **zlomkové** (design dokument §1.1.2: „má-li zatopená oblast hladinu o rozloze pěti kostek, hladina klesne o jednu pětinu výšky kostky"). Řešení bez `float`:

### 9.1 Identifikace nádrží

Při načtení levelu (a po každé změně geometrie v editoru) se nádrže odvodí z geometrie: **[R]**

1. Najdi všechny buňky, které nejsou `solid` a jsou uzavřené zdola i ze stran tak, že voda nemůže vytéct (flood-fill z každé neobsazené buňky směrem dolů a do stran; dutina, která se dotkne okraje levelu na spodní hraně nebo neuzavřené stěny, není nádrž).
2. Buňky patřící téže dutině dostanou stejný `reservoir_index`, uložený do `cell_to_reservoir`.
3. Kapacita každé buňky v jednotkách: `EMPTY` = 2, `RAMP` = 1 (šikmina zabírá půl kostky, design dokument §2.1.4). Jednotka = **půl kostky**, aby byla šikmina reprezentovatelná celým číslem. **[R]**

Nádrže s příznakem `unlimited` nemění hladinu a nelze z nich čerpat (design dokument §2.2.1). Technicky: přijímají i vydávají libovolný objem, `volume_units` se u nich neaktualizuje. **[R]**

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

Hladina se **nikdy neukládá jako číslo** — je to vždy odvozená veličina z `volume_units`. Tím je vyloučená desynchronizace mezi objemem a hladinou. **[R]**

### 9.3 Změna objemu

| Operace | Změna `volume_units` |
|---|---|
| Dul — načerpání (akce 1) | `-2` (plná cisterna = 1 kostka = 2 jednotky) |
| Dul — vypuštění (akce 2) | `+2` |
| Han — vysypání korby do vody | `+2`, a zároveň buňka dopadu ztratí kapacitu |
| Set — roztavení ledu | `+2` (design dokument §2.1.4: chová se jako vypuštění cisterny) |
| Yeo — vytvoření ledu | buňka ztrácí kapacitu; objem beze změny¹ |
| Han — vykopání díry v mělčině | dutina získá kapacitu, hladina klesne² |
| Čerpadlo | `-N` ve zdrojové, `+N` v cílové |

¹ Yeo mrazí existující vodu — objem vody se nemění, mění se skupenství. Buňka s `ICE` má `capacity_units = 0` a její obsah (2 jednotky) se odečte z `volume_units`, takže hladina zbytku zůstane na místě. **[N]** — viz [O-3](#20-otevřené-otázky-a-mezery-v-design-dokumentu).
² Design dokument §1.1.1: „voda ihned zaplní vyhrabanou díru a celková hladina klesne". Kapacita dutiny vzroste o 2, objem se nemění → hladina klesne sama z výpočtu. Žádný zvláštní kód. **[R]**

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

Žádné dělení, žádný `float`, žádná tolerance. **[R]**

**Kdy se kontroluje.** Ve validaci každé operace, která zvedá hladinu: Dul akce 2, Han akce 2 (vysypání do vody), Set roztavení ledu, přenos čerpadlem, a rovněž při kroku robota do nádrže. Kontrolují se **všichni** roboti v dané nádrži kromě Dula. **[R]**

**Automatická čerpadla.** Design dokument říká, že limit platí i pro vestavěná čerpadla. Čerpadlo, jehož přenos by někoho utopil, přenos **neprovede** (zastaví se, nezmenší dávku). **[N]** — design dokument nespecifikuje, zda se má zastavit nebo přečerpat jen část; viz [O-4](#20-otevřené-otázky-a-mezery-v-design-dokumentu).

### 9.5 Hloubka pro pohyb

```gdscript
enum WaterDepth { DRY, SHALLOW, DEEP }
```

`SHALLOW` = hloubka > 0 a ≤ 1/2 kostky (vstup povolen všem). `DEEP` = > 1/2 (jen Dul). Používá stejné celočíselné porovnání jako [§9.4](#94-kontrola-utonutí). **[R]**

---

## 10. Specifikace robotů

Přepis design dokumentu §1.1 do implementovatelné tabulky. **Sloupec „hmotnost" je hmotnost samotného robota** — nesené předměty se do ní nepočítají (design dokument §1, upraveno).

| Robot | Hmotnost | Inventář | Vstup do vody | Led | Akce 1 | Akce 2 |
|---|:--:|:--:|---|---|---|---|
| Han | 2 | 4 | jen `SHALLOW` | klouže | Nahrábnutí | Vysypání korby |
| Dul | 2 | 4 | `SHALLOW` i `DEEP` | klouže | Načerpání vody | Vypuštění cisterny |
| Set | 2 | 4 | jen `SHALLOW` | klouže | Zapálení | Odložení kanystru |
| Net | 2 | 4 | jen `SHALLOW` | klouže | — | Odložení předmětu |
| Da | 1 | 1 | ne | letí nad | — | Odhození předmětu |
| Yeo | 2 | 4 | jen `SHALLOW` | **chodí** | Vytvoření ledu | — |
| Il | 2 | 4 | jen `SHALLOW` | klouže | Interakce/oprava | Odložení kitu / opuštění |

**Zvláštní schopnosti mimo krok:**

- **Dul** — jediný smí do `DEEP`; do vody vstoupí a z vody vyleze jen tam, kde je hladina ve výšce jeho podkladu; ve vodě se pohybuje i svisle, bez limitu ponoru.
- **Net** — šplhá po svislých stěnách; nahoru jen s ≤ 2 předměty a jen když stěna neobsahuje `ICE` a končí pevným podkladem (ne stropem); dolů bez limitu předmětů, ale pod stěnou musí být pevný podklad (ne vzduch, ne voda).
- **Da** — létá volně vodorovně i svisle; nesmí zůstat ve vzduchu při přepnutí; předmět sbírá jen shora.
- **Set** — projde hořícím ohněm (viz [O-5](#20-otevřené-otázky-a-mezery-v-design-dokumentu) — oheň není v design dokumentu definovaný jako prvek).
- **Yeo** — po ledu chodí jako po souši, což je jediná výjimka z klouzání.

**Přepínání aktivního robota.** Sekvence je pevná a cyklická (`robot_sequence`). `SWITCH_ROBOT_NEXT` posune index; `SWITCH_ROBOT_TO` skočí přímo. Obojí validuje podmínku „robot je v bezpečí" — dnes definovanou jen pro Da (musí stát na pevném podkladu). Podmínka je implementovaná jako predikát `is_safe_to_leave(robot)` s jedním místem pro rozšíření, až autor doplní ostatní roboty. **[R]**

---

## 11. Akce

Každá akce je samostatná třída v `core/sim/actions/` se dvěma metodami: **[R]**

```gdscript
func validate(world: WorldState, robot: int) -> Validation   # čistá, nemutuje
func apply(world: WorldState, robot: int, out_events: Array) -> void
```

Sdílené validační predikáty (jedna implementace, používá je víc akcí):

| Predikát | Použití |
|---|---|
| `has_free_space_behind(robot)` | Han a2, Set a2, Net a2, Il a2 |
| `no_robot_below(cell)` | Han a1, Set a1 |
| `landing_cell_for_drop(cell)` | Han a2, Da a2 — kam předmět/kostka dopadne |
| `no_robot_at(cell)` | Han a2 (místo dopadu) |
| `raising_water_is_safe(res, units)` | Dul a2, Han a2 do vody, Set a1 na led, čerpadla |
| `has_item(robot, type)` | Set a1, Yeo a1, Il a1 (oprava) |
| `inventory_has_room(robot)` | sbírání předmětů |

Akce se **nikdy** nesmí implementovat jako mutace uprostřed validace. Toto je vynucené code review a testem, který každou akci spustí na neplatném vstupu a porovná hash stavu před/po. **[R]**

---

## 12. Inventář a předměty

Design dokument §2.1.2 a §2.1.3.

```gdscript
enum ItemType { FUEL = 0, SERVICE_KIT = 1 }
```

- Kapacita: 4 předměty pro všechny roboty, **1 pro Da**. **[R]**
- Sbírání je **automatické vstupem na buňku** předmětu, není to samostatná akce. **[R]**
- Plný inventář → předmět se pro robota chová jako **překážka** (krok na jeho buňku selže). To musí zohlednit behavior tree kroku, ne až akce. **[R]**
- **Da** sbírá jen shora: vstup na buňku předmětu shora sebere, vstup ze strany selže jako o překážku.
- **Kdo co smí sbírat:** `FUEL` → Set, Net, Da, Yeo. `SERVICE_KIT` → Net, Da, Il. Pro ostatní roboty je předmět překážkou i s prázdným inventářem. **[R]**
- **Klíč** není `ItemType` — nemá hmotnost, nezabírá slot, nelze ho odložit. Je to vlastní stav `key_holder`. **[R]**

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

Il musí stát v sousední buňce ve směru `access_direction` a být otočený k zařízení. **[R]**

Akce 1 Ila:
- zařízení `is_broken == true` a Il má `SERVICE_KIT` → oprava, kit se spotřebuje, `DeviceRepaired`;
- zařízení `is_broken == true` a Il nemá kit → odmítnuto;
- zařízení funkční → převzetí kontroly, `DeviceControlTaken`, `robot.controlling_device = idx`.

Akce 2 Ila:
- pokud ovládá zařízení → opuštění kontroly, `DeviceControlReleased`;
- jinak → odložení service kitu za sebe.

Během ovládání zařízení míří `DEVICE_INPUT` na zařízení, ne na robota. **Co přesně ovládání znamená pro jednotlivé typy zařízení, design dokument nespecifikuje** — viz [O-6](#20-otevřené-otázky-a-mezery-v-design-dokumentu).

### 13.2 Transportní plošiny

```gdscript
class_name PlatformState extends RefCounted
var cells: Array[Vector3i]        # členské buňky (nemusí sousedit)
var pose_a: Vector3i              # dvě koncové polohy jako offsety
var pose_b: Vector3i
var current_pose: int             # 0 = A, 1 = B
var weight_limit: int
var linked_cabinets: Array[int]
var linked_control_units: Array[int]   # prázdné → automatická plošina
```

- **Automatická** (jen skříň): jakmile je splněný hmotnostní limit, plošina se sama uvede do pohybu.
- **Manuální** (skříň + řídicí jednotka): pohyb spouští hráč přes Ila; limit platí i tak.

Hmotnost na plošině = součet hmotností robotů stojících na jejích buňkách (předměty se nepočítají, viz [§10](#10-specifikace-robotů)). Robot stojící na plošině se s ní posune. **[R]**

Editor validuje, že dráha mezi `pose_a` a `pose_b` neprochází statickými objekty ani při plném vytížení (design dokument §2.2.1).

### 13.3 Čerpadla

```gdscript
class_name PumpState extends RefCounted
var reservoir_a: int
var reservoir_b: int
var bidirectional: bool
var default_direction: int
var linked_cabinet: int
var linked_control_unit: int      # -1 → automatické
```

Přenos respektuje kontrolu utonutí ([§9.4](#94-kontrola-utonutí)). Nádrž s `unlimited` jako zdroj je nevyčerpatelná, jako cíl bezedná; z `unlimited` nádrže ale **nelze čerpat** (design dokument §2.2.1) — což je v rozporu s „nevyčerpatelným zdrojem", viz [O-7](#20-otevřené-otázky-a-mezery-v-design-dokumentu).

---

## 14. Klíč, cíl, ukončení levelu

- V levelu je **právě jeden** klíč (design dokument §2.1.5) — validuje se při načtení i v editoru. **[R]**
- Klíč se sbírá automaticky vstupem na jeho buňku; `key_holder` = index robota.
- Cíl je zpočátku **neprůchodný**. Odemkne se, když do něj vstoupí robot s klíčem → `TargetUnlocked`. Poté je průchodný pro všechny. **[R]**
- Robot, který vstoupí do cíle, dostane `in_target = true` a přidá se do `finished_robots`.
- Level je dokončený, když `finished_robots.size() == robots.size()` → `LevelCompleted`. **[R]**

**Co se s robotem v cíli stane** (zmizí ze scény? zůstane stát a blokuje? vypadne ze sekvence přepínání? kdo se stane aktivním, když do cíle vejde aktivní robot?) **design dokument neřeší** — viz [O-8](#20-otevřené-otázky-a-mezery-v-design-dokumentu). Do vyjasnění se nebude implementovat.

**Restart** = zahození `WorldState` a nová stavba z `LevelData`. Žádný „undo". Protože je simulace deterministická a příkazy tvoří uzavřený výčet, stačilo by pro pozdější undo logovat příkazy a přehrát je od začátku — poznámka do budoucna, **není v rozsahu**. **[N]**

---

## 15. Formát uložení levelu

Design dokument §2.2.2: binární, aby nešel snadno editovat mimo editor. **Toto je obfuskace, ne zabezpečení** — nespoléhej na ni jinak než jako na překážku náhodnému hrabání. **[R]**

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
| `PUMP` | `u16 count`, pak `u16 res_a, u16 res_b, u8 bidirectional, u8 default_dir, i16 cabinet, i16 control_unit` |
| `META` | volitelné: název levelu, autor, čas vytvoření (UTF-8, délkově prefixované) |

**Pravidla čtečky:** **[R]**

- Neznámý `chunk_id` se **přeskočí**, ne že soubor selže — dopředná kompatibilita.
- `format_version` vyšší než podporovaná → odmítnutí s čitelnou chybou.
- Nesedící `crc32` → odmítnutí (poškozený soubor).
- Po načtení běží **validace levelu** (tytéž kontroly, jaké vynucuje editor, [§16.2](#162-validační-pravidla)). Nevalidní soubor se nenačte; hra nesmí spoléhat, že data v souboru dávají smysl.

`RESV` odkazuje na nádrž kotevní buňkou, protože tvar se odvozuje z geometrie ([§9.1](#91-identifikace-nádrží)). Po flood-fillu se nádrž identifikuje jako ta, která tuto buňku obsahuje. Pokud kotevní buňka po načtení do žádné nádrže nepatří (geometrie se změnila), je soubor nevalidní.

---

## 16. Editor

### 16.1 Architektura

Editor pracuje nad **týmž `LevelData`**, které používá runtime (P6). Nemá vlastní paralelní reprezentaci světa. **[R]**

```
EditorSession
├── level: LevelData            # editovaný level
├── selection: Array[Vector3i]
├── tool: EditorTool            # umísťování, mazání, výběr, tažení
├── undo_stack: Array[EditorOperation]
└── validator: LevelValidator
```

Editor **má** undo (na rozdíl od hry) — jako zásobník operací s `apply()`/`revert()`. **[N]** Design dokument undo v editoru nezmiňuje, ale editor bez něj je v praxi nepoužitelný; potvrdit.

Náhled (`playtest`) spustí simulaci nad kopií `LevelData`; ukončení náhledu kopii zahodí a vrátí se k editaci. Editovaná data se náhledem nikdy nezmění. **[R]**

### 16.2 Validační pravidla

Editor je nesmí dovolit porušit; čtečka levelu je kontroluje znovu při načtení. **[R]**

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
| V10 | Čerpadlo odkazuje na dvě existující nádrže | §2.2.1 |
| V11 | Nádrž je uzavřená dutina (neteče z ní) | odvozeno z §9.1 |
| V12 | Sekvence robotů je úplná permutace umístěných robotů | §2.1.1 |
| V13 | Počáteční objem nádrže ≤ její kapacita | odvozeno |
| V14 | Žádný robot nezačíná v hloubce `DEEP` (kromě Dula) | §2.1.4 |

Zmenšení rozměrů levelu vyžaduje potvrzení a smaže zasažené objekty (design dokument §2.2.1); po smazání se validace pouští znovu.

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

`WorldView` staví scénu z `WorldState` **jednou** při načtení a dál ji upravuje jen podle událostí. Nikdy se nepřestavuje celá ani se nedotazuje pollingem. **[R]** Bloky se renderují přes `MultiMeshInstance3D` po typech/modelech; roboti, předměty a zařízení jsou samostatné uzly.

### 17.2 Přehrávání událostí

```
Simulation.submit_command() → CommandResult.events
                                     ↓
                            EventAnimator (fronta)
                                     ↓
              Tween/AnimationPlayer, jedna událost po druhé
```

Po dobu přehrávání je vstup blokovaný (`LevelController.input_locked = true`). Blokuje se **vstup**, ne simulace — stav je už dávno finální. Hráč musí mít možnost animaci **přeskočit** (klávesa nebo rychlé opakované zadání), což jen dokončí tweeny okamžitě. **[N]**

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

- **Orbitální** — sleduje aktivního robota, myš otáčí vodorovně i svisle, kolečko přibližuje. **Nesmí projít kostkou:** implementováno *sférickým dotazem po mřížce* od cíle k požadované pozici kamery — najde první buňku se `solid` blokem a kameru posadí před ni. Opět bez fyziky (P4), aby chování bylo stejné všude. **[R]**
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
| `action_1` | Q | `ACTION_1` |
| `action_2` | E | `ACTION_2` |
| `switch_robot` | Tab | `SWITCH_ROBOT_NEXT` |
| `camera_first_person` | F | — (jen view) |
| `restart_level` | R (s potvrzením) | `RESTART_LEVEL` |

**[N]** Konkrétní výchozí klávesy design dokument neurčuje; tohle je návrh.

---

## 18. Testovací strategie

Protože je simulace oddělená a deterministická (P1, P2), je testovatelná **bez Godot scény**. To je hlavní praktický zisk celé architektury.

**Úrovně testů:** **[R]**

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

**[N]** Framework: GUT, nebo vlastní minimální runner spouštěný přes `godot --headless --script tests/run_all.gd`. Vlastní runner je méně závislostí a pro čistý GDScript bez scén stačí; rozhodnout při zakládání `tests/`.

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
| M11 | Set, Yeo (oheň, led) + `WOOD` | překážky lze zničit/vytvořit |
| M12 | Net (šplhání), Da (let) | limity šplhání a přistání fungují |
| M13 | Klíč, cíl, dokončení levelu | level lze dohrát |
| M14 | Elektrická zařízení, plošiny, čerpadla, Il | Il ovládá plošinu |
| M15 | Binární formát: zápis a čtení | round-trip test, level se načte ze souboru |
| M16 | Editor: umísťování, výběr, undo, validace | level lze v editoru vytvořit a uložit |
| M17 | Náhled z editoru, menu, restart | plný cyklus vytvoř → hraj |

Milníky M5, M9, M11, M12 jsou **blokované, dokud autor nedodá příslušné behavior tree** ([§7.6](#76-místo-pro-stromy--vyplní-autor)).

---

## 20. Otevřené otázky a mezery v design dokumentu

Body, které tento dokument **nemůže rozhodnout sám**, protože jde o pravidla hry. Do jejich vyjasnění se dotčená část neimplementuje.

- **O-1 — Dřevo není definované.** Design dokument §2.1.4 vyjmenovává překážky: zeď, okraj, šikmina, hlína, kámen, led, voda. **Dřevo mezi nimi chybí**, ale zmiňuje se u Setovy akce 1 („dřevo nebo led"), v seznamu padajících kostek §1.1.1 a v synopsi („dřevěná plošina"). Potřebuje vlastní odstavec v §2.1.4: padá? jakou má nosnost? je průchodné shora?
- **O-2 — Padá led?** §1.1.1 uvádí led mezi kostkami, které mohou spadnout, ale §1.1.6 říká, že Yeův led je ukotvený a spadnout nemůže, a nově smí led existovat jen v nádrži. Může tedy led vůbec někdy padat?
- **O-3 — Co se stane s objemem vody při zmrazení.** Yeo mění vodu na led. Zmenší se tím objem vody v nádrži (led „vypadne" z bilance, hladina zbytku zůstane), nebo led v bilanci zůstává? Návrh v [§9.3](#93-změna-objemu) je jen návrh.
- **O-4 — Čerpadlo proti limitu utonutí.** Když by přenos utopil robota: zastaví se čerpadlo úplně, nebo přečerpá jen bezpečnou část? Totéž pro Dulovu cisternu (dnes: neprovede se vůbec).
- **O-5 — Oheň jako prvek.** §1.1.3 říká, že Set projde „hořícím ohněm", ale oheň není nikde definovaný jako objekt levelu (kde vzniká, jak dlouho hoří, co dělá ostatním).
- **O-6 — Co znamená „ovládat zařízení".** §1.1.7: hráč přebírá kontrolu nad zařízením. Jaké má takové zařízení vstupy? U plošiny asi „jeď do druhé polohy", u čerpadla „přečerpej", ale specifikace chybí. Souvisí s tím i význam `DEVICE_INPUT`.
- **O-7 — Neomezená nádrž jako zdroj.** §2.2.1 říká, že z nádrže s neomezenou kapacitou „nelze čerpat". Znamená to, že nemůže být zdrojem čerpadla ani pro Dula, nebo jen že se jí nemění hladina?
- **O-8 — Robot v cíli.** Zmizí ze scény, nebo zůstane stát a blokuje buňku? Vypadne ze sekvence přepínání? Kdo se stane aktivním, když do cíle vstoupí právě aktivní robot? Může robot z cíle zase vyjít?
- **O-9 — Výtah vs. transportní plošina.** Synopse a §2.1.4 mluví o „výtahu", editor o „transportních plošinách". Jde o totéž? Pokud ano, sjednotit názvosloví.
- **O-10 — Nosnost dřevěné plošiny.** Synopse říká, že dřevěná plošina se při překročení nosnosti **rozbije** (na rozdíl od výtahu, který přestane fungovat). Zničení plošiny pod robotem je ale jediná situace v celé hře, kde by mohl robot spadnout následkem cizí akce — jak se to snáší s pravidlem „robot se nemůže zničit"?
- **O-11 — Klouzání po ledu a dosud neurčené detaily.** §2.1.4 říká „klouzání = jeden krok"; §1 říká, že robot klouže, dokud nedojede na jiný povrch nebo nenarazí. To je konzistentní jen tehdy, když „jeden krok" znamená „jeden příkaz hráče" (a uvnitř běží víc dílčích kroků). Potvrdit — má to přímý dopad na tvar behavior tree.

---

## 21. Jak je tento dokument stavěný

Tahle část není o hře, ale o metodě — protože jedním z cílů projektu je odnést si opakovatelný postup ([CLAUDE.md](../CLAUDE.md)).

**1. Technický design má jednu jasnou hranici vůči design dokumentu.** Design dokument odpovídá na *co*, technický na *jak*. Jakmile se ty dvě role smíchají, vzniká dokument, který nikdo neudržuje, protože není jasné, kdo ho smí měnit. Explicitní věta o tom, který dokument vyhrává ve sporu, ušetří spoustu pozdějších diskusí.

**2. Nevymýšlej pravidla, když ti chybí.** Nejsilnější věc, kterou technický design může udělat, je **najít díry ve specifikaci** — [§20](#20-otevřené-otázky-a-mezery-v-design-dokumentu) vznikla čistě tím, že jsem se snažil každé pravidlo přepsat do kódu a některá nešla. Kdybych je „domyslel", díry by se ztratily a vyplavaly by až jako bug o tři měsíce později.

**3. Označuj status rozhodnutí.** `[R]` / `[N]` / `[O]` stojí skoro nic a okamžitě je vidět, co je dohodnuté, co čeká na potvrzení a co blokuje práci.

**4. Principy před detaily.** [§2](#2-architektonické-principy) je nejdůležitější kapitola. Když je princip zapsaný a očíslovaný, je na co se odvolat při code review („tohle porušuje P2") a nová rozhodnutí se dají odvodit místo vyjednávat.

**5. Architekturu volí povaha problému.** Tahle hra je deterministická, diskrétní a tahová, takže oddělení simulace od zobrazení není akademická čistota — je to to, co dělá hru testovatelnou bez scény a zlaté testy vůbec možnými. Vždycky se ptej, jakou vlastnost domény můžeš proměnit v technickou výhodu.

**6. Nejtěžší část specifikuj nejpodrobněji.** Vodní systém dostal vlastní kapitolu s konkrétní aritmetikou, protože je to jediné místo, kde design dokument implikuje zlomky. Podrobnost dokumentu má kopírovat rozložení rizika, ne rozložení textu v design dokumentu.

**7. Tabulky místo prózy, kde to jde.** Vlastnosti bloků, mapování kláves, chunky formátu — tabulka se dá číst i doplňovat a je vidět, když v ní chybí buňka.

**8. Piš pořadí implementace do dokumentu.** [§19](#19-implementační-milníky) mění spec na plán. Bez ní má člověk (i AI) tendenci začít od nejzajímavější části místo od té, na které ostatní stojí.

**9. Označ, co je blokované a čím.** Milníky vázané na chybějící behavior tree jsou označené. Dokument tak sám říká, co je právě teď další užitečný krok.

**10. Nech v dokumentu fyzické místo pro to, co dodá člověk.** Prázdné bloky v [§7.6](#76-místo-pro-stromy--vyplní-autor) jsou součást specifikace, ne nedodělek — je z nich vidět rozsah toho, co ještě chybí.
