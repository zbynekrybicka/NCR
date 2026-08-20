# Net — Blender stavebnice

Skripty v `bpy`, které postaví robota **Net** (přírodní, zelená) podle
[docs/robots-blender-spec.md](../../docs/robots-blender-spec.md) §0 a §4.

Ověřeno na **Blenderu 4.2 LTS**.

## Zadání autora: žádný obličej

**Net nemá obličej, oči ani kusadla.** Žádné párové kulaté prvky na přídi,
žádná tykadla, žádné čelisti — nic, co by šlo přečíst jako tvář. Tohle
pravidlo stojí nad spec dokumentem a je zapsané i v hlavičce
[`net_spec.py`](net_spec.py), aby přežilo budoucí úpravy.

Spec §4 sice u umístění jádra zmiňuje „hlavu", ale myslí tím jen místo na
těle. Přední segment je proto hladký, symetrický a beze všeho.

**Orientaci robota** proto nesou tři jiné věci:

1. zúžená příď oproti široké zádi,
2. sklon nohou — přední pár míří dopředu, zadní dozadu,
3. nápis v hangulu na jádru, který podle spec §0.1 kouká dopředu.

## Jak to spustit

```
blender --background --factory-startup --python blender/net/build_net.py
```

V Blenderu: `Text ▸ Open` na všechny soubory z `blender/net/` **i
z `blender/common/`**, pak spustit `build_net.py` nebo jednotlivý díl.

## Soubory

| Soubor | Co postaví |
|---|---|
| `net_spec.py` | **výkres**: profil těla, nohy, krunýř, náklad |
| `part_01_body.py` | tělo z elipsových řezů, segmentové pásky, lůžko jádra |
| `part_02_legs.py` | 6 článkovaných nohou s přísavkami |
| `part_03_carapace.py` | otevírací krunýř s čepem vpředu |
| `part_04_cargo.py` | dno schránky a 4 předměty |
| `anim_walk.py` | **klipy `walk`, `turn_left`, `turn_right`, `turn_around`** |
| `build_net.py` | složí vše, ohierarchizuje, zkontroluje obálku, umí exportovat |

## Jak se čtou pravidla ve tvaru

- **„nízké těžiště, chitinózní krunýř"** → Net je nejnižší ze všech
  (0.40u proti Hanovým 0.83u). Tělo je jeden hladký loft členěný
  vystouplými páskami, ne skládačka kvádrů. Výšku řídí jediná konstanta
  `BODY_AXIS_UP` — posunutím se přesunou i nohy, krunýř a schránka.
- **„jediný bez koleček, šplhá po svislých stěnách"** → šest článkovaných
  nohou s přísavkami. Nohy sahají dál než tělo (rozkročení 0.93u), aby se
  robot opíral o široký polygon.
- **„nejmenší profil ze všech"** u jádra → koule je pro všech 7 stejná
  (0.3u), takže jediný způsob, jak to splnit, je zapuštění. U Neta sahá
  spodek koule až na spodek těla — hlouběji už to nejde.
- **„vizuálně odlišit nese 0–2 vs 3–4"** → do dvou předmětů krunýř
  dosedne, od tří zůstane pootevřený a náklad je vidět.

## Animace

**Hotové klipy** ([`anim_walk.py`](anim_walk.py)):

| Klip | Délka | Co dělá |
|---|---|---|
| `walk` | 0.80 s | krok o jednu buňku vpřed |
| `turn_left` / `turn_right` | 0.67 s | otočka o 90° na místě |
| `turn_around` | 1.00 s | čelem vzad |

**Chod je střídavý tripod:** tři nohy stojí, tři kročí, pak se trojice
vymění. Je to nejjednodušší chod, u kterého robot v každém okamžiku stojí
na třech nohách, takže nepotřebuje řešit rovnováhu.

**Chodidlo se drží země, ne těla.** Do nové buňky posouvá model
`EventAnimator` s celým uzlem ([import-assets.md §6.4](../../docs/import-assets.md)),
takže nohy, které zrovna stojí, musí uvnitř klipu couvat přesně o tu
buňku dozadu. Klip proto neanimuje kloubní úhly, ale předepisuje **polohu
chodidla** a úhly dopočítává inverzní kinematika (`ncr_anim.ik_two_link`).
Kontrola ve skriptu hlásí, o kolik chodidlo minulo cíl a jestli stojící
noha prokluzuje — u všech čtyř klipů vychází 0.0000u.

**Kolik cyklů na krok** (`net_spec.WALK_CYCLES`) je jediné číslo, kterým
se ladí délka kroku. Za jednu stojící fázi ujede tělo `CELL / (2 *
WALK_CYCLES)` a přesně o tolik se musí chodidlo posunout vůči tělu. Při
dvou cyklech to je 0.25u, což Netova noha ujde bez natažení na doraz;
při jednom by na krok nedosáhla, při čtyřech by cupitala.

**Kde klip začíná:** má celý počet cyklů, takže první a poslední snímek
jsou stejná póza a kroky se dají řetězit bez trhnutí. Není to ale úplně
souměrný postoj — ve chvíli výměny tripodu je jedna trojice nohou o půl
kroku vpředu a druhá vzadu. Pro šestinožce je tohle přirozená stojící
póza a od ní se bude odvíjet i budoucí klip `idle`.

**Vlevo a vpravo** jsou z pohledu robota. Pozor: `ncr_common.p()` mapuje
svůj parametr `right` na +X, ale robot mířící přídí k −Y má na +X svoji
**levou** ruku. U souměrného tvaru to nevadilo, u otáčení by záměna byla
vidět hned.

## Co je připravené na další animace

| Co | Objekt | Jak |
|---|---|---|
| šplhání po stěně | `NET_LegFemur_*` → `NET_LegTibia_*` | stejná kinematika, jen jinam předepsaná chodidla |
| otevření krunýře | `NET_Carapace` | rotace kolem X, čep vpředu |
| počet předmětů | `NET_Cargo_0..3` | viditelnost (`net_spec.CARGO_COUNT`) |

`build_net.py` otevře krunýř sám, jakmile je `CARGO_COUNT >= 3`.

## Rozhodnutí, která stojí za revizi

1. **Přísavky, ne hroty.** Spec nabízí obojí. Přísavky zvolené záměrně —
   na svislou stěnu sedí líp a nepůsobí výhrůžně. Přepnout na hroty by
   znamenalo přepsat jen `part_02_legs.py`.
2. **Nohy nemají třetí článek.** Spec říká „článkované", což dvě části
   plus přísavka splňují. Dva články navíc dovolují použít uzavřené
   řešení inverzní kinematiky — u tří by bylo řešení nejednoznačné a
   muselo by se něco dodefinovat. Kdyby chůze potřebovala jemnější
   kinematiku, přidá se tarsus stejným postupem.
3. **Jádro 0.3u** — u Neta vyčnívá nejmíň ze všech, ale pořád je to
   největší jednotlivý prvek. Viz společná otevřená otázka
   v [../han/README.md](../han/README.md).
4. **Hangul `넷`** — nepotvrzeno rodilým mluvčím.

## Nové poznatky

- **`bound_box` je LOKÁLNÍ osově zarovnaný kvádr.** Převedením jeho rohů
  do světa vznikne u otočeného dílu nafouklý odhad — kontrola obálky
  hlásila u Netovy nohy 3 cm pod podlahou, které tam nebyly. Měří se
  proto přes vrcholy. Opraveno u všech čtyř robotů.
- **Znaménko rotace závisí na tom, kde je čep.** Krunýř má čep vpředu,
  takže se otevírá *kladným* úhlem; Hanova korba má čep vzadu a vyklápí
  se *záporným*. Při −32° zmizel krunýř do těla.
- **Origin v čepu se vyplatil až u animace.** Že články nohou mají origin
  v kloubu, bylo při stavbě jen úklidové rozhodnutí. Díky němu ale
  inverzní kinematika nepotřebuje žádný přepočet: femur se otočí kolem
  kyčle, tibia kolem kolena a je hotovo.
- **`ncr_common.p()` má parametr `right` na opačné straně.** +X je
  u robota mířícího k −Y jeho levá ruka. Na souměrném tvaru se to
  neprojevilo, u otáček by ano.
