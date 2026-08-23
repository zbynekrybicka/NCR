# Krajina „Cesta robotů" — Blender stavebnice

Skripty v `bpy`, které postaví rozlehlou low-poly krajinu podle
[docs/zadani_krajina_lowpoly_bpy.md](../../docs/zadani_krajina_lowpoly_bpy.md).
Na rozdíl od [robotů](../README.md) tohle NENÍ herní asset (žádná buňka
mřížky, žádný export do `game/assets/`) — je to samostatná scéna ve world-space
metrech, se kterou si autor dělá vlastní render a kontrolu.

Každá sekce dokumentu má svůj soubor a jde spustit zvlášť:

| Soubor | Co postaví | Kap. |
|---|---|---|
| `common.py` | sdílená knihovna — `SEED`/`rng`, `MATERIALS`/`get_material()`, `height()`/`snap_to_ground()`, `terrain_zone()`, hash noise, `scatter()`/`cluster_scatter()`, `Batch`/`link_dup()`/prototypy, `PATH_POINTS`/`CREEK_POINTS`/`CAVE_POINTS`. Nespouští se. | 1-3 |
| `01_teren.py` | jedna souvislá mřížka `T_teren_hlavni`, materiálové zóny, fazety na hoře, otvor pro portál jeskyně | 3 |
| `02_cesta.py` | dlažba v zahradě + hlína dál, mizení na hoře | 4 |
| `03_dum_plot.py` | dům, plot, branka | 5.1-5.2 |
| `04_zahrada.py` | trávník, záhonky, studna, kůlna, doplňky | 5.3-5.6 |
| `05_louka_potok.py` | velký strom, luční tráva/květiny, potůček, doplňky louky | 6 |
| `06_rybnik.py` | hladina, křoví, rákos/lekniny, molo a doplňky | 7 |
| `07_les.py` | borovice, mraveniště, podrost | 8 |
| `08_hora.py` | výškové zóny, suťové pole, mech, doplňky, vchod do jeskyně | 9 |
| `09_jeskyne.py` | chodba, enklávy, láva, krápníky, zával | 10 |
| `build_krajina.py` | spustí všechno v pořadí, poskládá kolekce, vypíše statistiky a spot-checkne pár acceptačních kritérií | 11-12 |

## Jak to spustit

**Z příkazové řádky** (bez GUI):

```
blender --background --factory-startup --python blender/krajina/build_krajina.py
```

Vynechání `--background` otevře Blender s hotovou scénou k prohlédnutí.

**V Blenderu (Text Editor).** `Text ▸ Open` a otevřít všechny soubory ze
složky `blender/krajina/` **i z `blender/common/`** (skripty se navzájem
importují a hledají se přes cestu otevřeného textového bloku, stejný trik
jako u robotů). Pak stačí spustit `build_krajina.py`, nebo jen jednu sekci
(např. `07_les.py` — postaví jen les, terén ale musí existovat, resp.
`snap_to_ground()` funguje analyticky i bez něj).

Skripty jsou **idempotentní**: každá sekce na začátku smaže vlastní objekty
podle prefixu (`T_`, `A_`, `B_`, `C_`, `D_`, `E_`, `F_`, `P_`), takže se dají
pouštět opakovaně bez hromadění kopií.

## Autor si kontrolu dělá sám

Tenhle kód nikdo v generujícím session nespustil ani nevyrenderoval — bpy tu
není k dispozici. Kontrola syntaxe proběhla přes `python -m py_compile` na
každém souboru (to odhalí překlepy a chyby v odsazení, ne rozbitou
geometrii). Než se scéna prohlásí za hotovou, projít [kap. 11 — akceptační
kritéria](../../docs/zadani_krajina_lowpoly_bpy.md#11-akceptační-kritéria-checklist-pro-kontrolu-výstupu)
vizuálně: `build_krajina.py` automaticky ohlásí jen body 3 (flat shading) a
4 (spot-check pár hlavních staveb, ne všechno) — zbytek (příčný sklon louky,
potok tekoucí z kopce, hladina rybníka volná ze 75 %+, les bez trávy,
jediné světlo v jeskyni z lávy, žádná zvířata...) chce oči.

## Zjednodušení oproti spec

Zadání samo říká, že je to "spec pro slabší model" rozdělená na malé kroky,
ne že se má trefit do posledního šroubku — ale pro přehlednost, co je
záměrně jinak (a proč), viz hlavičky jednotlivých souborů. Nejvýznamnější:

- **Hora — fazety.** Zadání nabízí dvě cesty (variabilní krok mřížky, nebo
  jitter). Zvolený jitter: mřížka zůstává 1.0 m všude (stejná topologie
  všude), ale výška se pro Y > ~105 vzorkuje ze zaokrouhlené 3m mřížky —
  sousední vrcholy sdílí plošinky, což vypadá fazetovaně bez přestavby sítě.
- **Jeskyně — enklávy.** Čtyři postranní komory (kap. 10.2) nejsou
  samostatné krabicové místnosti, ale boční vydutí hlavního tunelu (větší
  poloměr + boční posun řezů) s jejich charakteristickým obsahem uvnitř.
  Ruční topologie zvlášť stavěné místnosti bez možnosti render kontroly byla
  vyhodnocená jako zbytečné riziko děravé geometrie.
- **Vchod do jeskyně — portál.** Obdélníkový kamenný rám místo přesného
  nepravidelného osmiúhelníkového výřezu, ze stejného důvodu (riziko
  rozbitého otvoru bez možnosti to zkontrolovat).
- **Luční tráva/květiny — hustota.** O něco níž než literální čísla ze
  spec (kap. 6.2: 1.8 shluku/m², 400-600 květin), aby se scéna i se zbytkem
  krajiny vešla do rozpočtu 150-250k trojúhelníků. Kompoziční pravidla
  (ostrůvkovité rozložení, hustší u cesty) zůstala.
- **Květiny — barva.** Zahradní i luční květina je stonek + jeden plochý
  okvětní disk v jedné barvě (bez odděleného žlutého středu) — jeden
  materiál na objekt je jednodušší než další sadu prototypů jen kvůli
  jednomu pixelu žluté.
- Řada drobných doplňků (šroubky kbelíků, jednotlivá prkna kůlnové střechy,
  klikaté praskliny ve skále...) je zastoupená reprezentativním vzorkem, ne
  do posledního kusu — strukturální a kompoziční prvky z kap. 11 ano,
  mikro-detail podle uvážení.

## Rozpočet

`build_krajina.py` po sestavení vypíše trojúhelníky po sekcích a součet
proti rozpočtu 150 000–250 000 (kap. 1). Opakované prvky (tráva, květiny,
kameny, stromy) jsou všude buď **linked duplicates** ze 3-5 prototypů
(`common.link_dup`/`scatter_instances`/`build_rock_prototypes`), nebo
**jedna dávková mesh** postavená přímo z vrcholů (`common.Batch`) — nikde
`bpy.ops` ve smyčce přes stovky prvků (kap. 1.3 bod 3).

## Cesta jako kolekce navíc

Kap. 1.2 vyjmenovává kolekce jen pro sedm sekcí + terén + helpery. Cesta
(kap. 4) probíhá skrz všechny a nezapadá organizačně do žádné z nich, takže
má vlastní kolekci `P_Cesta` navěšenou vedle nich pod `Krajina` — záměrná
odchylka od doslovného výčtu, ne přehlédnutí.

## Export

`EXPORT_GLB = True` v `build_krajina.py` zapíše `*.glb` po sekcích do
`blender/krajina/export/` (mimo `game/assets/` — krajina zatím není součástí
herní asset pipeline robotů popsané v `docs/import-assets.md`, která počítá
s buňkou mřížky a `godot_forward()` otočkou; až bude čas napojit krajinu do
hry, export cesta/formát se podle toho přizpůsobí).
