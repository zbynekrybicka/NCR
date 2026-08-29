# Zadání: Hudba pro Suno AI

**Účel dokumentu:** podklad pro generování hudebního doprovodu hry pomocí
[Suno AI](https://suno.com) — sada ambientních skladeb, které se náhodně
střídají při hraní levelu (s možností ruční změny klávesou), a jedna
decentní skladba pro menu.

**Vzor/inspirace:** Martin Linda a jeho hudba pro hru *Berušky 2* od
Anakreonu — hrou, kterou je NCR celkově inspirované (viz
[design-document.md](design-document.md)). Konkrétní skladby ani zvukové
soubory z Berušek 2 nejsou k dispozici jako referenční materiál; níže
uvedený stylový rámec vychází z toho, jak jej autor v zadání popsal
(elektronická, meditativní hudba, která diváka po opakovaném poslechu
nezačne štvát), ne z rozboru konkrétních nahrávek.

**Stav projektu:** podle [CLAUDE.md](../CLAUDE.md) se vizuál a zvuk řeší
až od verze 0.2.0 — tento dokument je příprava assetů (prompty a jejich
výstupy), samotné napojení do hry (audio manager, přehrávání, klávesa pro
přepínání) je až navazující krok, viz [kap. 6](#6-navazující-kroky-mimo-rozsah-tohoto-dokumentu).

---

## 1. Přehled

| Sada | Počet | Přehrávání |
|---|---|---|
| **Level hudba** | 10 skladeb | Náhodný výběr při běhu levelu; hráč může aktuální skladbu přeskočit na další (náhodně vybranou) vyhrazenou klávesou. |
| **Menu hudba** | 1 skladba | Přehrává se v menu/scéně výběru levelu; velmi decentní, v smyčce. |

Deset level skladeb by mělo znít jako **jedna soudržná sada** (stejný
zvukový svět), ne jako deset náhodných kusů vedle sebe — hráč je bude
během levelu slyšet opakovaně a v libovolném pořadí, takže musí sedět k
sobě navzájem stejně jako každá zvlášť k samotné hře.

---

## 2. Společný stylový rámec

- **Žánr:** elektronická ambientní/downtempo hudba. Žádný symfonický
  orchestr, žádné velké nástrojové plochy typu filmový score.
- **Tempo:** pomalé až střední, orientačně 65–95 BPM. Žádný výrazný beat
  určující děj — pokud je perkuse vůbec přítomná, je jemná, tlumená,
  spíš texturální než rytmicky vůdčí.
- **Nástroje:** syntezátorové plochy (pads), jemné arpeggiované
  sekvence, měkký (sub)basový puls, ojedinělé melodické motivy s
  dostatkem prostoru mezi nimi. Bez zpěvu/vokálu — čistě instrumentální,
  aby text neodváděl pozornost od přemýšlení.
- **Nálada:** meditativní, podporuje soustředění a uvažování nad
  hádankou, s jemným podtónem klidného soustředění — ne ospalá ambientní
  výplň, ale ani napínavá/úzkostná hudba. Cíl: hráč má pocit, že musí
  udržet chladnou hlavu, aby uspěl, ne že je v ohrožení.
- **Snesitelnost při opakování:** žádné výrazné melodické „hooky",
  opakující se vokální fráze (stejně odpadá vokál úplně) ani náhlé
  dynamické skoky (crescenda, drop momenty). Skladba musí fungovat i
  jako nenápadné pozadí při desátém poslechu.
- **Smyčkovatelnost:** skladby poběží ve hře opakovaně ve smyčce — viz
  praktická poznámka v [kap. 5](#5-praktické-poznámky-k-práci-se-suno).

### Šablona Suno promptu (Style of Music pole, custom mode, instrumentální)

```
ambient electronic, downtempo, meditative, minimal, atmospheric analog-style
pads, soft evolving arpeggios, gentle sub bass pulse, sparse melodic motifs,
{doplňkové nástroje/barva dané skladby}, calm focused mood, cool-headed
tension, spacious mix, slow tempo around {BPM} bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

**Exclude styles (negative prompt) pro všechny skladby:**
```
vocals, singing, choir, rap, lyrics, orchestral, symphonic, epic trailer,
distorted guitar, aggressive drums, EDM drop, dubstep bass, jump scare,
sudden dynamics
```

---

## 3. Level skladby (10×)

Sedm z deseti skladeb je volně inspirovaných živlem/charakterem jednoho
z robotů (viz [1.1 Roboti](design-document.md#11-roboti)) — nejde o
herní mechaniku (skladby se přehrávají náhodně za celý level, ne podle
toho, kdo je zrovna aktivní), jen o způsob, jak dát deseti skladbám
odlišnou, ale tematicky ukotvenou barvu v rámci jednoho zvukového světa.
Zbylé tři jsou neutrální, „obecně herní" varianty stejného rámce.

**1. Zemní** (`#01-zemni`)
```
ambient electronic, downtempo, meditative, minimal, warm grounded analog
pads, soft mechanical clicks, deep slow sub bass pulse, muted low woody
percussion textures, earthy amber tone, calm focused mood, cool-headed
tension, spacious mix, slow tempo around 72 bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

**2. Vodní** (`#02-vodni`)
```
ambient electronic, downtempo, meditative, minimal, fluid slowly undulating
pads, gentle flowing arpeggio, soft filtered water-like texture, deep
sub bass pulse, cool blue tone, calm focused mood, cool-headed tension,
spacious mix, slow tempo around 68 bpm, instrumental, no vocals, no lead
vocal melody, no drop, no build-up climax, loopable
```

**3. Ohnivý** (`#03-ohnivy`)
```
ambient electronic, downtempo, meditative, minimal, slow pulsing warm
synth glow like embers, restrained tension, soft sub bass pulse, sparse
metallic pings, amber-red tone kept calm and controlled, cool-headed
tension, spacious mix, slow tempo around 78 bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

**4. Přírodní** (`#04-prirodni`)
```
ambient electronic, downtempo, meditative, minimal, organic soft wooden
mallet and bell tones, gently climbing arpeggio motif, warm analog pad bed,
deep sub bass pulse, green earthy tone, calm focused mood, cool-headed
tension, spacious mix, slow tempo around 74 bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

**5. Létající** (`#05-letajici`)
```
ambient electronic, downtempo, meditative, minimal, airy spacious high
pads, light delayed sparkling texture, weightless floating feel, soft
sub bass pulse, pale blue-white tone, calm focused mood, cool-headed
tension, wide spacious mix, slow tempo around 80 bpm, instrumental, no
vocals, no lead vocal melody, no drop, no build-up climax, loopable
```

**6. Ledový** (`#06-ledovy`)
```
ambient electronic, downtempo, meditative, minimal, crystalline glassy
bell textures, sparse icy pad, slow shimmering arpeggio, deep sub bass
pulse, cold icy blue-white tone, calm focused mood, cool-headed tension,
spacious mix, slow tempo around 70 bpm, instrumental, no vocals, no lead
vocal melody, no drop, no build-up climax, loopable
```

**7. Elektrický** (`#07-elektricky`)
```
ambient electronic, downtempo, meditative, minimal, subtle circuit-like
micro-rhythm sequence, soft glitch texture, restrained arpeggiated synth
pulse, deep sub bass, blue-purple tone, calm focused mood, cool-headed
tension, spacious mix, slow tempo around 82 bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

**8. Tichý výpočet** (`#08-tichy-vypocet`) — neutrální
```
ambient electronic, downtempo, meditative, minimal, slow evolving neutral
pad bed, distant soft arpeggio, deep sub bass pulse, understated and
spacious, grayscale tone with a faint hint of color, calm focused mood,
cool-headed tension, slow tempo around 75 bpm, instrumental, no vocals, no
lead vocal melody, no drop, no build-up climax, loopable
```

**9. Kybernetická zahrada** (`#09-kyberneticka-zahrada`) — neutrální, mix
nature + cybernetic (viz název hry)
```
ambient electronic, downtempo, meditative, minimal, organic textures
blended with soft synthetic pads, gentle glitch-touched arpeggio, deep
sub bass pulse, blend of green and blue tones, calm focused mood,
cool-headed tension, spacious mix, slow tempo around 76 bpm, instrumental,
no vocals, no lead vocal melody, no drop, no build-up climax, loopable
```

**10. Hluboké soustředění** (`#10-hluboke-soustredeni`) — neutrální
```
ambient electronic, downtempo, meditative, minimal, very sparse slow pad
drone, occasional soft melodic motif with long silences between phrases,
deep sub bass pulse, dim neutral tone, calm focused mood, cool-headed
tension, spacious mix, slow tempo around 66 bpm, instrumental, no vocals,
no lead vocal melody, no drop, no build-up climax, loopable
```

---

## 4. Menu skladba (1×)

Musí být nápadně decentnější než level skladby — hráč u ní stráví čas
procházením menu/výběrem levelu, ne řešením hádanky, takže smí být ještě
klidnější a téměř bez vývoje.

**Menu** (`#00-menu`)
```
ambient electronic, very minimal, extremely sparse and static soft pad
drone, barely moving texture, no arpeggio, no percussion, distant faint
sub bass, neutral pale tone, quiet unobtrusive background atmosphere, calm
and settled mood, no tension, slow tempo around 60 bpm, instrumental, no
vocals, no melodic motif, no drop, no build-up climax, loopable
```

**Exclude styles pro menu skladbu** (navíc k obecným v [kap. 2](#2-společný-stylový-rámec)):
```
percussion, drums, rhythmic sequence, arpeggio, melody, buildup
```

---

## 5. Praktické poznámky k práci se Suno

- **Instrumentální režim:** v Suno v custom módu nechat pole s textem
  prázdné / použít přepínač Instrumental — žádný z výše uvedených promptů
  vokál nepotřebuje.
- **Délka:** Suno generuje typicky ~2–4minutové skladby; pro herní smyčku
  to stačí, není potřeba composovat na délku levelu (level může trvat
  kratší i mnohem delší dobu než jedna skladba, hraje se to ve smyčce).
- **Seamless loop:** Suno negeneruje skladby jako čistou smyčku (začátek
  a konec na sebe zvukově nenavazují). Před nasazením do hry je potřeba
  vybraný výstup doupravit v audio editoru (např. Audacity) — najít/
  vytvořit loop point s crossfade, aby přechod z konce na začátek nebyl
  slyšitelný. Tohle je krok navíc po výběru finálních skladeb, ne
  součást samotného promptování.
- **Iterace:** doporučuji generovat po menších dávkách (např. 2–3
  skladby najednou) a hned poslechem ověřit, že barva/tempo sedí k
  ostatním už vybraným kouskům, než se vygeneruje zbytek — stejný princip
  postupného ověřování jako u ostatního obsahu (viz
  [CLAUDE.md](../CLAUDE.md), preferovaný způsob práce).
- **Pojmenování souborů:** kódy v závorkách u každé skladby (`#01-zemni`
  atd.) jsou návrh na název souboru po stažení, ať se dá sada snadno
  importovat do Godotu v konzistentním pořadí.

---

## 6. Navazující kroky (mimo rozsah tohoto dokumentu)

Až budou skladby vygenerované, vybrané a doupravené na smyčku, je potřeba:

- Doplnit do [design-document.md](design-document.md) novou sekci o
  hudbě (analogicky k jiným herním systémům) — zejména: klávesa pro
  ruční přepnutí level skladby na další (v [design-document.md kap.
  2.1.2](design-document.md#212-řízené-prvky--roboti) zatím žádná taková
  klávesa není definovaná, autor ji musí zvolit a případně zmapovat vedle
  ostatních ovládacích kláves), chování při přepnutí (okamžitě, nebo
  crossfade?), a kdy přesně se mezi level a menu hudbou přepíná.
- Implementovat přehrávání v Godotu (`AudioStreamPlayer` / audio manager
  autoload): náhodný výběr při startu levelu, náhodný výběr při ručním
  přeskočení (bez opakování stejné skladby dvakrát za sebou), smyčkování,
  přechod na menu skladbu při návratu do menu.
