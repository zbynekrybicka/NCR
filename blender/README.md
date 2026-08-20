# blender/ — modely robotů

Skripty v `bpy`, které staví modely podle
[docs/robots-blender-spec.md](../docs/robots-blender-spec.md). Každý robot
je stavebnice: díly jsou samostatné soubory a `build_*.py` je složí.

```
blender/
├── common/     sdílená knihovna + jádro (spec §0.1 — jeden asset pro všech 7)
│   ├── ncr_common.py     konvence, materiály, primitiva, boolean/bevel/join
│   ├── ncr_anim.py       klipy, inverzní kinematika, export animací do glTF
│   └── part_00_core.py   centrální jednotka, parametrizovaná jménem robota
├── han/        Han — zemní (hnědá)     → README
├── dul/        Dul — vodní (modrá)     → README
├── set/        Set — ohnivý (červená)  → README
├── net/        Net — přírodní (zelená) → README
├── da/         Da — létající (azurová) → README
├── yeo/        Yeo — ledový (bílá)     → README
└── il/         Il — elektrický (žlutá) → README
```

**Všech sedm robotů je hotových.** Každý se vejde do jedné buňky mřížky,
stojí na její podlaze a míří čelem k −Y.

**Animovaní jsou zatím dva:** Da (roztočené vrtule) a Net (chůze a otáčky).
Podrobnosti v [Animace](#animace) níž a v README obou robotů.

## Společné pro všechny

**Konvence souřadnic** (podle [import-assets.md §2.2–2.3](../docs/import-assets.md),
aby export do glTF nepotřeboval žádnou dodatečnou rotaci):

```
1 buňka mřížky = 1.0 Blender unit
origin modelu  = střed buňky, model se vejde do [-0.5, 0.5]^3
podlaha buňky  = z = -0.5      (robot na ní stojí)
předek robota  = -Y
```

Rozměry se v `*_spec.py` píšou v čitelném rámci `fwd / right / up`
(kde `up = 0` je podlaha) a překládá je `ncr_common.p()`.

**Postup, který se osvědčil:**

1. Přečíst příslušnou sekci spec dokumentu a najít v ní *vůdčí myšlenku*
   tvaru (u Hana „dosah dopředu/dolů", u Dula „hladkost je funkční").
2. Napsat `*_spec.py` — všechna čísla na jednom místě, díly žádnou
   konstantu nedefinují.
3. Stavět po dílech, každý spustitelný samostatně a idempotentní.
4. **Vyrenderovat a podívat se.** Build proběhne „bez chyby" i tehdy, když
   je model rozpadlý — u Hana zbyly z korby roztažené pláty, u Dula
   trčela cisterna z trupu. Z kódu to vidět není.
5. Kontrola obálky v `build_*.py` hlídá, že se model vejde do buňky
   a stojí na podlaze.

**Nový robot** začíná zkopírováním `*_spec.py` a `build_*.py`, protože
jádro i knihovna jsou sdílené — píše se tedy jen vlastní tvar. Knihovna
tím postupně roste: Dul do ní přidal `hull_loft` a `stretch` a materiály
`glass` / `water`, Set materiál `soot`. Set, Net i Da už si vystačili
s tím, co v ní bylo — knihovna se ustálila.

Odvozovat `build_*.py` jednoho robota z druhého se vyplatí, ale **ne
plošnou záměnou řetězců**: `"dul"` → `"set"` přepíše i `mo`**`dul`**`e`
uvnitř `importlib.import_module`. Nahrazuj cíleně.

## Animace

Klipy se dělají v Blenderu a jedou s modelem v `.glb` — Godot je uvidí
v `AnimationPlayer` pod jménem klipu. Sdílené nástroje jsou v
[`common/ncr_anim.py`](common/ncr_anim.py), vlastní klipy robota v jeho
složce v `anim_*.py` a čísla (délky, výšky kroku, počet cyklů) tam, kam
patří všechna ostatní čísla — do `*_spec.py`.

| Robot | Klip | Délka | Co dělá |
|---|---|---|---|
| Da | `rotors` | 0.40 s, smyčka | 8 rotorů, koaxiální pár proti sobě |
| Net | `walk` | 0.80 s | krok o jednu buňku vpřed |
| Net | `turn_left` / `turn_right` | 0.67 s | otočka o 90° na místě |
| Net | `turn_around` | 1.00 s | čelem vzad |

**Dvě pravidla, ze kterých plyne skoro všechno ostatní:**

1. **Klip nesmí hýbat kořenem modelu.** Posun do nové buňky a otočení
   dělá `EventAnimator` s celým uzlem ([import-assets.md §6.4](../docs/import-assets.md)).
   Klip hýbe jen tím, co je uvnitř — u chůze se tedy nohy, které zrovna
   stojí, musí posouvat *proti* směru pohybu, jinak chodidla kloužou.
2. **Délku určuje hra, ne klip** ([§6.3](../docs/import-assets.md)) — klip
   se v Godotu roztáhne přes `speed_scale`. Proto se dělá v přirozeném
   tempu a v tabulce se drží jeho přirozená délka. Smyčka se roztahovat
   nesmí, takže `rotors` běží ve vlastní stopě a s událostmi nemá nic
   společného.

**Postup, který se osvědčil u chůze:** neanimovat kloubní úhly, ale
předepsat, **kde je chodidlo**, a úhly dopočítat inverzní kinematikou
(`ncr_anim.ik_two_link`). Chodidlo pak stojí přesně tam, kde má, došlap
sedí na tisícinu buňky a tempo kroku se mění jedním číslem, bez
překreslování křivek. Skript si to sám kontroluje a vypíše, o kolik
chodidlo minulo cíl a jestli stojící noha neprokluzuje — obojí má být
0.0000.

Seznam pastí je na konci každého README. Tyhle platí pro všechny
a stojí za zopakování:

- **Skryté objekty depsgraph nevyhodnocuje** — mají zastaralou
  `matrix_world` i `bound_box`.
- **`bound_box` je lokální osově zarovnaný kvádr**, takže u otočeného
  dílu jeho převod do světa nadhodnocuje. Obálka se měří přes vrcholy.
- **`matrix_world` je po `align_to` i po přiřazení rodiče zastaralá**,
  dokud neproběhne `view_layer.update()`. Knihovna si to hlídá sama
  v `radial()`, `set_origin()` a v kontrole obálky.
- **Boolean nepouštěj na slepenou skořepinu** — EXACT solver si neporadí
  s koincidentními stěnami. Řež do jednotlivých kvádrů, slep je potom.
- **Cokoli, co se dotýká podlahy** (ostruhy, vzorek, hroty), musí být
  uvnitř jmenovitého poloměru kola, ne nad ním.
- **Znaménko rotace závisí na tom, kde je čep** — Hanova korba se vyklápí
  záporným úhlem (čep vzadu), Netův krunýř kladným (čep vpředu).
- **Záplaty přes záměnu řetězců musí kontrolovat, že něco nahradily.**
  Dvakrát se stalo, že se náhrada minula o číslici a selhala mlčky.
- **Hotová NLA stopa pózuje objekt při každém `frame_set`.** Když se na
  jednom modelu dělá víc klipů za sebou, musí se hotové stopy umlčet a
  klidová póza sejmout jednou na začátku — jinak druhý klip vychází
  z poslední pózy prvního. Na konci se stopy musí zase pustit, protože
  umlčenou exportér do `.glb` nezapíše.
- **Kvaternion má dvojí zápis** (`q` i `-q`). Dva sousední klíče
  s opačným znaménkem se při interpolaci po složkách přetočí dokola.
- **Kontrola obálky se dělá na stojícím modelu**, ne na rozkročeném —
  proto se animace pouští až po `report()`.
