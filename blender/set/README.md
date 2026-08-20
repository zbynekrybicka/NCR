# Set — Blender stavebnice

Skripty v `bpy`, které postaví robota **Set** (ohnivý, červená) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §3.

Stejný postup jako u [Hana](../han/README.md) a [Dula](../dul/README.md):
každý díl je samostatný soubor, `build_set.py` je složí. Knihovnu a jádro
si roboti sdílejí z [../common/](../common/). Ověřeno na **Blenderu 4.2 LTS**.

## Jak to spustit

```
blender --background --factory-startup --python blender/set/build_set.py
```

V Blenderu: `Text ▸ Open` na všechny soubory z `blender/set/` **i
z `blender/common/`**, pak spustit `build_set.py` nebo jednotlivý díl.

## Soubory

| Soubor | Co postaví |
|---|---|
| `set_spec.py` | **výkres**: všechny rozměry a attachment pointy |
| `part_01_chassis.py` | rám mezi koly, blatník, čelní deska |
| `part_02_wheels.py` | 6 terénních kol s vzorkem |
| `part_03_hull.py` | trup se zkosenou přídí, věnec věže, lůžko jádra |
| `part_04_turret.py` | otočná věž s lícemi a čepem náměru |
| `part_05_flamer.py` | hlaveň, ústí se sazemi, vlastní nádrž, hořáček |
| `build_set.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |

## Jak se čtou pravidla ve tvaru

Spec §3 dává dvě vůdčí myšlenky a obě jsou v modelu vidět:

- **„statická pozice při palbě"** → podvozek je robustnější než Hanův:
  šest velkých kol s vzorkem, široký rozchod (0.64u), těžký rám nízko
  u země a čelní deska s žebry. Silueta má působit zapřeně, ne hbitě.
- **„hlavice jako hlavní silueta-definující prvek"** → dlouhá hlaveň
  s rozšířeným ústím na otočné věži. Z každého úhlu je to první, co na
  robotovi uvidíš.

Spec navíc chce dosah **vodorovně / šikmo / svisle** (dřevo) a **šikmo
dolů** (led). To znamená dva klouby: odměr věže kolem Z a náměr hlavně
kolem X, s rozsahem zhruba −45° až +90° (`ELEVATION_RANGE`).

## Co je připravené na animaci

| Co | Objekt | Jak |
|---|---|---|
| odměr | `SET_Turret` | rotace kolem Z, origin v ose věnce |
| náměr | `SET_Flamer` | rotace kolem X, origin v čepu náměru |
| jízda | `SET_Wheel_L0..2`, `_P0..2` | rotace kolem X |

Ústí a nádrž visí na hlavni, hlaveň na věži — otočením věže se pohne celá
hlavice. Výchozí póza je náměr +12°, věž na čelo; obojí se přepíná
v `set_spec.py` nebo přes `build_set.TURRET_YAW` / `ELEVATION`.

## Rozhodnutí, která stojí za revizi

1. **Jádro vzadu a omezený náměr nad zádí.** Spec chce jádro „na těle,
   mimo dráhu plamene". Leží tedy vzadu na palubě, za věží a pod úrovní
   čepu hlavně. Cenou je běžné omezení každé skutečné věže: sklopit
   hlaveň dolů *nad zádí* nejde, narazila by do jádra. Pokud má hra
   umožňovat pálení šikmo dolů dozadu, chce to jádro přesunout jinam —
   nebo se smířit s tím, že se Set musí otočit.
2. **Vlastní nádrž vs. kanystr.** Modelovaná je jen ta malá na hlavici,
   jak spec žádá. Kanystr, který Set spotřebovává, je předmět inventáře
   a patří do `assets/items/`, ne do modelu robota.
3. **Jádro 0.3u** — stejná otevřená otázka jako u ostatních, viz
   [../han/README.md](../han/README.md).
4. **Hangul `셋`** — nepotvrzeno rodilým mluvčím.

## Nové poznatky

- **Cokoli, co se dotýká podlahy, musí být uvnitř jmenovitého poloměru.**
  Vzorek běhounu přidaný *nad* `WHEEL_R` propadl kolo pod podlahu buňky
  o 13 mm. Plášť má proto poloměr `WHEEL_R - LUG_H` a vzorek tvoří
  vnějšek. Totéž platilo pro ostruhy Hanových pásů.
- **Odstup přílepku musí být větší než součet poloměrů.** Vlastní nádrž
  s odstupem 0.072 od osy hlavně o poloměru 0.042 se do hlavně zapustila
  a přestala být čitelná jako nádrž.
- **Odvozovat skript jednoho robota z druhého jde, ale ne plošnou
  záměnou řetězců.** `"dul"` → `"set"` přepsalo i `mo`**`dul`**`e` uvnitř
  `importlib.import_module` a `sys.modules`. Generátor proto nahrazuje
  cíleně (`DUL_`, `dul_spec`, `build_dul`, …).
