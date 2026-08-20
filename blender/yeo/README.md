# Yeo — Blender stavebnice

Skripty v `bpy`, které postaví robota **Yeo** (ledový, bílá) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §6.

Ověřeno na **Blenderu 4.2 LTS**.

## Jak to spustit

```
blender --background --factory-startup --python blender/yeo/build_yeo.py
```

V Blenderu: `Text ▸ Open` na všechny soubory z `blender/yeo/` **i
z `blender/common/`**, pak spustit `build_yeo.py` nebo jednotlivý díl.

## Soubory

| Soubor | Co postaví |
|---|---|
| `yeo_spec.py` | **výkres**: podvozek, trup, hrudní jádro, chladič |
| `part_01_chassis.py` | rám mezi koly, blatník |
| `part_02_wheels.py` | 4 kola se dvěma řadami hrotů |
| `part_03_hull.py` | trup, límec hrudní koule, krk chladiče |
| `part_04_radiator.py` | žebrovaná hlavice a jinovatka |
| `build_yeo.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |

## Jak se čtou pravidla ve tvaru

- **„chladicí hlavice — dominantní prvek siluety"** → hlavice je širší
  i vyšší než trup (0.40 × 0.32u proti 0.40 × 0.28u). Nese ji jedenáct
  žeber mezi dvěma krycími deskami, drží ji **rohové sloupky**, ne boční
  nosníky — viz poznatky níže.
- **„podvozek potřebuje grip"** a spec k tomu výslovně chce **kontrast
  vůči Dulovu hladkému podvozku**. Yeo má proto hrubá kola s dvěma řadami
  hrotů: co je u Dula zatažené a obtékané, je tady vystrčené a zubaté.
  Hroty tvoří vnějšek kola, takže robot dosedá právě jimi.
- **„jádro níž na hrudi, ať nekoliduje s chladičem"** → střed koule leží
  uvnitř trupu a z čelní stěny se vyklenuje jen její přední část. Vršek
  zůstává celý chladiči. Límec kolem koule je proto prstenec na čele,
  ne na hřbetu jako u ostatních robotů.
- **„jinovatka na žebrech"** → samostatný objekt `YEO_Frost` s vlastním
  materiálem. Jde ho zesílit, zeslabit (`FROST_PER_FIN`) nebo úplně
  vypnout (`build_yeo.FROST = False`), aniž se sahá na chladič.

## Co je připravené na animaci

| Co | Objekt | Jak |
|---|---|---|
| jízda | `YEO_Wheel_L0..1`, `_P0..1` | rotace kolem X |
| námraza | `YEO_Frost` | viditelnost, případně scale |

Chladič sám se nehýbe — je to konstrukční prvek, ne nástroj.

## Rozhodnutí, která stojí za revizi

1. **Kde je vlastně tryska?** Spec §6 u Yeoa žádnou nezmiňuje — mrazení
   popisuje jen jako funkci. Modeloval jsem to tedy tak, že chladič je
   celý nástroj (mrazí sáláním okolo sebe). Kdyby měl mít Yeo směrovou
   trysku jako Set, patří to nejdřív do spec dokumentu.
2. **Kanystr** je předmět inventáře, ne součást robota — stejně jako
   u [Seta](../set/README.md).
3. **Jádro 0.3u** — na hrudi vychází dobře, protože trup je vysoký.
   Viz společná otevřená otázka v [../han/README.md](../han/README.md).
4. **Hangul `여`** — nepotvrzeno rodilým mluvčím.

## Nové poznatky

- **Dominantní prvek musí být dominantní ze všech stran.** Chladič měl
  napřed plné boční nosníky a z profilu z něj byla hladká bílá deska —
  přesně to, čím dominantní prvek siluety není. Rohové sloupky nechají
  stoh žeber prosvítat ze všech čtyř směrů.
- **`radial()` čte `matrix_world` kopírovaného objektu.** U čerstvě
  natočeného dílu (`align_to` nastavuje kvaternion) je zastaralá, takže
  se kopie rozletí kolem počátku scény — hroty vyhodily kola 0.35u pod
  podlahu. Opraveno v knihovně: `radial()` si teď dělá
  `view_layer.update()` sám.
