# Dul — Blender stavebnice

Skripty v `bpy`, které postaví robota **Dul** (vodní, modrá) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §2.

Stejný postup jako u [Hana](../han/README.md): každý díl je samostatný
soubor, `build_dul.py` je složí dohromady. Knihovnu a jádro si oba roboti
sdílejí z [../common/](../common/). Ověřeno na **Blenderu 4.2 LTS**.

## Jak to spustit

**V Blenderu (Text Editor).** `Text ▸ Open` a otevřít všechny soubory
z `blender/dul/` **i z `blender/common/`** — skripty se navzájem hledají
podle cesty otevřeného textového bloku. Pak spustit `build_dul.py` (celý
robot) nebo jednotlivý díl.

**Z příkazové řádky.**

```
blender --background --factory-startup --python blender/dul/build_dul.py
```

## Soubory

| Soubor | Co postaví |
|---|---|
| `dul_spec.py` | **výkres**: profil trupu a všechny attachment pointy |
| `part_01_hull.py` | torpédo z elipsových řezů, zápustky kol, hrdlo sání, švy, límec jádra |
| `part_02_wheels.py` | 4 nízkoprofilová kola na kyvných ramenech |
| `part_03_intake.py` | sání na přídi — náběhový prstenec, hrdlo, mříž (Akce 1) |
| `part_04_nozzle.py` | tryska na zádi — kryt, rotor, stator (Akce 2 + pohon) |
| `part_05_tank.py` | cisterna — skleněná kopule, límec, hladina |
| `build_dul.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |
| [`../common/ncr_common.py`](../common/ncr_common.py) | sdílená knihovna |
| [`../common/part_00_core.py`](../common/part_00_core.py) | jádro (spec §0.1) — stejný skript pro všech 7 |

## Jak se čtou pravidla ve tvaru

Spec §2 dává u Dula jednu vůdčí myšlenku: **hladkost trupu je funkční**,
ne stylová — Dul po ledu klouže a plave. Z toho plyne většina rozhodnutí:

- Trup je **jeden loft** z elipsových řezů, ne skládačka kvádrů. Slouží
  k tomu `ncr_common.hull_loft()`, přidaný právě kvůli Dulovi.
- Kola jsou **zapuštěná do břicha** a zápustky schválně **neprořezávají
  bok** pláště — jinak by do nich bylo z boku vidět a kola by trčela ze
  siluety, což spec zakazuje.
- Sání i tryska jsou **vrtané do trupu**, ne přilepené.
- Cisterna je **kopule zapuštěná pod povrch**, ne otvor s vanou (viz níže).

Výšku celého trupu řídí jediná konstanta `HULL_AXIS_UP` — profil je psaný
relativně k ní, takže posunutím trupu se přesunou i kola a všechno ostatní.

## Co je připravené na animaci

| Co | Objekt | Jak |
|---|---|---|
| pohon / vypouštění | `DUL_Impeller` | rotace kolem Y, origin na ose trysky |
| zatažení podvozku | `DUL_WheelArm_*` | rotace kolem X, origin v čepu ramene<br>(`build_dul.RETRACT_WHEELS = -70`) |
| jízda | `DUL_Wheel_*` | rotace kolem X |
| stav cisterny | `DUL_TankWater` | viditelnost; výchozí stav je prázdná |

Kopule je průhledná, takže je hladina čitelná zvenku ze všech stran —
prázdný Dul má kopuli světle modrou, plný zelenomodrou.

## Export do hry

Stejně jako u Hana je připravený, ale **vypnutý**:

```python
EXPORT_GLB = False        # True zapíše game/assets/robots/dul.glb
APPLY_ROTATIONS = False   # zapeče rotace do meshů, až těsně před exportem
```

## Rozhodnutí, která stojí za revizi

1. **Cisterna jako kopule, ne jako otvor.** Spec říká „vnitřní objem
   naznačený průhledem/poklopem nahoře". První pokus vedl do hřbetu
   skutečný otvor a pod něj vanu — jenže hřbet je zakřivený a zužuje se,
   takže plochý lem otvoru na jednom konci trčel a na druhém se propadal.
   Kopule zapuštěná pod povrch tenhle problém nemá a objem *naznačuje*,
   jak spec chce. Je ale menší, než by „cisterna" napovídala. Kdyby měla
   být objemnější, jde zvětšit `TANK_*` — hřbet je v místě kopule rovný,
   takže roztažení dopředu/dozadu je bezpečné.
2. **Jádro 0.3u je i tady dominantní.** Na torpédu působí jako potápěčská
   helma — čitelné a svým způsobem sympatické, ale je to půlka výšky
   robota. Platí stejná otevřená otázka jako u Hana: číslo je sdílené
   (`ncr_common.CORE_DIAMETER`) a rozhodnout se má jednou pro všech 7.
3. **Hangul `둘`** — nepotvrzeno rodilým mluvčím, viz
   [../han/README.md](../han/README.md).
4. **Kola vs. „zatažitelná".** Modelovaná jsou jako kyvná ramena, která
   se dají zatáhnout rotací. Design dokument zatím neříká, jestli je
   zatažení stav, který hra vůbec zobrazuje — pokud ne, je to jen
   příprava do zásoby.

## Nové poznatky (nad rámec Hanova seznamu)

- **Skryté objekty depsgraph nevyhodnocuje**, takže mají zastaralou
  `matrix_world` i `bound_box` — kontrola obálky je musí na měření
  dočasně odkrýt. (Kvůli tomu hlásil první build Dula obálku přesně
  ±0.5 ve všech osách: prázdná nádrž se tvářila jako jednotková krychle.)
  Opraveno i u Hana.
- **Na zakřiveném plášti nefunguje plochý lem.** Cokoli, co má na oblém
  povrchu sedět bez plovoucí hrany, musí být buď zapuštěné hlouběji, než
  je největší spád povrchu, nebo tvarované podle něj. Boolean řezaný
  kopií toho, co má obepnout (zvětšenou o pár procent), je na to
  spolehlivější než válec.
- **Zápustka nesmí prorazit plášť z druhé strany**, jinak přestane
  schovávat to, co má schovat.
