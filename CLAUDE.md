# Nature Cybernetic Robots (NCR)

Logická 3D puzzle hra v Godotu, ve které hráč střídavě ovládá sedm robotů se
zcela odlišnými schopnostmi pohybu/interakce, aby je společně dostal přes
krychlovou mřížkou tvořenou úroveň do cíle. Bez náhody, bez AI protivníků —
čistě deterministické puzzle na tahy.

Plný herní design je v [docs/design-document.md](docs/design-document.md).
Dokument vznikl přepisem autorova PDF a **není hotový** — obsahuje sekci
"Otevřené otázky / TODO" na konci s chybějícími částmi (dokončení pravidel
Dula, UI, art styl, struktura levelů atd.). Design dokument se doplňuje
průběžně souběžně s vývojem, ne celý předem.

## Cíl projektu

Dvojí, stejně důležité:

1. Dokončit hratelnou hru.
2. Naučit se opakovatelný workflow spolupráce s AI na vývoji hry — jak
   napsat design dokument, podle kterého lze hru stavět po malých,
   kontrolovatelných krocích (ne jedním obřím promptem na celou hru).

Z toho plyne preferovaný způsob práce: **postupovat po malých, samostatně
ověřitelných krocích** (jeden systém/mechanika/scéna najednou), ne
generovat velké části hry najednou. Než se začne implementovat nedokončená
mechanika, je potřeba nejdřív doplnit její pravidla v design dokumentu.

## Tech stack

- **Engine:** Godot 4.x
- **Jazyk:** GDScript
- Herní projekt (Godot project root) žije v [game/](game/) — zatím prázdné,
  čeká na `project.godot`.

## Struktura repozitáře

```
NCR/
├── docs/
│   └── design-document.md   # herní design dokument (živý, průběžně se doplňuje)
└── game/                    # Godot projekt (kořen s project.godot)
```

## Klíčové herní koncepty (rychlý přehled)

- Level = krychlová 3D mřížka; vše (roboti, předměty, překážky) žije v této
  mřížce a pohybuje se po jedné kostce.
- Hráč ovládá vždy jednoho aktivního robota, mezi roboty na scéně se
  přepíná v předem dané sekvenci.
- Každý robot: otočení (vlevo/vpravo/čelem vzad, neomezené), krok vpřed,
  a až dvě specifické akce (Akce 1, Akce 2).
- Sedm robotů se sedmi odlišnými pohybovými/interakčními schopnostmi —
  Han (zemní/kope a převáží hlínu), Dul (vodní/čerpadlo+cisterna),
  Set (ohnivý/pálí překážky), Net (přírodní/šplhá po stěnách),
  Da (létající/dron), Yeo (ledový/tvoří led), Il (elektrický/ovládá
  zařízení). Detaily viz design dokument.
- Cíl levelu: dostat všechny přidělené roboty do cíle; nejdřív musí cílem
  projít robot, který na scéně našel klíč.
- Hmotnost robotů (+ nesené předměty) ovlivňuje interakce s objekty
  (nosnost mostů, výtahů apod.).
- Součástí hry je i in-game **editor** levelů (viz design dokument, sekce 2.2).

## Poznámky pro práci s AI

- Design dokument je zdroj pravdy pro pravidla hry. Když se implementuje
  mechanika, jejíž pravidla v dokumentu chybí nebo jsou nejednoznačná,
  je třeba se nejdřív zeptat / doplnit dokument — ne si pravidla domýšlet.
- Autor (Zbyněk) chce z tohoto projektu odnést i obecný postup pro
  AI-asistovaný game dev, který lze pak použít i na budoucí projekty —
  přístup a rozhodnutí o procesu (ne jen o kódu) mají tedy taky hodnotu.
