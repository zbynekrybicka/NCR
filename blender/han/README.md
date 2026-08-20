# Han — Blender stavebnice

Skripty v `bpy`, které postaví robota **Han** (zemní, hnědá) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §1.

Každý díl je samostatný soubor a jde spustit zvlášť — postaví jen svou část.
`build_han.py` spustí všechny a složí je do hierarchie. Ověřeno na
**Blenderu 4.2 LTS**.

## Jak to spustit

**V Blenderu (Text Editor).** `Text ▸ Open` a otevřít všechny soubory ze
složky `blender/han/` **i z `blender/common/`** (skripty se navzájem
importují a hledají se přes cestu otevřeného textového bloku). Pak stačí
spustit ten, který chceš:

- `build_han.py` → celý robot
- `part_03_hull.py` → jen trup, atd.

**Z příkazové řádky.**

```
blender --background --factory-startup --python blender/han/build_han.py
```

Vynechání `--background` otevře Blender s hotovým modelem.

Skripty jsou **idempotentní**: každý díl na začátku smaže své objekty podle
prefixu, takže se dají pouštět opakovaně a nic se nevrší.

## Soubory

| Soubor | Co postaví |
|---|---|
| `han_spec.py` | **výkres**: všechny rozměry a attachment pointy Hana. Jediné místo na ladění proporcí. |
| [`../common/ncr_common.py`](../common/ncr_common.py) | knihovna — konvence, materiály, primitiva, boolean/bevel/join. Nespouští se. |
| [`../common/part_00_core.py`](../common/part_00_core.py) | jádro (spec §0.1) — 2 polokoule, šev, 14 nýtů, nápis v hangulu. Parametrizované jménem robota, použitelné pro všech 7. |
| `part_01_chassis.py` | rám mezi pásy, blatník/paluba, tažný hák |
| `part_02_tracks.py` | pásy s ostruhami, hnací řetězky, napínací a pojezdová kola |
| `part_03_hull.py` | trup se zkosenou přídí, motorová paluba, krk jádra, výfuk |
| `part_04_arm.py` | vidlice, výložník, násada, hydraulika |
| `part_05_bucket.py` | hrabací lžíce — korýtko, břit, 5 zubů |
| `part_06_hopper.py` | korba s průhledy, závěs, zvedací píst, náklad |
| `build_han.py` | složí vše dohromady, ohierarchizuje, zkontroluje obálku, umí exportovat |

Knihovna a jádro se s příchodem [Dula](../dul/README.md) přestěhovaly do
[`blender/common/`](../common/) — jádro je podle spec sdílený asset, ne
kopie, takže Dulovi stačilo změnit jméno robota.

## Konvence souřadnic

Odpovídají [import-assets.md §2.2–2.3](../../docs/import-assets.md), aby šel
model exportovat do glTF bez jediné dodatečné rotace:

```
1 buňka mřížky = 1.0 Blender unit
origin modelu  = střed buňky, model se vejde do [-0.5, 0.5]^3
podlaha buňky  = z = -0.5      (robot na ní stojí)
předek robota  = -Y            (po exportu z toho bude Direction.NORTH)
```

Protože se v „−Y dopředu" špatně počítá, rozměry v `han_spec.py` jsou psané
v čitelném návrhovém rámci `fwd / right / up` (kde `up = 0` je podlaha) a
překládá je funkce `ncr_common.p()`. **Nikde v dílech nepiš souřadnice
ručně — vždycky přes `p()`.**

## Ladění proporcí

Všechno je v `han_spec.py`. Když se tam změní výška trupu, přesune se s ním
rameno, korba i jádro — díly si čísla dopočítají.

Póza ramene se přepíná jednou konstantou:

```python
POSE = POSE_PARKED    # POSE_PARKED / POSE_DIG / POSE_CARRY
```

`POSE_DIG` **záměrně** sahá do sousední buňky (tak Han hrábne do
`ahead_diagonal_below`) — `build_han.py` to ohlásí jako překročení obálky.
Pro export do hry patří `POSE_PARKED`.

Po každém buildu se vypíše kontrola:

```
[NCR] obálka X -0.350..0.350   Y -0.483..0.496   Z -0.500..0.330
[NCR] chodidla na Z = -0.500 (má být -0.500), předek k -Y
[NCR] model se vejde do jedné buňky mřížky.
```

## Co je připravené na animaci

Origin každého pohyblivého dílu **sedí přesně v jeho kloubu**, takže je každý
pohyb jedna rotace kolem X — žádné přepočty:

| Co | Objekt | Jak |
|---|---|---|
| Akce 1 — hrábnutí | `HAN_Arm_Boom`, `HAN_Arm_Stick`, `HAN_Bucket` | rotace kolem X, origin v čepu |
| Akce 2 — vyklopení | `HAN_Hopper` | rotace kolem X (`HOPPER_TIP_ANGLE = -55` je plné vyklopení) |
| jízda | `HAN_Wheel_*`, `HAN_Sprocket_*` | rotace kolem X |

Hydraulické písty jsou rozdělené na `_Barrel` a `_Rod` a každá půlka visí na
svém článku, takže se při ohnutí kloubu natáhnou samy.

**Stav korby** (spec žádá čitelnost zvenku) je vyřešený dvakrát: korba má
průhledy v bocích i v zádi a náklad je samostatný objekt `HAN_HopperLoad`.
Výchozí stav je *prázdná* — plná se udělá odkrytím toho objektu.

## Export do hry

`build_han.py` má na to funkci, ale **standardně nic nezapisuje**:

```python
EXPORT_GLB = False        # True zapíše game/assets/robots/han.glb
APPLY_ROTATIONS = False   # zapeče rotace do meshů, až těsně před exportem
```

Zapnout, nebo zavolat `export_glb()` ručně. Nastavení odpovídá
import-assets §2.2 (GLB, +Y up, applied modifikátory).

Jedna odchylka od §2.2: pravidlo *„jeden materiál na model"* platí pro bloky
kvůli `MultiMesh`. Han má materiálů víc (plášť, kov, guma, obnošená hrana),
protože roboti přes `MultiMesh` nejedou a spec §0.2 přímo žádá, aby barva
odlišovala plášť od neutrálních mechanismů.

## Otevřené otázky

Spec je nechává na pilotním robotovi — Han je odpověděl takhle, ale
rozhodnutí je na tobě:

1. **Jádro 0.3u je velké.** Vůči trupu (0.48 × 0.44) je koule dominantní a
   silueta robota je „hlava na pásech". Čte se to dobře a jako „hlava" to
   funguje, ale pokud má být jádro spíš detail než dominanta, chce to
   0.22–0.25u. Číslo je v `ncr_common.CORE_DIAMETER` a je sdílené všemi 7.
2. **Jádro jako sdílený asset** — postavené je jako samostatná kolekce
   `NCR_Core` a parametrizované jménem robota, takže dalších šest z něj
   vznikne změnou jednoho argumentu. Link do `.blend` se vyplatí až u
   druhého robota.
3. **Hangul.** `한` (spec §0.1 chce ověřit). Jména 1–7 odpovídají korejským
   číslovkám 하나/둘/셋/넷/다섯/여섯/일곱, proto tahle volba — u Da/Yeo/Il
   ale zbývá rozhodnout, jestli jedna slabika (`다`, `여`, `일`), nebo celá
   (`다섯`, `여섯`, `일곱`). Rodilý mluvčí to zatím nepotvrdil.
   Přepisy jsou v `ncr_common.ROBOT_HANGUL`.
4. **Font.** Nápis potřebuje font s hangulem; hledá se v
   `ncr_common.HANGUL_FONTS` (na Windows `malgun.ttf`). Když se nenajde,
   build to ohlásí a nápis zůstane prázdný.

## Na co si dát pozor (poučení z prvního průchodu)

Věci, které při psaní dalších šesti robotů ušetří čas:

- **Boolean nepouštěj na slepenou skořepinu.** EXACT solver si neporadí
  s koincidentními stěnami (dno korby se dotýká boků hranou na hranu) a
  udělá z modelu roztažené pláty. Řež do jednotlivých kvádrů a slep je až
  potom.
- **`matrix_world` je po přiřazení rodiče zastaralá**, dokud neproběhne
  `bpy.context.view_layer.update()`. Bez toho odskočí jak rodičovství, tak
  kontrola obálky.
- **Přesun originu musí počítat s rotací** objektu, jinak geometrie odletí
  (`ncr_common.set_origin` to řeší přes `matrix_world`).
- **Pole (Array) roste v +Y**, ale předek je −Y — offset proto patří záporný.
- **Decal na kouli**: samotná projekce nestačí, u znaku 0.085 na poloměru
  0.15 je průhyb ~0.006, takže se okraje glyfu utopí pod povrchem. Chce to
  druhý shrinkwrap po normále.
- **Skryté objekty depsgraph nevyhodnocuje** (`hide_viewport = True`),
  takže mají zastaralou `matrix_world` i `bound_box`. Kontrola obálky si je
  proto na měření dočasně odkryje. Našlo se to až u Dula, opraveno v obou.

Další poznatky přibyly u [Dula](../dul/README.md) — hlavně co dělat
s díly, které mají sedět na zakřiveném plášti.
