# Da — Blender stavebnice

Skripty v `bpy`, které postaví robota **Da** (létající, azurová) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §5.

Ověřeno na **Blenderu 4.2 LTS**.

## Jak to spustit

```
blender --background --factory-startup --python blender/da/build_da.py
```

V Blenderu: `Text ▸ Open` na všechny soubory z `blender/da/` **i
z `blender/common/`**, pak spustit `build_da.py` nebo jednotlivý díl.

## Soubory

| Soubor | Co postaví |
|---|---|
| `da_spec.py` | **výkres**: rozteč ramen, rotory, podvozek, hák, senzor |
| `part_01_frame.py` | centrální trup, 4 ramena v X, gondoly motorů, kamera |
| `part_02_rotors.py` | 8 rotorů ve čtyřech koaxiálních párech |
| `part_03_gear.py` | 4 přistávací nohy s chodidly |
| `part_04_hook.py` | hák na ose pod trupem |
| `anim_rotors.py` | **klip `rotors`** — roztočení všech osmi vrtulí |
| `build_da.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |

## Jak se čtou pravidla ve tvaru

- **X-konfigurace, ne kříž.** Ramena míří do rohů buňky, protože po
  úhlopříčce je nejvíc místa — disk rotoru se tak vejde největší
  (průměr 0.33u při rozpětí 0.87u). Vedlejší efekt: vpředu je mezi rameny
  volno pro kameru a nic nepřekáží dopřednému pohledu.
- **„musí přistát pro výměnu robota"** → Da se modeluje **přistálý**,
  chodidla na podlaze buňky. Vznášení je podle
  [import-assets.md §2.3](../../docs/import-assets.md) věc idle animace,
  ne pozice modelu — jinak by se rozešel s kamerou a s ostatními roboty.
- **„sbírá předmět jen shora"** → hák visí na ose robota, takže se nabírá
  svisle dolů. Spodek háku zůstává i po přistání nad podlahou (0.031u),
  aby si Da nesedl na vlastní náklad.
- **Koaxiální páry** → dolní rotor je natočený o 60° vůči hornímu, takže
  jsou shora vidět oba disky a je jasné, že jich je osm, ne čtyři.

## Animace

**Hotový klip: `rotors`** ([`anim_rotors.py`](anim_rotors.py)) — jedna celá
otáčka za 0.40 s (150 ot/min), horní rotor páru po směru hodinových
ručiček, dolní proti. Protiběh není kosmetika: koaxiální pár si tím ruší
reakční moment a shora je díky němu na první pohled vidět, že rotorů je
osm, a ne čtyři.

Klip je **smyčka a pouští se napořád**, ne přes tabulku událostí. Podle
[import-assets.md §6.3](../../docs/import-assets.md) se smyčka nesmí
roztahovat přes `speed_scale`, takže `rotors` patří do vlastní stopy
(nebo vlastního `AnimationPlayer`) a s krokem po mřížce nemá nic
společného. V Godotu se u něj musí zapnout **Loop** v nastavení importu
`.glb`.

Tempo se ladí jediným číslem — `da_spec.ROTOR_SPIN_FRAMES`. Klíčů na
otáčku (`ROTOR_SPIN_STEPS`) musí zůstat aspoň tři: glTF zná jen
kvaterniony a mezi dvěma klíči jde vždycky nejkratší cestou, takže dva
klíče na celé kolo by znamenaly, že se vrtule nepohne vůbec.

## Co je připravené na další animace

| Co | Objekt | Jak |
|---|---|---|
| pohled kamery | `DA_Sensor` | rotace, origin v úchytu gondoly |
| zatažení podvozku | `DA_Gear_0..3` | rotace, origin tam, kde noha vychází z trupu |
| houpání nákladu | `DA_Hook` | rotace kolem závěsu |

Vznášení (klip `idle`) se dělá posunem `DA_Root`, ne přestavbou modelu.

## Rozhodnutí, která stojí za revizi

1. **Kamera vpředu.** Spec §5 ji explicitně chce kvůli čitelné orientaci.
   Je to jedno oko na gondole, tedy zjevné zařízení — ne tvář. Kdyby
   i tohle bylo moc (srov. zadání u [Neta](../net/README.md)), orientaci
   by musela nést jen X-konfigurace a nápis na jádru, což je slabší.
2. **Hák, ne gripper.** Spec nabízí obojí. Hák je jednodušší, čitelnější
   ze všech úhlů a k „nabírání shora" stačí. Gripper s čelistmi by
   znamenal dva až tři pohyblivé díly navíc.
3. **Rotory se točí v klipu, ne v Godotu.** Původně měl být model
   statický a roztočení věc GDScriptu. Klip vyhrál proto, že jede
   s modelem v jednom souboru, nepotřebuje na scéně žádný skript navíc
   a Godot ho umí míchat s ostatními klipy přes `AnimationTree`. Pro
   render zblízka se klip zastaví na snímku 0 — v pohybu splynou listy
   v disk.
4. **Jádro 0.3u** — u Da vychází poměr nejlíp ze všech, protože trup je
   široký a koule na něm sedí jako kokpit. Viz společná otevřená otázka
   v [../han/README.md](../han/README.md).
5. **Hangul `다`** — nepotvrzeno rodilým mluvčím.

## Poznámky ke stavbě

- **Oblouk háku je torus s vyříznutým ústím**, ne oblouk poskládaný
  z článků. Boolean na čistém torusu je spolehlivější a dá se řídit
  jedním úhlem (`HOOK_GAP`).
- Rozteč a průměr rotoru jsou svázané: `da_spec.reach()` počítá největší
  dosah od středu, takže je vidět, kolik místa v buňce ještě zbývá,
  než se sáhne na `ARM_R` nebo `ROTOR_R`.
