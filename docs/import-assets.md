# Nature Cybernetic Robots — Import assetů

Zbyněk Rybička, 2026 · Godot 4.x / GDScript

> **Vztah k ostatním dokumentům.** [design-document.md](design-document.md) je zdroj pravdy pro **pravidla hry**, [technical-design.md](technical-design.md) pro **to, jak se implementují**. Tento dokument je návod pro **vizuální vrstvu** — jak k prvkům hry přiřadit modely, obrázky, animace a prostředí, aniž se sáhne na simulaci. Kde by si vizuál a pravidla odporovaly, vyhrává design dokument a vizuál se přizpůsobí.
>
> **Stav.** Živý. Odpovídá stavu kódu po dokončení v0.1.0 (placeholder vizuál) a popisuje cestu k 0.2.0.

## Obsah

1. [Základní pravidlo: assety nesmí sáhnout na simulaci](#1-základní-pravidlo-assety-nesmí-sáhnout-na-simulaci)
2. [Adresáře, export z Blenderu, konvence](#2-adresáře-export-z-blenderu-konvence)
3. [Modely bloků: `model_id` a knihovna modelů](#3-modely-bloků-model_id-a-knihovna-modelů)
4. [Modely robotů, předmětů a zařízení](#4-modely-robotů-předmětů-a-zařízení)
5. [2D obrázky a UI](#5-2d-obrázky-a-ui)
6. [Animace navázané na události](#6-animace-navázané-na-události)
7. [Prostředí: krajina, biotopy, umístění levelů](#7-prostředí-krajina-biotopy-umístění-levelů)
8. [Postup po krocích](#8-postup-po-krocích)
9. [Co je potřeba rozhodnout](#9-co-je-potřeba-rozhodnout)

---

## 1. Základní pravidlo: assety nesmí sáhnout na simulaci

Architektonický princip P1 ([technický design §2](technical-design.md#2-architektonické-principy)) platí pro vizuální vrstvu stejně jako pro všechno ostatní: veškerá práce s assety žije v `app/`, nikdy v `core/`. Simulace nesmí vědět, že nějaké modely existují.

**Kontrolní otázka před každou změnou:** *změní se tím posloupnost událostí, které vrátí `Simulation.submit_command()`?* Pokud ano, není to import assetu, ale změna pravidel — a ta patří nejdřív do design dokumentu.

Z toho plynou tři konkrétní pravidla:

1. **Model nesmí nést pravidlo.** Když model šikminy vypadá jinak, než jak se po ní chodí, opravuje se model, ne strom pohybu. Rozměry modelu nikdy nerozhodují o průchodnosti — o té rozhoduje `BlockType` a tabulky v [`grid_types.gd`](../game/core/grid/grid_types.gd).
2. **Animace nesmí měnit stav.** Když animace doběhne, svět je ve stavu, ve kterém už dávno byl ([§17.2](technical-design.md#172-přehrávání-událostí)). Animátor stav jen *dohrává*.
3. **Level uložený před přidáním assetů se musí hrát identicky i po něm.** `model_id` je čistě kosmetický údaj; formát souboru se kvůli vizuálu nemění.

Test `tests/test_architecture.gd` hlídá, že v `core/` není `Node`, `float` ani `get_tree()` — ten hlídá tuhle hranici automaticky a při práci s assety se nesmí obcházet.

---

## 2. Adresáře, export z Blenderu, konvence

### 2.1 Kam co patří

[Mapa modulů (§3)](technical-design.md#3-vrstvy-a-mapa-modulů) už s adresářem `assets/` počítá, zatím je prázdný. Navrhovaná struktura:

```
game/
├── assets/
│   ├── blocks/        wall_concrete.glb, dirt_grass.glb, ramp_stone.glb …
│   ├── robots/        han.glb, dul.glb, set.glb, net.glb, da.glb, yeo.glb, il.glb
│   ├── items/         fuel.glb, service_kit.glb, key.glb
│   ├── devices/       cabinet.glb, control_unit.glb, platform.glb, pump.glb
│   ├── ui/
│   │   ├── icons/     tool_wall.svg, robot_han.svg, undo.svg …
│   │   └── theme.tres
│   ├── env/
│   │   ├── biomes/    louka.tscn, poust.tscn, led.tscn …
│   │   └── sky/       *.hdr / panoramata
│   └── world_map/     landscape.glb, marker.glb
├── campaign/          campaign.json — katalog oficiálních levelů (viz §7.3)
└── app/
    ├── view/          model_library.gd, robot_view.gd, anim_timing.gd …
    ├── ui/            theme, obalové skripty nad Control uzly
    └── world_map/     scéna krajiny mezi levely
```

**Soubory `*.import` patří do gitu.** `.gitignore` ignoruje `.godot/` (to je správně — je to cache), ale metadata importu leží vedle assetu jako `wall_concrete.glb.import` a bez nich se projekt na jiném stroji naimportuje s výchozím nastavením. Commituj `.glb` i `.glb.import`.

### 2.2 Export z Blenderu

| Věc | Nastavení | Proč |
|---|---|---|
| Formát | glTF 2.0 binární (`.glb`) | jeden soubor včetně textur, Godot ho čte nativně |
| Měřítko | **1 metr v Blenderu = 1 buňka mřížky** | `CELL_SIZE = 1.0` ([§4](technical-design.md#4-souřadný-systém-a-konvence-mřížky)) |
| Osy | v exportéru nech `+Y up` (výchozí) | Godot je Y-up; Blender Z-up se převede automaticky |
| Předek modelu | v Blenderu směřuje k **−Y** | po převodu z toho bude −Z = `Direction.NORTH` ([§4](technical-design.md#4-souřadný-systém-a-konvence-mřížky)) |
| Transformace | před exportem *Apply* na rotaci i měřítko | jinak se objeví dvojitá rotace v Godotu |
| Materiály | jeden materiál na model, přiřazený na mesh data | podmínka pro `MultiMesh` (viz [§3](#3-modely-bloků-model_id-a-knihovna-modelů)) |
| Modifikátory | aplikované (nebo „Export → Apply Modifiers“) | Godot je nezná |

### 2.3 Kam patří počátek souřadnic (origin)

Tohle je nejčastější zdroj posunutých modelů, proto explicitně. `WorldView.cell_to_position()` ([world_view.gd:36](../game/app/view/world_view.gd#L36)) vrací **střed buňky**. Uzel modelu se staví právě tam, takže:

- **Bloky** — origin ve středu krychle, model vyplňuje `[-0.5, 0.5]³`.
- **Šikmina** — model uvnitř téže krychle, hmota v dolní polovině. **Stoupá ve směru své orientace**, nízká strana je na straně `-orientace` — přesně jak to čte [`is_ramp_rising_toward()`](../game/core/sim/world_state.gd#L137). Tohle není kosmetika: orientaci šikminy používá strom pohybu ([bt_nodes.gd:74](../game/core/bt/bt_nodes.gd#L74)), takže model, který stoupá jinam než data, je **lež hráči**.
- **Roboti a předměty** — model uvnitř `[-0.5, 0.5]³`, **chodidla na `y = -0.5`** (dno buňky), předek k `-Z`. Díky tomu není potřeba v kódu žádný posun.
- **Da** — vizuální vznášení nad středem buňky je čistě věc modelu/animace (idle klip), ne pozice uzlu. Pozice uzlu vždycky odpovídá buňce, jinak se rozejde s kamerou a s ostatními roboty.

### 2.4 Rozpočet a fallback

Bloků je ve scéně nejvíc a jedou přes `MultiMeshInstance3D` — u nich se vyplatí držet nízký počet trojúhelníků a jeden materiál. Roboti (max. 7 na scéně) si můžou dovolit podstatně víc.

**Každý model má fallback.** Knihovna modelů vrací `null`, když asset chybí, a `WorldView` v tom případě použije dosavadní barevnou krychli / primitivum. Díky tomu můžou assety přicházet po jednom a hra je hratelná v každém okamžiku — což je stejný postup po malých krocích jako u pravidel.

---

## 3. Modely bloků: `model_id` a knihovna modelů

### 3.1 Co už v datech je

Formát levelu **už dneska** nese `model_id` na každou buňku:

- [`LevelData.models`](../game/core/grid/level_data.gd#L12) — `PackedInt32Array`, jedna hodnota na buňku,
- chunk `BLKS` ukládá `u8 block_type, u16 model_id, u8 orientation, u16 run_length` ([§15](technical-design.md#15-formát-uložení-levelu)),
- editor ho umí zapsat ([`editor_operation.gd`](../game/editor/editor_operation.gd#L21)).

**Nikde se ale nevykresluje.** [`WorldView.refresh_blocks()`](../game/app/view/world_view.gd#L76) staví `MultiMesh` jen podle typu bloku a `model_id` i `orientation` ignoruje. Přidání modelů je tedy doplnění vykreslování, ne zásah do formátu — přesně jak slibuje [§20.1](technical-design.md#201-rozsah-verze-010).

### 3.2 Konvence `model_id`

| Hodnota | Význam |
|---|---|
| `0` | výchozí model typu bloku — **vždy existuje**, případně se dosadí varianta podle biotopu (viz [§7.4](#74-biotopy)) |
| `1…n` | konkrétní varianta vzhledu (cihla vs. beton, tráva vs. písek) |
| neznámé číslo | tiše spadne zpátky na `0`; starý soubor s novým buildem se nesmí rozbít |

Varianta **nikdy** nesmí měnit chování. Pokud potřebuješ blok, který se chová jinak, je to nový `BlockType` v [`grid_types.gd`](../game/core/grid/grid_types.gd) a změna pravidel v design dokumentu — ne nový `model_id`.

### 3.3 Knihovna modelů

Nový soubor `app/view/model_library.gd`. Tabulka, ne `if` — stejný styl jako tabulky vlastností v [§5.1](technical-design.md#51-typy-bloků).

```gdscript
class_name ModelLibrary
extends RefCounted

## Mapa (typ bloku, model_id) → Mesh pro MultiMesh. Chybějící asset vrací
## null a WorldView použije placeholder krychli (§2.4 import-assets).

const BLOCK_MODELS := {
	GridTypes.BlockType.WALL: {
		0: "res://assets/blocks/wall_concrete.glb",
		1: "res://assets/blocks/wall_brick.glb",
	},
	GridTypes.BlockType.DIRT: {
		0: "res://assets/blocks/dirt.glb",
		1: "res://assets/blocks/dirt_grass.glb",
	},
	GridTypes.BlockType.RAMP: { 0: "res://assets/blocks/ramp.glb" },
	# … zbytek typů
}

static var _cache: Dictionary = {}   # Vector2i(typ, model_id) -> Mesh

static func block_mesh(block_type: int, model_id: int) -> Mesh:
	var key := Vector2i(block_type, model_id)
	if _cache.has(key):
		return _cache[key]
	var variants: Dictionary = BLOCK_MODELS.get(block_type, {})
	var path: String = variants.get(model_id, variants.get(0, ""))
	var mesh: Mesh = _extract_mesh(path) if path != "" else null
	_cache[key] = mesh
	return mesh

## Z GLB (scéna) vytáhne jeden Mesh použitelný v MultiMesh.
static func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var root := scene.instantiate()
	var mesh: Mesh = null
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		mesh = instance.mesh
		# Materiál z importu může sedět na uzlu, ne na mesh datech — MultiMesh
		# vidí jen mesh, takže ho tam přeneseme.
		var override := instance.get_surface_override_material(0)
		if override != null and mesh != null:
			mesh.surface_set_material(0, override)
		break
	root.free()
	return mesh
```

Cache je nutná: `WorldView.build()` se volá při každém načtení levelu i restartu ([level_controller.gd:61](../game/app/level_controller.gd#L61)) a `load()` na GLB není zadarmo.

### 3.4 Vykreslování podle `model_id` a orientace

`refresh_blocks()` dnes drží jednu `MultiMeshInstance3D` na *typ*. Nově drží jednu na **dvojici (typ, model_id)** — jinak by nešly ve stejném levelu použít dvě varianty zdi. Klíčem slovníku `_block_layers` bude `Vector2i(typ, model_id)`; vrstvy se vytvářejí líně podle toho, co v levelu skutečně je (většina levelů použije jen pár kombinací).

Zároveň se konečně použije orientace:

```gdscript
var basis := Basis(Vector3.UP, WorldView.facing_to_yaw(world.orientation_at(cell)))
instance.multimesh.set_instance_transform(i,
		Transform3D(basis, cell_to_position(cell) + offset))
```

Znaménko yaw musí sedět s [`editor_view.gd:116`](../game/app/editor/editor_view.gd#L116), kde už se orientace vykresluje (a je tam s opačným znaménkem než `facing_to_yaw`). **Sjednoť to na jedno místo**, ideálně statickou funkci ve `WorldView`, kterou použije i editor — jinak bude šikmina v editoru mířit jinam než ve hře.

Posun `offset` pro šikminu (dnes `-0.25` na Y, [world_view.gd:93](../game/app/view/world_view.gd#L93)) se s reálným modelem **ruší** — model už má hmotu ve správné půlce krychle. Placeholder větev si offset ponechá.

### 3.5 Co do MultiMesh nepatří

| Do `MultiMesh` | Vlastní uzel |
|---|---|
| statické bloky bez animace, jeden materiál | plošiny (pohybují se — [§13.2](technical-design.md#132-transportní-plošiny)) |
| zeď, hlína, kámen, dřevo, led, šikmina | elektrické skříně a řídicí jednotky (mají stav zapnuto/porucha) |
| | cíl (svítí, reaguje na odemčení klíčem) |
| | padající blok během animace (viz [§6.6](#66-souběh-fronta-a-dočasné-uzly)) |

**Pozor na dnešní díru:** zařízení, plošiny, čerpadla ani **voda** se v `WorldView` nevykreslují vůbec. Hráč dnes nevidí, kde je hladina ani kde je skříň. To není chybějící asset, ale chybějící kód ve vykreslovací vrstvě — je to samostatný krok v [§8](#8-postup-po-krocích), ne „přidání modelu“.

### 3.6 Editor

[`EditorUi`](../game/app/editor/editor_ui.gd) dnes posílá jen `block_tool_selected(block_type)` a `EditorController` zapisuje `model_id = 0` natvrdo ([editor_controller.gd:121](../game/app/editor/editor_controller.gd#L121)). Až budou varianty existovat, doplní se do palety druhý řádek s variantami vybraného typu a signál dostane druhý parametr. Do té doby všechno funguje — `0` je platná hodnota.

---

## 4. Modely robotů, předmětů a zařízení

### 4.1 Struktura uzlu robota

Animátor dneska tweenuje přímo `position` a `rotation.y` uzlu, který vrátí `view.robot_node(i)` ([event_animator.gd:49](../game/app/view/event_animator.gd#L49)). Tenhle kontrakt se **zachová** — model se pověsí dovnitř:

```
RobotView (Node3D)          ← tímhle hýbe EventAnimator (pozice buňky, yaw)
└── Model (instance GLB)
    ├── Skeleton3D / MeshInstance3D
    └── AnimationPlayer     ← klipy: idle, walk, turn, dig, climb…
```

Díky obalu se animace uvnitř modelu (přešlapování, otáčení vrtulí Da) míchá s pohybem po mřížce, aniž by o sobě věděly. „Nos“ ukazující směr ([world_view.gd:110](../game/app/view/world_view.gd#L110)) se s reálným modelem zruší — model má vlastní předek.

Tabulka modelů vedle stávajících `ROBOT_COLORS`:

```gdscript
const ROBOT_MODELS := {
	GridTypes.RobotKind.HAN: "res://assets/robots/han.glb",
	GridTypes.RobotKind.DUL: "res://assets/robots/dul.glb",
	# … a tak dál; chybějící klíč nebo neexistující soubor → barevná krychle
}
```

### 4.2 Předměty a klíč

Stejný vzor, jen bez animačního stromu: `ItemType.FUEL`, `ItemType.SERVICE_KIT` a klíč dostanou model místo koule a torusu ([world_view.gd:132](../game/app/view/world_view.gd#L132)).

Jedna věc navíc: **nesený předmět**. Dnes se předmět po sebrání jen přestane kreslit (`refresh_items()` čte `world.items_on_ground`). S modely se hodí ukázat ho v inventáři robota — vizuálně na modelu (slot/držák) nebo v HUD ikonou. Je to čistě view: `RobotState.inventory` už informaci nese.

### 4.3 Zařízení a plošiny

Zařízení mají stav (`is_broken`, `is_on` — [§13.1](technical-design.md#131-zařízení)), takže potřebují vlastní uzel s materiálem reagujícím na stav (kontrolka), ne `MultiMesh`. Plošina je sada buněk, které se hýbou jako celek ([devices.gd:109](../game/core/sim/devices.gd#L109)) — jeden uzel s modelem plošiny, kterým se posouvá při `PLATFORM_MOVED`.

### 4.4 Voda

Voda je zvláštní případ: nemá blok, je to objem v nádrži ([§9](technical-design.md#9-vodní-systém)). Vizuálně to znamená **hladinový mesh na nádrž**, jehož výška se počítá ze zlomku `remaining_units / layer_capacity` — [§17.2](technical-design.md#172-přehrávání-událostí) říká, že tohle je jediné místo v celé hře, kde se celočíselný zlomek převádí na `float`, a ten převod patří do view, ne do `core/`.

Rozlišení `SHALLOW` / `DEEP` ([`WaterDepth`](../game/core/grid/grid_types.gd#L170)) je pro hráče zásadní informace (kdo se kde utopí) a musí být vidět — průhlednost, hloubka barvy, jiný odstín. To je designové rozhodnutí, ne technické (viz [§9](#9-co-je-potřeba-rozhodnout)).

---

## 5. 2D obrázky a UI

### 5.1 Formát

- **Ikony ovládacích prvků → SVG.** Godot je importuje jako textury a umí je vyrenderovat ve zvoleném měřítku (`scale` v importním docku). Hra běží v různých rozlišeních a UI je celé postavené z `Control` uzlů, takže vektor je proti PNG jasná výhra.
- **Rastrové obrázky (pozadí menu, portréty robotů) → PNG**, s `Filter` zapnutým. Kdyby art směřoval k pixel-artu, `Filter` se vypne — to je jediné podstatné importní nastavení a mělo by být pro celý projekt jednotné.
- **Nikdy nekombinuj ikony s textem v jednom obrázku** — text musí zůstat v `Label`/`Button.text` kvůli budoucí lokalizaci ([§20.1](technical-design.md#201-rozsah-verze-010) ji odkládá, ale nemá smysl si ji zavírat).

### 5.2 Jak ikony napojit na existující UI

Celé UI je dnes postavené v kódu — [`Hud`](../game/app/hud.gd), [`EditorUi`](../game/app/editor/editor_ui.gd), [`MainMenu`](../game/app/menu/main_menu.gd). Nepřepisuj to na `.tscn` kvůli vzhledu; jde to i tak, ve dvou vrstvách:

**Vrstva 1 — `Theme` pro všechno najednou.** Jeden `assets/ui/theme.tres` (fonty, barvy, pozadí tlačítek, okraje panelů) přiřazený na kořenový `Control` každé vrstvy pokryje vzhled všech tlačítek a popisků bez zásahu do logiky:

```gdscript
const UI_THEME := preload("res://assets/ui/theme.tres")

func _ready() -> void:
	var root := Control.new()
	root.theme = UI_THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# … stávající obsah se vloží do root místo přímo do CanvasLayer
```

**Vrstva 2 — ikony na konkrétní prvky.** `EditorUi` už má popisky v tabulkách (`BLOCK_LABELS` na [editor_ui.gd:24](../game/app/editor/editor_ui.gd#L24), `ITEM_LABELS` na [řádku 34](../game/app/editor/editor_ui.gd#L34), jména robotů bere z `GridTypes.ROBOT_NAMES`). Přidá se sesterská tabulka ikon a `_add_tool_button()` dostane parametr navíc:

```gdscript
const BLOCK_ICONS := {
	GridTypes.BlockType.WALL: preload("res://assets/ui/icons/tool_wall.svg"),
	GridTypes.BlockType.RAMP: preload("res://assets/ui/icons/tool_ramp.svg"),
	# …
}

func _add_tool_button(parent: Control, label: String, icon: Texture2D,
		callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.icon = icon          # null je v pořádku — zůstane jen text
	button.toggle_mode = true
	button.button_group = _tool_group
	button.pressed.connect(callback)
	parent.add_child(button)
```

`null` jako ikona je legitimní stav — opět fallback, aby šlo ikony přidávat po jedné.

### 5.3 HUD

[`Hud`](../game/app/hud.gd) je dnes jediný `Label` s pěti řádky textu. Design dokument má panel robotů s přepínáním klikem mezi otevřenými TODO a [§20.1](technical-design.md#201-rozsah-verze-010) ho odkládá na 0.2.0 — tedy právě teď. Assetově to znamená: ikona/portrét na robota, ikony na předměty v inventáři, symbol klíče a zámku cíle. Logika (kdo je aktivní, co smí) přichází z `Simulation` a v HUD se nesmí duplikovat (P5).

---

## 6. Animace navázané na události

### 6.1 Princip

Zopakujme, protože na tom stojí celá kapitola ([§17.2](technical-design.md#172-přehrávání-událostí)):

```
Simulation.submit_command() → CommandResult.events   (stav je hotový)
                                     ↓
                            EventAnimator (fronta)   (jen dohrává v čase)
                                     ↓
                        AnimationPlayer / interpolace
```

Po dobu přehrávání je blokovaný **vstup**, ne simulace. Pořadí událostí v poli je pořadí, ve kterém se staly, a je pro animaci závazné (P8).

**Důsledek pro pomalejší roboty:** zpomalení je změna jediného čísla ve view. Simulace se nezpomalí, protože žádný čas nezná.

### 6.2 Časy na jedno místo

Dneska jsou časy dvě konstanty v animátoru: `STEP_TIME := 0.14`, `TURN_TIME := 0.10` ([event_animator.gd:10](../game/app/view/event_animator.gd#L10)). To je ladicí tempo — na ladění pravidel schválně rychlé. Finální tempo bude výrazně pomalejší a bude se hodně ladit, proto patří do vlastního souboru `app/view/anim_timing.gd`:

```gdscript
class_name AnimTiming
extends RefCounted

## Jediné místo, kde se určuje tempo přehrávání událostí (§17.2). Simulace
## o čase nic neví — změna hodnot tady nemůže změnit chování hry.

## Globální násobič: 1.0 = základní tempo, 2.0 = všechno dvakrát pomaleji.
static var speed_scale: float = 1.0

## Základní doby v sekundách. 0.0 = událost se projeví okamžitě a nebere čas.
const BASE := {
	Event.EventType.ROBOT_MOVED: 0.55,
	Event.EventType.ROBOT_TURNED: 0.35,
	Event.EventType.ROBOT_ENTERED_TARGET: 0.80,
	Event.EventType.BLOCK_FELL: 0.30,
	Event.EventType.PLATFORM_MOVED: 0.70,
	Event.EventType.WATER_VOLUME_CHANGED: 0.50,
	Event.EventType.ITEM_PICKED_UP: 0.30,
	Event.EventType.ITEM_DROPPED: 0.30,
	Event.EventType.COMMAND_REJECTED: 0.20,
}

## Krok nahoru/dolů trvá jinak dlouho než rovná chůze — substep nese událost
## sama (events.gd, robot_moved).
const SUBSTEP_FACTOR := {
	GridTypes.Substep.FORWARD: 1.0,
	GridTypes.Substep.UP_RAMP: 1.3,
	GridTypes.Substep.DOWN_RAMP: 1.1,
	GridTypes.Substep.UP_VERTICAL: 1.6,
	GridTypes.Substep.DOWN_VERTICAL: 1.2,
}

static func duration(event: Event) -> float:
	var base: float = BASE.get(event.type, 0.0)
	if event.type == Event.EventType.ROBOT_MOVED:
		base *= float(SUBSTEP_FACTOR.get(int(event.data["substep"]), 1.0))
	return base * speed_scale
```

Do stejného souboru patří i `CameraRig.FOLLOW_SPEED` ([camera_rig.gd:11](../game/app/camera/camera_rig.gd#L11)) — když se roboti zpomalí čtyřikrát a kamera ne, kamera dojede na cíl dřív, než robot dojde, a scéna vypadá roztrhaně. Tempo hry patří na jedno místo.

### 6.3 Klip vs. tabulka: kdo určuje délku

Klip vyexportovaný z Blenderu má vlastní délku. Rozpor mezi ní a tabulkou se řeší **jednosměrně: autorita je tabulka**, klip se roztáhne:

```gdscript
func _play_clip(player: AnimationPlayer, clip: String, duration: float) -> void:
	if not player.has_animation(clip):
		return                                   # chybí klip → jen posun uzlu
	var length := player.get_animation(clip).length
	player.speed_scale = length / maxf(duration, 0.001)
	player.play(clip)
```

Proč takhle a ne obráceně: tempo hry je herní rozhodnutí, ne důsledek toho, kolik snímků měl někdo v Blenderu. Kdyby délku určoval klip, nešlo by zpomalit roboty bez reexportu sedmi modelů.

Praktický důsledek pro animátora v Blenderu: **kroková animace má být jeden celý krok** (od stojící pózy do stojící pózy, chodidla končí tam, kde se robot zastaví), ne nekonečná chodicí smyčka. Smyčku by šlo pouštět taky, ale při roztažení na jinou délku začnou chodidla klouzat, a hlavně by nešlo trefit konec kroku přesně do okamžiku, kdy robot dosedne do nové buňky. Smyčka se hodí jen na `idle` a na trvalé věci (vrtule Da).

Doporučení: v tabulce si drž i „přirozenou“ délku klipu, aby animátor mohl dělat animace v přirozeném tempu a `speed_scale` zůstal blízko 1.0. Extrémní roztažení (`speed_scale` pod 0.3 nebo nad 3) vypadá špatně — to je signál, že se má klip reexportovat.

### 6.4 Mapa událostí na animace

Návrh, jak co hrát. Sloupec „blokuje“ říká, jestli událost spotřebuje čas ve frontě, nebo se projeví okamžitě a fronta jede dál.

| Událost | Co se má dít | Blokuje |
|---|---|:--:|
| `ROBOT_MOVED` | posun uzlu do nové buňky + klip podle `substep`: `walk`, `walk_ramp_up/down`, `climb_up/down` (Net), `fly_up/down` (Da), `swim` (Dul ve vodě) | ano |
| `ROBOT_TURNED` | rotace o 90/180°, klip `turn_left` / `turn_right` / `turn_around` | ano |
| `ROBOT_ENTERED_TARGET` | klip `enter_target`, pak skrytí uzlu (dnes jen `visible = false`, [event_animator.gd:89](../game/app/view/event_animator.gd#L89)) | ano |
| `ACTIVE_ROBOT_CHANGED` | přesun kamery + zvýraznění nového robota; klip nemá | ne |
| `BLOCK_REMOVED` | zmizení bloku (rozpad/prach), pak `refresh_blocks()` | krátce |
| `BLOCK_PLACED` | dosednutí bloku | krátce |
| `BLOCK_FELL` | pád po dráze `from → to` s dorazem — **potřebuje dočasný uzel**, viz [§6.6](#66-souběh-fronta-a-dočasné-uzly) | ano |
| `ICE_MELTED` | přechod ledu na vodu, návaznost na hladinu | ano |
| `PLATFORM_MOVED` | posun uzlu plošiny **i robotů, kteří na ní stojí** | ano |
| `WATER_VOLUME_CHANGED` | interpolace výšky hladinového meshe (jediný převod zlomku na `float`) | ne (souběžně) |
| `ITEM_PICKED_UP` / `KEY_PICKED_UP` | předmět doletí k robotovi a zmizí | ano |
| `ITEM_DROPPED` | opačně | ano |
| `TARGET_UNLOCKED` | cíl se rozsvítí | ne |
| `DEVICE_REPAIRED` | kontrolka naskočí | ne |
| `DEVICE_TOGGLED` | přepnutí napájení skříně — změna kontrolky / polohy páky | ne |
| `PUMP_TRANSFERRED` | běh čerpadla; hladiny řeší `WATER_VOLUME_CHANGED` | ne |
| `COMMAND_REJECTED` | krátký „náraz“ robota + zvuk, žádný posun | ano |
| `LEVEL_COMPLETED` | závěrečná sekvence / návrat na mapu světa ([§7.3](#73-mapa-světa-overworld)) | ano |
| `LEVEL_RESTARTED` | scéna se staví znovu ([level_controller.gd:61](../game/app/level_controller.gd#L61)), animace se nehraje | ne |

### 6.5 Chybějící událost: akce robota

Tady je konkrétní překážka, na kterou se narazí hned u první animace kopání. `HanDig` vydá jedinou událost — `BLOCK_REMOVED(cell, DIRT)` ([han_dig.gd:49](../game/core/sim/actions/han_dig.gd#L49)). Ta neříká **kdo** kopal ani **čím**. Totéž platí pro `SetBurn`, `YeoFreeze`, `HanDump`, `DulPump`.

Z toho plyne: „Han se rozmáchne a nabere hlínu“ se z dnešního proudu událostí spolehlivě zanimovat nedá. Odvozovat aktéra z polohy odstraněného bloku vůči robotům je křehké (dva roboti vedle sebe) a hlavně by to bylo pravidlo schované ve view.

**Řešení: doplnit do `core/sim/events.gd` událost `ROBOT_ACTED`** s daty `{robot, action, target}`, kterou každá akce vydá jako *první* ve své sekvenci. Vlastnosti tohoto kroku:

- žádné pravidlo se nemění — jen se do proudu přidává informace, která tam už implicitně je;
- je to **změna v `core/`**, takže: scénářové testy porovnávající posloupnosti událostí se musí upravit, [§6.3 technického designu](technical-design.md#63-události) se musí doplnit, a patří to do vlastního commitu odděleně od assetů;
- animace akce se pak zahraje na `ROBOT_ACTED` a její důsledek (`BLOCK_REMOVED`) navazuje.

Udělej ten krok **dřív**, než začneš dělat animace akcí, ne uprostřed nich.

### 6.6 Souběh, fronta a dočasné uzly

Dnešní [`EventAnimator`](../game/app/view/event_animator.gd) má jeden slot: hraje právě jednu událost, ostatní se aplikují okamžitě a nespotřebují čas ([`_start()` vrací `false`](../game/app/view/event_animator.gd#L67)). To pro placeholder stačí; pro reálné animace potřebuje dvě rozšíření:

**1. Blokující vs. souběžné události.** Každá událost si z `AnimTiming` vezme dobu a příznak „blokuje“. Blokující se řadí za sebe, neblokující se rozjedou a nechají frontu pokračovat. Pořadí *spuštění* zůstává pořadím událostí — to je P8 a nesmí se porušit. Typický případ: robot vysype hlínu do vody, hladina stoupá souběžně s tím, jak blok dopadá.

**2. Dočasné uzly pro pohybující se bloky.** Padající blok nejde animovat v `MultiMesh` (instance se nedají rozumně tweenovat jednotlivě). Postup: při `BLOCK_FELL` se blok z `MultiMesh` odebere, vytvoří se `MeshInstance3D` s týmž meshem, ten se přesune z `from` do `to`, a po dopadu se zahodí a zavolá `refresh_blocks()`. Stejný trik pro `BLOCK_REMOVED` s rozpadem.

**3. Přeskočení musí zůstat funkční.** [`skip()`](../game/app/view/event_animator.gd#L34) dnes dokončí vše okamžitě. **Pravidlo pro každou novou animaci: musí mít definovanou koncovou pózu, kterou umí `skip()` nastavit jednou operací.** Animace, která „doběhne jen během času“, je chyba — po přeskočení by scéna nesouhlasila se stavem. Ruční test: podrž klávesu kroku, pak porovnej scénu s HUD.

### 6.7 Idle, přechody a `AnimationTree`

Jakmile bude klipů víc než pár, přejdi z ručního `AnimationPlayer.play()` na `AnimationTree` se `StateMachine` na robota:

- stav `idle` (smyčka) mezi příkazy, případně odlišný `idle_active` pro právě ovládaného robota,
- jednorázové stavy `walk`, `turn`, `dig`, … s návratem do `idle`,
- přechody s krátkým prolnutím (`xfade`), aby robot mezi kroky neškubal.

`EventAnimator` pak neříká „hraj klip X“, ale „nastav parametr přechodu na X“ — a nemusí znát strukturu modelu. Rozhraní mezi animátorem a modelem drž úzké: jedna metoda `RobotView.play_action(name: String, duration: float)`.

### 6.8 Zvuk

Mimo rozsah tohoto dokumentu, ale platí to samé: zvuk se věší na **tytéž události**, ideálně druhou tabulkou vedle `AnimTiming`. Nedělej zvuk uvnitř animačních klipů — po roztažení `speed_scale` by se rozešel.

### 6.9 Klipy, které už existují

Podle doporučení z [§6.3](#63-klip-vs-tabulka-kdo-určuje-délku) si tady drž **přirozenou délku** každého klipu, aby se dalo spočítat, jak daleko od 1.0 skončí `speed_scale`. Klipy vznikají v Blenderu ([blender/README.md](../blender/README.md), sekce Animace) a jedou s modelem v `.glb`.

| Robot | Klip | Přirozená délka | Událost | `speed_scale` při tabulkovém tempu |
|---|---|---:|---|---:|
| Da | `rotors` | 0.40 s (smyčka) | žádná — běží pořád | 1.0, neroztahuje se |
| Net | `walk` | 0.80 s | `ROBOT_MOVED`, `substep = FORWARD` (0.55 s) | 1.45 |
| Net | `turn_left` / `turn_right` | 0.67 s | `ROBOT_TURNED` o 90° (0.35 s) | 1.90 |
| Net | `turn_around` | 1.00 s | `ROBOT_TURNED` o 180° | podle tabulky |

Dvě věci, které z toho plynou:

1. **`rotors` se nesmí roztahovat.** Je to smyčka a trvalý jev, takže nepatří do fronty událostí — patří do vlastní stopy `AnimationPlayer`u (nebo do vlastní vrstvy `AnimationTree`), která běží nezávisle na tom, co robot zrovna dělá. Kdyby ji `_play_clip()` roztáhlo podle délky kroku, vrtule by při každém příkazu změnily otáčky.
2. **Netovy klipy mají `speed_scale` kolem 1.5–1.9.** To je ještě v pásmu, kde to vypadá dobře (§6.3 varuje až před 0.3 a 3.0), ale je to signál: až se doladí cílové tempo hry (otevřená otázka V4), buď se posunou hodnoty v `AnimTiming`, nebo se klipy reexportují v jiné délce. Délka klipu je v Blenderu jedno číslo v `*_spec.py` (`WALK_FRAMES`, `TURN_FRAMES`), reexport je tedy levný.

Netova chůze je stavěná tak, že **chodidla stojících nohou drží zem** — uvnitř klipu couvají přesně o tu buňku, o kterou uzel popojede. Když se změní `AnimTiming`, tenhle vztah zůstane platit, protože klip i posun uzlu se roztahují stejným číslem. Co ho ale rozbije, je posun uzlu jinou křivkou než lineární: klip počítá s rovnoměrnou jízdou z buňky do buňky. Pokud se do `EventAnimator` přidá easing, musí se stejný easing přidat i do klipu (v `anim_walk.py` je to jediná funkce `_walk_motion`).

---

## 7. Prostředí: krajina, biotopy, umístění levelů

### 7.1 Dvě různé věci

Prostředí se rozpadá na dva nezávislé úkoly a je dobré je nemíchat:

| | Co to je | Kdy je vidět |
|---|---|---|
| **A. Kulisa levelu** | okolí kvádru levelu během hraní — obloha, světlo, terén kolem, mlha | při hraní levelu |
| **B. Mapa světa** | 3D krajina s biotopy, ve které jsou oficiální levely umístěné na konkrétních místech | mezi levely, místo výběru levelu |

**Obojí je čistá dekorace.** Ani jedno nesmí ovlivnit simulaci: krajina není mřížka, po kulise se nechodí, biotop nemění pravidla. Jakmile by měl biotop měnit chování (třeba „v poušti led rychleji taje“), je to nové pravidlo do design dokumentu, ne prostředí.

### 7.2 Kulisa kolem levelu

Dnes `WorldView._add_light()` přidá holé směrové světlo ([world_view.gd:70](../game/app/view/world_view.gd#L70)) a nic víc — level visí v prázdnu.

Návrh: **biotop = scéna** v `assets/env/biomes/<jmeno>.tscn`, která obsahuje:

```
Biome (Node3D)
├── WorldEnvironment     # obloha, mlha, ambientní světlo, tonemapping
├── DirectionalLight3D   # slunce daného biotopu (úhel, barva, stíny)
├── Terrain              # dekorativní terén kolem levelu (GLB)
└── LevelAnchor (Marker3D)  # kam se posadí roh levelu (0,0,0)
```

`LevelController.setup()` ji instancuje vedle `WorldView` a světlo z `WorldView` se odstraní (přesune se do biotopu). Level se umístí tak, aby jeho počátek seděl na `LevelAnchor`.

Dvě věci, které se snadno pokazí:

- **Kulisa nesmí zasahovat do hrací mřížky.** Level je kvádr `[0, size)` a jeho rozměry jsou u každého levelu jiné ([§4](technical-design.md#4-souřadný-systém-a-konvence-mřížky)). Terén tedy nemodeluj „na míru“ jednomu levelu, ale jako okolí s dostatečným odstupem — nebo mu nech pod levelem plochou plošinu, na kterou level dosedne libovolnou velikostí.
- **Kulisa nesmí lhát o průchodnosti.** Okraj levelu je neprůchodná zeď ([§4](technical-design.md#4-souřadný-systém-a-konvence-mřížky)). Když kolem levelu plynule pokračuje rovná louka, hráč se bude oprávněně divit, proč tam robot nemůže. Okraj má číst jako útes, plošina, ostrov, propast — něco, co vysvětluje, proč se dál nedá. **Tohle je art pravidlo, ne technické, a stojí za to ho dodržet.**

### 7.3 Mapa světa (overworld)

Nová scéna, sourozenec menu / levelu / editoru. [`main.gd`](../game/app/main.gd) už má přesně tenhle vzor — drží `_menu`, `_editor`, `_play_controller` a přepíná mezi nimi, takže přibude `_world_map` a jedna větev navíc.

```
WorldMap (Node3D)
├── Landscape            # res://assets/world_map/landscape.glb (nebo víc regionů)
├── WorldEnvironment
├── MapCamera            # orbit nad krajinou, nezávislý na CameraRig levelu
└── Markers              # jeden uzel na level, pozice z katalogu
```

Krajina může být jeden velký GLB, nebo víc kusů po regionech (biotopech) — s tím, že se dají načítat po částech. Rozhodni podle velikosti; jeden GLB je jednodušší a dokud se scéna otevírá jen mezi levely, výkon nebude problém.

**Katalog levelů.** Pozice levelu v krajině **nepatří do souboru levelu**. Level je level; kde leží na mapě, v jakém je pořadí a jestli je odemčený, je vlastnost kampaně. Navíc levely vytvořené hráčem v editoru žádné místo v krajině nemají. Proto samostatný soubor `game/campaign/campaign.json`:

```json
{
  "version": 1,
  "levels": [
    {
      "id": "tutorial01",
      "path": "res://levels/tutorial01.ncr",
      "name": "První kroky",
      "biome": "louka",
      "map_position": [12.5, 3.0, -40.0],
      "requires": []
    },
    {
      "id": "tutorial02",
      "path": "res://levels/tutorial02.ncr",
      "name": "Kopání",
      "biome": "louka",
      "map_position": [18.0, 3.2, -35.5],
      "requires": ["tutorial01"]
    }
  ]
}
```

JSON, a ne binární formát: na rozdíl od levelů tenhle soubor **nemá důvod být obfuskovaný** (na obfuskaci levelů je vlastní důvod — [§15](technical-design.md#15-formát-uložení-levelu)) a ruční editace při stavbě kampaně je výhoda.

Alternativa, kterou formát dovoluje: přidat do `.ncr` chunk `BIOM` s názvem biotopu. Čtečka neznámé chunky přeskakuje ([§15](technical-design.md#15-formát-uložení-levelu)), takže je to dopředně kompatibilní. Dává to smysl jen pro biotop (ten *je* vlastnost levelu — určuje jeho kulisu). Pozice na mapě do souboru nepatří ani tak. **Doporučení: začni s biotopem v katalogu; do souboru ho přesuň, teprve až budou biotop chtít i vlastní levely hráčů.**

**Postup hráče** (které levely jsou odemčené) je podle [§20.1](technical-design.md#201-rozsah-verze-010) mimo rozsah 0.1.0. Až přijde, půjde do `user://progress.json` — tedy do uživatelských dat, ne do katalogu. Pole `requires` v katalogu jen popisuje graf závislostí; co je splněno, je běhová informace.

**Tok obrazovkami:**

```
MainMenu → WorldMap → (klik na marker) → LevelController → LEVEL_COMPLETED → WorldMap
                   ↘ Editor (vlastní levely, mimo mapu) ↗
```

### 7.4 Biotopy

Biotop je pojmenovaná sada: kulisa + osvětlení + zvuk + výchozí vzhled bloků. Tabulka ve view, stejný styl jako všude jinde:

```gdscript
const BIOMES := {
	"louka": {
		"scene": "res://assets/env/biomes/louka.tscn",
		"block_variants": {           # náhrada za model_id == 0
			GridTypes.BlockType.DIRT: 1,   # hlína s trávou
			GridTypes.BlockType.WALL: 0,
		},
	},
	"poust": {
		"scene": "res://assets/env/biomes/poust.tscn",
		"block_variants": { GridTypes.BlockType.DIRT: 2 },  # písek
	},
}
```

Tady se hezky potkává biotop s `model_id`: **`model_id == 0` znamená „vezmi výchozí variantu podle biotopu“**, cokoli jiného je explicitní volba autora levelu, kterou biotop nepřebíjí. Level tak vypadá v poušti jinak než na louce, aniž by kdokoli editoval buňky — a autor si přesto může konkrétní blok vynutit.

### 7.5 Výkon a přepínání scén

Krajina bývá řádově těžší než level. Držet obojí načtené současně nemá smysl:

- při vstupu do levelu se `WorldMap` uvolní (`queue_free()`), stejně jako to dnes dělá `main.gd` s menu ([main.gd:23](../game/app/main.gd#L23)),
- při návratu se načte znovu; pokud bude načítání znatelné, přidej mezikrok s načítací obrazovkou — ne držení scény v paměti.

---

## 8. Postup po krocích

Stejná logika jako [§20.4 technického designu](technical-design.md#204-rozpis-kroků): každý krok je samostatně ověřitelný a hra je po každém z nich hratelná. Pořadí je navržené tak, aby nejdřív vznikla *infrastruktura s fallbackem* a teprve pak se sypaly assety.

| # | Vzniká | Ověření | Stojí na | Stav |
|---|---|---|---|:--:|
| A1 | `assets/` dle [§2.1](#21-kam-co-patří), konvence exportu, první testovací blok (`WALL`) | ve hře je zeď jako model, všechno ostatní stále placeholder | [§2](#2-adresáře-export-z-blenderu-konvence) | ☐ |
| A2 | `app/view/model_library.gd`, `WorldView` vykresluje podle `model_id` **a orientace** | šikmina v levelu míří tam, kam se po ní dá vyjít; editor i hra shodně | [§3](#3-modely-bloků-model_id-a-knihovna-modelů) | ☐ |
| A3 | `app/view/robot_view.gd`, modely robotů s fallbackem, `idle` | 7 robotů má model nebo krychli, nic se nerozbije při chybějícím GLB | [§4.1](#41-struktura-uzlu-robota) | ☐ |
| A4 | `app/view/anim_timing.gd` — časy a `speed_scale` z animátoru na jedno místo, včetně kamery | `speed_scale = 3.0` zpomalí hru a **nezmění** průchod levelem | [§6.2](#62-časy-na-jedno-místo) | ☐ |
| A5 | klipy chůze/otáčení napojené na `ROBOT_MOVED` / `ROBOT_TURNED` podle `substep` | krok po šikmině vypadá jinak než rovný; přeskočení nechá scénu v koncové póze | [§6.3](#63-klip-vs-tabulka-kdo-určuje-délku), [§6.4](#64-mapa-událostí-na-animace) | ☐ |
| A6 | **`ROBOT_ACTED` v `core/sim/events.gd`** + úprava akcí, testů a [§6.3 TD](technical-design.md#63-události) | scénářové testy prochází s novou událostí; commit odděleně od assetů | [§6.5](#65-chybějící-událost-akce-robota) | ☐ |
| A7 | animace akcí (kopání, vysypání, pálení, mrazení, čerpání) | každá akce má klip a definovanou koncovou pózu | A6 | ☐ |
| A8 | souběžné události + dočasné uzly pro `BLOCK_FELL`, `PLATFORM_MOVED` | blok viditelně padá, plošina veze roboty, fronta se nezasekne | [§6.6](#66-souběh-fronta-a-dočasné-uzly) | ☐ |
| A9 | **vykreslení vody** — hladinový mesh na nádrž, `WATER_VOLUME_CHANGED` | hladina je vidět, `SHALLOW` a `DEEP` jsou rozlišitelné, stoupá plynule | [§4.4](#44-voda), [§9 TD](technical-design.md#9-vodní-systém) | ☐ |
| A10 | **vykreslení zařízení a plošin** (dnes neviditelné) | skříň, jednotka, plošina i čerpadlo jsou vidět a ukazují stav | [§4.3](#43-zařízení-a-plošiny) | ☐ |
| A11 | `assets/ui/theme.tres` + ikony v editoru a HUD | UI má jednotný vzhled, tlačítka bez ikony nepadají | [§5](#5-2d-obrázky-a-ui) | ☐ |
| A12 | HUD s panelem robotů dle design dokumentu | přepnutí robota klikem, stav inventáře a klíče je vidět bez čtení textu | [§5.3](#53-hud) | ☐ |
| A13 | kulisa levelu — biotopová scéna, světlo mimo `WorldView` | level stojí v krajině, okraj čte jako neprůchodný | [§7.2](#72-kulisa-kolem-levelu) | ☐ |
| A14 | `campaign/campaign.json`, `app/world_map/` | z mapy jde spustit level a po dokončení se vrátit zpátky | [§7.3](#73-mapa-světa-overworld) | ☐ |
| A15 | biotopové varianty bloků (`model_id == 0` → biotop) | tentýž level vypadá v poušti jinak než na louce | [§7.4](#74-biotopy) | ☐ |

**Kde se to nejspíš zadrhne:**

- **A2** — sjednocení znaménka yaw mezi hrou a editorem. Dnes se liší ([editor_view.gd:116](../game/app/editor/editor_view.gd#L116) vs. [world_view.gd:117](../game/app/view/world_view.gd#L117)) a s krychlemi to není poznat. S modely to bude poznat okamžitě.
- **A6** — jediný krok, který sahá do `core/`. Nespojuj ho s ničím jiným.
- **A9/A10** — nejsou to importy assetů, ale chybějící kód. Naplánuj je jako samostatnou práci, ne jako „dokreslení“.
- **A13** — velikost levelu je proměnná; kulisa modelovaná na jeden konkrétní level se u dalšího rozsype.

---

## 9. Co je potřeba rozhodnout

Otázky, na které tenhle dokument **nemá** odpovědět, protože jsou to designová rozhodnutí. Patří do [design dokumentu](design-document.md) (jehož TODO sekce vizuál zatím odkládá na 0.2.0 — což je právě teď).

| # | Otázka | Proč to blokuje |
|---|---|---|
| V1 | **Art styl.** Stylizace (nízkopolygonální? realistické?), paleta, čitelnost typů bloků na první pohled. | Bez toho nemá smysl modelovat první blok — každý další by se k němu musel přizpůsobovat. |
| V2 | **Vzhled a proporce robotů.** Vejde se každý do jedné buňky? Da se vznáší jak vysoko? | Určuje konvenci originu ([§2.3](#23-kam-patří-počátek-souřadnic-origin)) a čitelnost scény. |
| V3 | **Jak vypadá hluboká vs. mělká voda.** | Rozdíl rozhoduje o utonutí ([§9.4 TD](technical-design.md#94-kontrola-utonutí)); hráč ho musí poznat *před* krokem, ne po něm. |
| V4 | **Cílové tempo hry.** Kolik sekund trvá krok, otočka, akce. | Jedno číslo v `AnimTiming`, ale animace se podle něj dělají — [§6.3](#63-klip-vs-tabulka-kdo-určuje-délku). |
| V5 | **Seznam biotopů** a co který znamená vizuálně. | Bez seznamu nejde postavit krajinu ani tabulku variant bloků. |
| V6 | **Má mapa světa postup/odemykání?** Nebo jsou všechny levely dostupné hned? | Rozhoduje o `requires` v katalogu a o tom, jestli je potřeba ukládání postupu. |
| V7 | **Objevují se vlastní levely hráče na mapě?** | Pokud ano, potřebují pozici — a tím se katalog mění na něco, co zapisuje i editor. |
| V8 | **Co se stane po dokončení levelu.** Návrat na mapu? Animace? Další level? | Určuje obsluhu `LEVEL_COMPLETED` ([§6.4](#64-mapa-událostí-na-animace)). |

Zbytek — konkrétní modely, textury, ikony — jsou už jen assety a dají se přidávat po jednom, protože každý má fallback.
