# Zadání: Textury kostek úrovně (herní mřížka) pro DALL-E

**Účel dokumentu:** podklad pro generování texturových obrázků (DALL-E) pro
pět typů statických kostek herní mřížky (viz [design-document.md, kap.
2.1.4](design-document.md#214-statické-prvky--překážky)):

- **Zeď** — ocelová konstrukce
- **Hlína**
- **Dřevo**
- **Kámen**
- **Led**

Toto je jiná sada než [zadani_textury_dalle.md](zadani_textury_dalle.md),
který řeší povrchy pro venkovní diorama v
[blender/krajina](../blender/krajina/) (`campaign_map`/`world_map`). Tady
jde o materiály samotných kostek herní mřížky, se kterými hráč přímo
interaguje v levelu (viz `GridTypes.BlockType` v
[grid_types.gd](../game/core/grid/grid_types.gd) a jejich vykreslení v
[world_view.gd](../game/app/view/world_view.gd)).

**Důležitá poznámka ke stavu projektu:** design dokument v kap. 3 (Otevřené
otázky) explicitně říká, že art styl hry je záměrně mimo scope až do verze
0.2.0 — aktuálně se kostky vykreslují jen plochou barvou
(`StandardMaterial3D.albedo_color`, viz `BLOCK_COLORS` v
[world_view.gd:11-17](../game/app/view/world_view.gd#L11-L17)). Tento
dokument je tedy podklad pro budoucí texturovaný render, ne rozhodnutí o
art stylu samo o sobě. Až budou textury vybrané, je potřeba to promítnout
zpět do design dokumentu (viz [5. Navazující krok](#5-navazující-krok)).

Pro vizuální konzistenci s [zadani_textury_dalle.md](zadani_textury_dalle.md)
přebírá tento dokument stejný „hand-painted stylized low-poly" art
styl. Pokud by měla mřížka levelu mít odlišný (např. čistší/industriálnější)
vizuál než venkovní krajina, je potřeba to explicitně rozhodnout — viz
poznámka v [2. Společný stylový rámec](#2-společný-stylový-rámec).

---

## 1. Seznam materiálů a jejich pravidla

Kostka v mřížce je jednotný `BoxMesh` (1×1×1, viz `CELL_SIZE` v
[world_view.gd:8](../game/app/view/world_view.gd#L8)) s **jedním materiálem
na všech šesti stěnách** — na rozdíl od terénních textur v krajině tedy
textura nemá zvýhodněný pohled shora, musí fungovat i zboku (např. Han se
dívá na Zeď z první osoby). Proto níže cílíme na **frontální materiálový
vzorek**, ne top-down perspektivu.

| Klíč | Placeholder barva (`world_view.gd`) | Pravidlo z design dokumentu |
|---|---|---|
| `zed_ocel` | `#8C8C94` (chladná světle šedá) | Neprůchodná a **nezničitelná**, nelze přesunout ani ovlivnit gravitací — bere se jako pevný podklad pro robota o úroveň výš. Design dokument připouští i betonovou variantu; toto zadání řeší jen ocelovou dle zadání. |
| `hlina` | `#73522E` (tmavě hnědá) | Neprůchodná pro všechny kromě Hana, který ji **vykopává** (akce 1). Podléhá gravitaci. |
| `drevo` | `#8C6133` (teplá hnědá) | Neprůchodná, **zničitelná ohněm** (Set, akce 1) — po zničení nezůstává nic. Podléhá gravitaci. |
| `kamen` | `#616166` (neutrální tmavě šedá) | Nezničitelná, ale na rozdíl od zdi **podléhá gravitaci** (padá, uvolní-li se prostor pod ní). |
| `led` | `#A6D9F2` (bledě ledová modrá) | Vzniká jen ve vodě (Yeo, akce 1), taje (Set, akce 1). Nikdy nepadá — vždy pevně ukotvený. Ve stejné úrovni jako robot se chová jako zeď, o úroveň výš se po něm klouže. |

Mimo rozsah tohoto zadání (nebyly součástí požadavku): `RAMP` (šikmina —
vizuálně pravděpodobně sdílí materiál se Zdí, jen jiný tvar) a `TARGET`
(cíl — má vlastní zářivě žlutou identitu, `#F2CC33`, spíš jako
"UI"/interaktivní prvek než textura povrchu).

---

## 2. Společný stylový rámec

- **Styl:** stylizovaná malovaná herní textura (hand-painted stylized
  low-poly game texture) — shodné s [zadani_textury_dalle.md](zadani_textury_dalle.md#2-společný-stylový-rámec-pro-všechny-prompty),
  aby kostky levelu a venkovní diorama vizuálně ladily.
- **Pohled:** frontální pohled na plochý materiálový vzorek (rovná
  plocha čelem ke kameře), ne perspektiva ani top-down — textura jde na
  všech 6 stěn kostky rovnoměrně.
- **Opakovatelnost:** bezešvá dlaždice (seamless tileable) na všech
  čtyřech okrajích — nutné i mezi sousedními kostkami stejného typu
  (např. delší souvislá zeď z více kostek Zeď vedle sebe).
- **Osvětlení:** rovnoměrné ploché, bez ostrých vržených stínů (stíny a
  PBR odlesky dodá engine).
- **Barevnost:** dominantní odstín odpovídá placeholder barvě z tabulky
  výše, aby náhrada textury za plochou barvu nezměnila razantně čitelnost
  mřížky (hráč typy kostek rozeznává i podle barvy).
- **Rozlišení/formát:** čtvercový obrázek, 1024×1024, bez vodoznaků, bez
  textu v obraze.

Šablona promptu:

```
Seamless tileable game material texture of {popis materiálu}, hand-painted
stylized low-poly game art style, flat frontal view, flat even lighting, no
cast shadows, no perspective, dominant color {slovní odstín}, {doplňkové
detaily}, seamless edges on all sides, 1024x1024, no text, no watermark.
```

---

## 3. Prompty po materiálu

**zed_ocel** (`#8C8C94`, chladná světle šedá, ocelová konstrukce)
```
Seamless tileable game material texture of an indestructible industrial
steel wall panel, hand-painted stylized low-poly game art style, flat
frontal view, flat even lighting, no cast shadows, no perspective, dominant
color cool light grey metal, bolted/riveted steel plating with subtle
seams and faint scratches, solid mechanical fortress look, seamless edges
on all sides, 1024x1024, no text, no watermark.
```

**hlina** (`#73522E`, tmavě hnědá, kopatelná zemina)
```
Seamless tileable game material texture of a dense diggable earth block,
hand-painted stylized low-poly game art style, flat frontal view, flat
even lighting, no cast shadows, no perspective, dominant color dark warm
soil brown, clumpy compact dirt with small pebbles and thin root fibers,
looks excavatable, seamless edges on all sides, 1024x1024, no text, no
watermark.
```

**drevo** (`#8C6133`, teplá hnědá, spálitelné dřevo)
```
Seamless tileable game material texture of a solid stacked wooden block,
hand-painted stylized low-poly game art style, flat frontal view, flat
even lighting, no cast shadows, no perspective, dominant color warm medium
brown, visible wood grain planks with a couple of small knots, sturdy but
flammable look, seamless edges on all sides, 1024x1024, no text, no
watermark.
```

**kamen** (`#616166`, neutrální tmavě šedá, těžký balvan)
```
Seamless tileable game material texture of a solid rough granite boulder
block, hand-painted stylized low-poly game art style, flat frontal view,
flat even lighting, no cast shadows, no perspective, dominant color
neutral dark grey stone, faceted rock surface with subtle cracks and
mineral speckles, heavy indestructible look, seamless edges on all sides,
1024x1024, no text, no watermark.
```

**led** (`#A6D9F2`, bledě ledová modrá, zmrzlá voda)
```
Seamless tileable game material texture of a frozen ice block, hand-
painted stylized low-poly game art style, flat frontal view, flat even
lighting, no cast shadows, no perspective, dominant color pale icy blue,
translucent frosty surface with subtle internal cracks and light frost
specks, cold slippery look, seamless edges on all sides, 1024x1024, no
text, no watermark.
```

---

## 4. Doporučené pořadí

Všech pět je zhruba stejně důležitých (jsou to jediné statické
zničitelné/gravitační překážky v mřížce), pořadí podle toho, co se dřív
potká v levelech:

1. `zed_ocel` — nejčastější kostka v každém levelu (hranice, konstrukce).
2. `hlina`, `kamen`, `drevo` — hlavní interaktivní překážky, ověřit
   spolu, ať barevně dobře odliší od sebe i od zed_ocel.
3. `led` — nejvíc kontextově vázaný na vodu, generovat až s nádrží po
   ruce, aby šlo posoudit soulad s `voda_rybnik`/`voda_potok`.

## 5. Navazující krok (mimo rozsah tohoto dokumentu)

Až budou textury vygenerované a vybrané:

- Rozhodnout, jestli mřížka levelu sdílí přesně stejný art styl jako
  venkovní krajina, nebo má mít vlastní (viz poznámka v úvodu) — promítnout
  rozhodnutí zpět do design dokumentu (kap. 3, Otevřené otázky / TODO —
  položka "art styl").
- V [world_view.gd](../game/app/view/world_view.gd) nahradit
  `material.albedo_color = color` (řádky 80-82) načtením `Texture2D` a UV
  mapováním na `BoxMesh`; `BLOCK_COLORS` slovník může zůstat jako fallback
  nebo jako zdroj `albedo_color` tintu přes texturu.
- Pro `led` zvážit, jestli texturovaná verze má i nadále nést
  poloprůhlednost/lesk přes shader parametry (aktuálně kostka ledu nemá
  žádnou transparency, na rozdíl od vody — je to jen barevně odlišná pevná
  kostka), nebo jestli textura sama navodí "ledový" dojem beze změny
  materiálových vlastností.
- Zvážit doplnění betonové varianty Zdi (design dokument připouští "beton
  nebo ocel") jako druhou texturu ve stejném `BlockType.WALL`, pokud editor
  časem dostane možnost volit vzhled zdi (viz [Nastavení objektu](design-document.md#221-ovládací-panel) — „každému objektu se přiřazuje model z dostupné knihovny").
