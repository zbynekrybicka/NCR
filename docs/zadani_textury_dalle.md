# Zadání: Textury povrchů krajiny pro DALL-E

**Účel dokumentu:** podklad pro generování texturových obrázků (DALL-E) pro
povrchy použité v [blender/krajina](../blender/krajina/) — viz
[docs/zadani_krajina_lowpoly_bpy.md](zadani_krajina_lowpoly_bpy.md).

**Důležitá poznámka ke stavu projektu:** aktuální design dokument (kap. 1 a 2)
explicitně předepisuje **flat shading bez UV a bez textur** — každý materiál
nese jen plochou barvu (`MATERIALS` slovník v
[common.py](../blender/krajina/common.py)). Tento dokument je podklad pro
**přechod na texturovaný styl**, což je záměrná odchylka od dosavadního
zadání. Než se textury reálně napojí do `bpy` skriptů (UV unwrap, texture
nody, případně změna materiálové logiky), je potřeba tuto změnu promítnout
zpět do design dokumentu (kap. 1.3 bod 8, kap. 2) — to je samostatný
navazující krok, ne součást tohoto dokumentu.

---

## 1. Seznam povrchů

Povrchy vytažené z `MATERIALS` v `common.py` (= kap. 2 design dokumentu),
roztříděné podle toho, jak se v enginu použijí.

### 1.1 Terén a plošné povrchy — potřebují seamless/tileable texturu

| Klíč | Barva | Popis | Kde se používá |
|---|---|---|---|
| `trava_zahrada` | `#6FA83C` | posekaný, sytě zelený trávník | zahrada (kap. 5) |
| `trava_louka` | `#7FB84A` | luční tráva, o něco divočejší | louka (kap. 6) |
| `trava_ridka` | `#8B9A5B` | řídký horský porost | travnatý pás na hoře (kap. 9.2) |
| `hlina_cesta` | `#9A7A53` | ušlapaná hlína cesty | cesta za zahradou (kap. 4) |
| `hlina_holy` | `#6B5539` | udupaná holá zem | plac u kůlny, břehy, mraveniště okolí |
| `kamen_dlazba` | `#9C9891` | kamenná dlažba | cesta v zahradě (kap. 4) |
| `kamen_skala` | `#7D7A76` | skalní stěna | horní partie hory (kap. 9.2) |
| `kamen_balvan` | `#8A8681` | volné kameny, suťové pole | hora, volné balvany všude |
| `mech` | `#5C7A3E` | mech ve skvrnách | na skále (kap. 9.3), pařezy |
| `jehlici_zeme` | `#7A5B3A` | opadané jehličí na zemi | les (kap. 8), úpatí hory |
| `skala_jeskyne` | `#4A4340` | skalní stěna a podlaha jeskyně | jeskyně (kap. 10) |

### 1.2 Stavební materiály — tileable, menší měřítko opakování

| Klíč | Barva | Popis |
|---|---|---|
| `drevo_plot` | `#A87C4E` | ošlehané světlé dřevo (plot, stříšky) |
| `drevo_tmave` | `#6E4E2E` | tmavé dřevo (kůlna, rumpál, lávka, dveře) |
| `drevo_kmen` | `#5A4632` | kůra kmenů stromů |
| `drevo_suchy` | `#6B5F4A` | suché/mrtvé dřevo (holé stromy) |
| `beton` | `#B4B0A6` | betonová skruž studny |
| `omitka_dum` | `#E4D9C3` | fasáda domu |
| `strecha` | `#A8443A` | střešní krytina |

### 1.3 Vegetační koruny — spíš alpha-cutout karta než klasická tileable textura

| Klíč | Barva | Popis |
|---|---|---|
| `jehlici_zelen` | `#3F6B3A` | jehličnaté koruny borovic |
| `listi_tmave` | `#3E7A46` | keře |
| `listi_svetle` | `#5FA05A` | koruna velkého listnatého stromu |

### 1.4 Voda

| Klíč | Barva | Popis |
|---|---|---|
| `voda_rybnik` | `#3D7A8C` | hladina rybníka (alpha 0,75, transmission) |
| `voda_potok` | `#5AA0AE` | hladina potoka (alpha 0,7) |

### 1.5 Drobné props materiály — nízká priorita pro DALL-E

Malé objekty, kde plocha na modelu je tak malá, že tileable textura buď
nepřinese nic navíc oproti ploché barvě, nebo stačí jednoduchá karta bez
opakování: `lekniny`, `rakos`, `rakos_palice`, `kvet_cervena/zluta/ruzova/
bila/fialova`, `plody`, `houba_hneda`, `houba_cervena`, `sena`, `kov`,
`sklo`, `rez`, `guma_hadice`. Doporučení: řešit až po vyladění hlavních
terénních textur, případně ponechat jako plochou barvu (nejsou dominantní
v záběru).

### 1.6 Emisní/speciální povrchy jeskyně — textura jen pro neemisní složku

`lava`, `lava_kura`, `lava_portal`, `lava_odlesk`, `svetlo_zaval`,
`zaslepovaci_plocha`, `obsidian` — světelná/emisní hodnota zůstává v
shaderu (Emission Strength), DALL-E textura se týká jen albedo složky
(např. `lava_kura` = ztuhlá krusta, `obsidian` = leštěný povrch).

---

## 2. Společný stylový rámec pro všechny prompty

Aby všechny textury seděly vizuálně k sobě (a k paletě z kap. 2 design
dokumentu), každý prompt níže staví na společném základu:

- **Styl:** stylizovaná malovaná herní textura (hand-painted game texture),
  nikoli fotorealismus — ladí s low-poly geometrií scény.
- **Pohled:** kolmo shora (top-down orthographic), rovnoměrné ploché
  osvětlení bez ostrých vržených stínů (stíny dodá engine).
- **Opakovatelnost:** bezešvá dlaždice (seamless tileable texture) — okraje
  obrázku musí na sebe navazovat.
- **Barevnost:** musí odpovídat zadané hex barvě jako dominantnímu tónu
  (DALL-E neumí přijmout hex přímo, proto je v promptu slovní popis
  odstínu odvozený z hex hodnoty).
- **Rozlišení/formát:** čtvercový obrázek, 1024×1024 (DALL-E 3 max
  čtvercový formát), bez vodoznaků, bez textu v obraze.

Šablona promptu:

```
Seamless tileable top-down game texture of {popis povrchu}, hand-painted
stylized low-poly game art style, flat even lighting, no cast shadows, no
vignette, dominant color {slovní odstín}, {doplňkové detaily}, seamless
edges, 1024x1024, no text, no watermark.
```

---

## 3. Prompty po povrchu

### Terén

**trava_zahrada** (`#6FA83C`, sytě zelená, posekaná)
```
Seamless tileable top-down game texture of freshly mown garden lawn grass,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color saturated medium green, short even blades with
subtle mowing stripe pattern, small tonal variation, seamless edges,
1024x1024, no text, no watermark.
```

**trava_louka** (`#7FB84A`, o něco světlejší a divočejší)
```
Seamless tileable top-down game texture of wild meadow grass, hand-painted
stylized low-poly game art style, flat even lighting, no cast shadows,
dominant color fresh yellowish-green, uneven longer blades bending in
different directions, occasional tiny wildflower speck, seamless edges,
1024x1024, no text, no watermark.
```

**trava_ridka** (`#8B9A5B`, tlumená, řídká)
```
Seamless tileable top-down game texture of sparse dry mountain grass
growing in rocky soil, hand-painted stylized low-poly game art style, flat
even lighting, no cast shadows, dominant color muted olive-khaki green,
patchy coverage with visible bare dirt between tufts, seamless edges,
1024x1024, no text, no watermark.
```

**hlina_cesta** (`#9A7A53`, ušlapaná hlína)
```
Seamless tileable top-down game texture of a packed dirt footpath, hand-
painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color warm tan brown, smooth trodden surface with faint
footprint and small pebble texture, seamless edges, 1024x1024, no text, no
watermark.
```

**hlina_holy** (`#6B5539`, tmavší, udupaná)
```
Seamless tileable top-down game texture of bare compacted dark earth,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color dark umber brown, worn and trampled ground with
small stones and dry patches, seamless edges, 1024x1024, no text, no
watermark.
```

**kamen_dlazba** (`#9C9891`, dlažební kameny)
```
Seamless tileable top-down game texture of irregular flat cobblestone
garden paving, hand-painted stylized low-poly game art style, flat even
lighting, no cast shadows, dominant color light warm grey, individual flat
stone slabs with narrow gaps and mossy dust in joints, seamless edges,
1024x1024, no text, no watermark.
```

**kamen_skala** (`#7D7A76`, skalní stěna)
```
Seamless tileable top-down game texture of faceted rocky mountain stone
surface, hand-painted stylized low-poly game art style, flat even
lighting, no cast shadows, dominant color medium cool grey, angular
weathered rock facets with subtle darker cracks, seamless edges, 1024x1024,
no text, no watermark.
```

**kamen_balvan** (`#8A8681`, volné balvany)
```
Seamless tileable top-down game texture of a scree field of loose rounded
boulders and gravel, hand-painted stylized low-poly game art style, flat
even lighting, no cast shadows, dominant color warm light grey, mixed
pebble and boulder sizes tightly packed, seamless edges, 1024x1024, no
text, no watermark.
```

**mech** (`#5C7A3E`, mech)
```
Seamless tileable top-down game texture of soft moss patches on stone,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color deep mossy green, bumpy cushiony texture with
small tonal clumps, seamless edges, 1024x1024, no text, no watermark.
```

**jehlici_zeme** (`#7A5B3A`, jehličí)
```
Seamless tileable top-down game texture of a forest floor covered in dry
pine needles and small twigs, hand-painted stylized low-poly game art
style, flat even lighting, no cast shadows, dominant color warm reddish
brown, layered needle litter with occasional small pinecone fragment,
seamless edges, 1024x1024, no text, no watermark.
```

**skala_jeskyne** (`#4A4340`, jeskynní skála)
```
Seamless tileable top-down game texture of dark rough cave rock floor,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color dark warm charcoal grey, faceted uneven stone
surface with fine cracks, seamless edges, 1024x1024, no text, no
watermark.
```

### Stavební materiály

**drevo_plot** (`#A87C4E`, ošlehané světlé dřevo)
```
Seamless tileable top-down game texture of weathered light wood planks,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color warm sandy tan, visible wood grain and a few
knots, slightly faded and sun-bleached, seamless edges, 1024x1024, no
text, no watermark.
```

**drevo_tmave** (`#6E4E2E`, tmavé dřevo)
```
Seamless tileable top-down game texture of dark aged timber planks, hand-
painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color deep warm brown, pronounced wood grain, small
cracks and worn edges, seamless edges, 1024x1024, no text, no watermark.
```

**drevo_kmen** (`#5A4632`, kůra)
```
Seamless tileable top-down game texture of pine tree bark, hand-painted
stylized low-poly game art style, flat even lighting, no cast shadows,
dominant color dark greyish brown, vertical plated bark ridges, seamless
edges, 1024x1024, no text, no watermark.
```

**drevo_suchy** (`#6B5F4A`, suché dřevo)
```
Seamless tileable top-down game texture of dry bare weathered wood,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color pale greyish tan, cracked dried-out grain, no
bark, seamless edges, 1024x1024, no text, no watermark.
```

**beton** (`#B4B0A6`, betonová skruž)
```
Seamless tileable top-down game texture of aged plain concrete, hand-
painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color light warm grey, subtle mottling and small surface
imperfections, seamless edges, 1024x1024, no text, no watermark.
```

**omitka_dum** (`#E4D9C3`, fasáda)
```
Seamless tileable top-down game texture of a rustic plastered house wall,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color warm cream beige, gentle hand-troweled texture
variation, seamless edges, 1024x1024, no text, no watermark.
```

**strecha** (`#A8443A`, střešní krytina)
```
Seamless tileable top-down game texture of terracotta roof shingles, hand-
painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color warm brick red, overlapping shingle rows with
slight weathering, seamless edges, 1024x1024, no text, no watermark.
```

### Vegetační koruny (alpha karty — atlas, ne tileable dlaždice)

**jehlici_zelen**
```
Hand-painted stylized low-poly game texture of a pine tree foliage clump
on a transparent background, dominant color deep forest green with subtle
tonal variation, soft rounded needle cluster silhouette suitable for a
billboard/canopy card, no background, no text, no watermark, 1024x1024.
```

**listi_tmave**
```
Hand-painted stylized low-poly game texture of a dense dark bush foliage
clump on a transparent background, dominant color deep muted green, soft
rounded leafy silhouette suitable for a billboard/canopy card, no
background, no text, no watermark, 1024x1024.
```

**listi_svetle**
```
Hand-painted stylized low-poly game texture of a bright deciduous tree
canopy clump on a transparent background, dominant color fresh light
green, soft rounded leafy silhouette with lighter highlights suitable for
a billboard/canopy card, no background, no text, no watermark, 1024x1024.
```

### Voda (jemná, s malým opakovacím měřítkem)

**voda_rybnik**
```
Seamless tileable top-down game texture of a calm pond water surface,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color muted teal blue, subtle gentle ripples and soft
reflective highlights, semi-transparent look, seamless edges, 1024x1024,
no text, no watermark.
```

**voda_potok**
```
Seamless tileable top-down game texture of shallow flowing stream water,
hand-painted stylized low-poly game art style, flat even lighting, no cast
shadows, dominant color light aqua blue, small directional ripples
suggesting gentle flow, seamless edges, 1024x1024, no text, no watermark.
```

### Jeskyně — neemisní složka

**lava_kura** (ztuhlá krusta)
```
Seamless tileable top-down game texture of cooled cracked lava crust,
hand-painted stylized low-poly game art style, flat even lighting except
thin glowing cracks, dominant color near-black charcoal with dark red-
brown undertones, network of jagged plates separated by thin glowing
orange cracks, seamless edges, 1024x1024, no text, no watermark.
```

**obsidian**
```
Seamless tileable top-down game texture of polished black volcanic glass
obsidian, hand-painted stylized low-poly game art style, flat even
lighting, no cast shadows, dominant color glossy near-black, subtle sheen
and faint conchoidal fracture lines, seamless edges, 1024x1024, no text,
no watermark.
```

---

## 4. Doporučené pořadí

Stejně jako u modelovacího zadání (kap. 12 tamního dokumentu) doporučuji
negenerovat všechno najednou:

1. Terénní povrchy (1.1) — nejvíc plochy v záběru, největší dopad na
   celkový look.
2. Stavební materiály (1.2).
3. Voda (1.4).
4. Vegetační karty (1.3) — vyžadují ověřit, jestli alpha-cutout přístup
   sedí s existující geometrií korun (ico-koule).
5. Jeskyně (1.6) a drobné props (1.5) až nakonec, případně některé
   ponechat jako plochou barvu, pokud se ukáže, že textura nic nepřidá.

## 5. Navazující krok (mimo rozsah tohoto dokumentu)

Až budou textury vygenerované a vybrané, je potřeba:

- Aktualizovat kap. 1 a 2 [design-dokumentu krajiny](zadani_krajina_lowpoly_bpy.md)
  (zrušit pravidlo „negenerovat UV/textury“, doplnit texturovací konvence).
- Rozšířit `get_material()` v `common.py` o UV unwrap a texture image node
  místo/vedle plochého Base Color.
- Rozhodnout dlaždicové měřítko (kolik metrů = jedna dlaždice textury) pro
  každý povrch, aby to sedělo s rozlišením mřížky terénu (kap. 3).
