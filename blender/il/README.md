# Il — Blender stavebnice

Skripty v `bpy`, které postaví robota **Il** (elektrický, žlutá) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §7.

Ověřeno na **Blenderu 4.2 LTS**. Il je poslední ze sedmi.

## Jak to spustit

```
blender --background --factory-startup --python blender/il/build_il.py
```

V Blenderu: `Text ▸ Open` na všechny soubory z `blender/il/` **i
z `blender/common/`**, pak spustit `build_il.py` nebo jednotlivý díl.

## Soubory

| Soubor | Co postaví |
|---|---|
| `il_spec.py` | **výkres**: trup, hlava, nohy, ramena, pruhy |
| `part_01_body.py` | soudkovitý trup, obruby, černé pruhy a panely, krční prstenec |
| `part_02_legs.py` | dvě boční nohy a přední noha, 3 kola |
| `part_03_arms.py` | výsuvné pájecí a USB rameno |
| `build_il.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |

## Jak se čtou pravidla ve tvaru

- **„R2-D2 základ"** → soudkovitý trup (průměr 0.36u, výška 0.35u), tři
  kola — dvě boční nohy a jedna přední — a černé akcenty na žluté
  karoserii: dva obvodové pruhy a čtyři svislé panely.
- **„Jádro na vrcholu kupole/hlavy — Il je jediný, kde hlava v běžném
  smyslu splývá s pozicí jádra nejpřirozeněji"** → čteno doslova: **jádro
  tu hlavu JE**. Žádná kupole s koulí navrch, koule sedí přímo na trupu
  a límec kolem ní hraje roli krčního prstence. U žádného jiného robota
  to takhle nevychází — proto to spec zmiňuje právě u Ila.
- **Dvě různé ruce, každá na svou práci** → pájecí špička je tenká
  a přesná (opravuje skříně), USB konektor je plochý a hranatý (ovládá
  panely). Podle spec jsou obě **výsuvné**, takže tyč je samostatný objekt
  s originem v ústí pouzdra: zasunutí je posun podél lokálního Z.
- Přední noha je vedle nápisu na hlavě **druhý ukazatel orientace** —
  z libovolného úhlu je vidět, kam Il kouká.

## Co je připravené na animaci

| Co | Objekt | Jak |
|---|---|---|
| jízda | `IL_Wheel_L / _P / _C` | rotace kolem X |
| vysunutí nástroje | `IL_ArmSolder`, `IL_ArmUSB` | posun podél osy ramene (`il_spec.EXTEND`) |
| postoj | `IL_Leg_L / _P / _C` | rotace v uchycení |

`build_il.EXTEND = 0.0` zasune obě ramena do pouzder — tak Il vypadá,
když zrovna nepracuje.

## Rozhodnutí, která stojí za revizi

1. **Il nemá oko.** Reference ho má a je to její nejcharakterističtější
   prvek, ale spec §7 ho v seznamu prvků neuvádí a orientaci nese nápis
   na hlavě i přední noha. Po zkušenosti s [Netem](../net/README.md) jsem
   ho nepřidával sám od sebe — kdybys ho chtěl, je to jedna čočka
   na kupoli a řádek v `part_01_body.py`.
2. **Ramena jsou vysunutá.** Výchozí stav modelu ukazuje oba nástroje,
   aby bylo na první pohled vidět, co Il umí. Pro klidový vzhled stačí
   `EXTEND = 0.0`.
3. **Jádro 0.3u** — u Ila sedí poměr nejpřirozeněji ze všech sedmi,
   protože hlava a jádro jsou tentýž prvek. Kdyby se jádro zmenšovalo
   (viz [../han/README.md](../han/README.md)), zmenší se tím Ilovi hlava
   a proporce R2 se rozejdou — u něj to bude vidět nejvíc.
4. **Hangul `일`** — nepotvrzeno rodilým mluvčím.

## Nové poznatky

- **Záplaty přes záměnu řetězců musí kontrolovat, že něco nahradily.**
  Dvě úpravy barev (Yeo, Il) selhaly mlčky, protože hledaný řetězec se
  o jednu číslici lišil od skutečného — a modely se pak renderovaly
  v původní bledé barvě, aniž by cokoli hlásilo chybu. `assert a in s`
  před každou náhradou to odhalí hned.
