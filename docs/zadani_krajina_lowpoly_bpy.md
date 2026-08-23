# Zadání: Low-poly krajina „Cesta robotů“ — modelovací specifikace pro bpy

**Účel dokumentu:** podklad pro model, který napíše Python skript pro Blender (`bpy`).
**Cílová verze Blenderu:** 4.2 LTS a vyšší.
**Doporučené použití:** nezadávat celý dokument najednou. Rozdělit na sekce 1–8 a zadávat po jedné (viz kap. 12 — Pořadí promptů). Kapitoly 1–3 se přikládají ke *každému* promptu jako společná hlavička.

---

## 1. Globální konvence

| Parametr | Hodnota |
|---|---|
| Jednotky | 1 Blender unit = 1 metr, metrický systém |
| Osy | +X = doprava, **+Y = směr cesty (kupředu)**, +Z = nahoru |
| Počátek (0,0,0) | práh vstupních dveří domu |
| Referenční měřítko | robot je vysoký ~0,8 m; cesta je široká 1,2 m; dveře 0,9 × 2,0 m |
| Celková délka scény | ~200 m ve směru +Y |
| Rozpočet trojúhelníků | celá scéna 150 000–250 000 tris |
| Shading | **výhradně flat shading** (`shade_flat`), žádné smooth normály, žádné bevely s více než 1 segmentem |
| UV | negenerovat, žádné textury — barva nese materiál |
| Origin objektů | vždy v základně objektu (dole uprostřed), aby šlo snadno sázet na terén |
| Apply transformace | scale a rotace applyovat, location ponechat |

### 1.1 Pojmenování

`<sekce>_<skupina>_<prvek>_<index>`, např. `A_plot_sloupek_012`, `C_les_borovice_037`.
Prefixy sekcí: `A` zahrada, `B` louka, `C` rybník, `D` les, `E` hora, `F` jeskyně, `T` terén.

### 1.2 Kolekce

```
Krajina
├── T_Teren
├── A_Zahrada
├── B_Louka
├── C_Rybnik
├── D_Les
├── E_Hora
├── F_Jeskyne
└── X_Helpers        (empties, značky, kamera, světla)
```

### 1.3 Pravidla pro generovaný kód

1. Skript musí být **deterministický**: nahoře jedna konstanta `SEED = 12345`, veškerá náhoda přes `rng = random.Random(SEED)`. Dvě spuštění = identická scéna.
2. Nahoře souboru blok konstant (rozměry, počty, barvy) — vše laditelné bez zásahu do těla kódu.
3. Geometrii tvořit přes `bpy.data.meshes.new()` + `mesh.from_pydata(verts, edges, faces)` nebo přes `bmesh`. **`bpy.ops.*` nepoužívat v cyklech** (je to řádově pomalejší a mění aktivní kontext).
4. Opakované prvky (tráva, stromy, kameny, rákos) tvořit jako **linked duplicates**: jednou vytvořit prototyp mesh datablock, pak `bpy.data.objects.new(name, proto.data)`. Varianty dělat rotací a nestejnoměrným scale, ne novou geometrií. Pro každý typ 3–5 prototypů.
5. Skript je **idempotentní**: na začátku smaže objekty a kolekce, které sám vytváří (podle prefixu jména), a pak staví znovu.
6. Kód členit do funkcí `build_terrain()`, `build_garden()`, … a jedné `main()`. Žádná logika v globálním scope kromě konstant a volání `main()`.
7. Funkce pro sázení na terén: `snap_to_ground(x, y) -> z` — vrací výšku terénu podle stejné analytické funkce, jakou používá generátor terénu (kap. 3). Vše, co stojí na zemi, se sází přes ni. Nepoužívat raycast, pokud to jde analyticky.
8. Každý objekt dostane přiřazený materiál z centrálního slovníku `MATERIALS` (kap. 2), vytvořeného funkcí `get_material(name)`, která materiál recykluje, pokud už existuje.

---

## 2. Materiálová paleta

Všechny materiály: Principled BSDF, `use_nodes=True`, Roughness 0,85 pokud není uvedeno jinak, Metallic 0, Specular 0,2. Žádné textury.

| Klíč | Barva (hex) | Poznámka |
|---|---|---|
| `trava_zahrada` | `#6FA83C` | sytější, „posekaná“ |
| `trava_louka` | `#7FB84A` | |
| `trava_ridka` | `#8B9A5B` | horský porost |
| `hlina_cesta` | `#9A7A53` | ušlapaná hlína |
| `hlina_holy` | `#6B5539` | udupaná zem v kůlně, mraveniště, břeh |
| `kamen_dlazba` | `#9C9891` | dlažební kameny |
| `kamen_skala` | `#7D7A76` | skála |
| `kamen_balvan` | `#8A8681` | volné balvany |
| `mech` | `#5C7A3E` | Roughness 0,95 |
| `drevo_plot` | `#A87C4E` | ošlehané, světlejší |
| `drevo_tmave` | `#6E4E2E` | kůlna, rumpál, lávka |
| `drevo_kmen` | `#5A4632` | kmeny stromů |
| `beton` | `#B4B0A6` | studna |
| `guma_hadice` | `#3E6B4C` | Roughness 0,5 |
| `kov` | `#8C8F94` | Metallic 0,9, Roughness 0,35 |
| `omitka_dum` | `#E4D9C3` | |
| `strecha` | `#A8443A` | |
| `jehlici_zeme` | `#7A5B3A` | suché jehličí |
| `jehlici_zelen` | `#3F6B3A` | koruny borovic |
| `listi_tmave` | `#3E7A46` | keře |
| `listi_svetle` | `#5FA05A` | koruna velkého stromu |
| `voda_rybnik` | `#3D7A8C` | Alpha 0,75, Roughness 0,08, Transmission 0,3 |
| `voda_potok` | `#5AA0AE` | Alpha 0,7, Roughness 0,05 |
| `lekniny` | `#4A8A4E` | |
| `rakos` | `#96A54C` | |
| `kvet_*` | `#E24A4A`, `#F2C230`, `#E27ACF`, `#F0F0F0`, `#7A6FE0` | 5 variant: červená, žlutá, růžová, bílá, fialová |
| `plody` | `#B9243C` | lesní plody |
| `lava` | `#FF5A0A` | Emission Color `#FF7A1A`, Emission Strength **8,0** |
| `lava_kura` | `#3A1E14` | ztuhlá krusta, Emission Strength 0,4 |
| `skala_jeskyne` | `#4A4340` | |

---

## 3. Terén — globální řešení

Terén je **jedna souvislá mřížka** (`T_teren_hlavni`), ne dlaždice.

* Rozsah: X ∈ ⟨−45, +35⟩, Y ∈ ⟨−10, +185⟩.
* Rozlišení mřížky: **1,0 m** v rovinné části (Y < 110), **1,5 m** v horské části. Pokud to je pro model složité, použít jednotných 1,0 m — vyjde ~13 000 quadů, což je akceptovatelné.
* Výška `z = height(x, y)` je analytická funkce, složená z těchto členů (a stejná funkce musí být dostupná pro `snap_to_ground`):

```
height(x, y):
    z = 0
    # A) zahrada, Y < 21: rovina
    # B) louka, 21 <= Y < 70: příčný sklon (vrstevnice běží ve směru Y)
    if Y >= 21:  z += 0.08 * x * smoothstep(21, 26, y)
    # C) mírné stoupání k lesu
    z += lerp(0, 4.0, smoothstep(70, 112, y))
    # D) hora
    z += lerp(0, 42.0, smoothstep(112, 172, y)) ** kužel: viz 8.1
    # E) mísa rybníka: eliptická deprese, střed (-28, 44), viz 6.2
    # F) koryto potoka: úzký zářez, viz 6.1
    # G) mikrošum: value noise, amplituda 0.12 m, měřítko 6 m
    return z
```

* **Důležité: sklon louky je příčný.** Terén klesá směrem k −X, stoupá k +X. Cesta proto vede po vrstevnici (X ≈ 0, konstantní Z) a potok teče napříč z +X k −X do rybníka. To je jádro kompozice sekce B.
* Terén má vertex color / material zóny podle výšky a Y: zahrada `trava_zahrada`, louka `trava_louka`, les `jehlici_zeme`, hora `trava_ridka` → `kamen_skala`, břeh rybníka `hlina_holy`. Řešit **rozdělením ploch do materiálových slotů podle středu polygonu**, ne texturou. Přechody musí být „zubaté“ podél hran polygonů (low-poly estetika), ne rovné čáry — přechodovou hranici rozmlžit náhodným prahem ±2 m.
* Cesta se do terénu nezapouští; je to samostatná geometrie (kap. 4) položená 3 cm nad terén.

---

## 4. Cesta (průběžný prvek celou scénou)

Cesta je páteř scény. Definovaná jako **polyline bodů** v konstantě `PATH_POINTS`, z níž se generuje pás geometrie.

Trasa (X, Y):
```
(0, 0) dveře domu → (0, 21) branka → (0.5, 30) → (-0.5, 46) brod přes potok
→ (0, 60) → (0.8, 72) vstup do lesa → (-1.5, 88) míjí mraveniště
→ (0.5, 104) → (0, 116) úpatí hory → (2, 130) → (-3, 142) serpentina
→ (2.5, 150) → (0, 156) ústí jeskyně
```
Mezi body interpolovat Catmull-Rom nebo alespoň lomeně s vloženými body po 2 m.

* **Šířka:** 1,2 m v zahradě a na louce, 1,0 m v lese, 0,8 m a nepravidelná na hoře.
* **Úsek 0–21 m (zahrada): kamenná dlažba.** Jednotlivé nepravidelné ploché kameny, ne souvislý pás: 5–7 nepravidelných hexagonálních/pentagonálních plátů na 1 m délky, tloušťka 6 cm, mezery 3–6 cm, každý s náhodným natočením ±20° a náhodným posunem ±5 cm. Materiál `kamen_dlazba`, drobná výšková variace ±1,5 cm (některé kameny lehce zapadlé).
* **Úsek 21+ (louka, les, hora): ušlapaná hlína.** Souvislý pás, materiál `hlina_cesta`, okraje nepravidelné — vrcholy okraje posunout náhodně ±12 cm do stran. Pás kopíruje terén (Z z `snap_to_ground` + 0,03).
* Na hoře cesta postupně mizí: od Y = 140 zúžit na 0,8 m, od Y = 150 přerušovat (vynechat náhodně 30 % segmentů) — přechází v pěšinu mezi kameny.

---

## 5. Sekce A — Zahrada (Y ∈ ⟨−6, 21⟩, X ∈ ⟨−12, 12⟩)

Terén rovný, Z = 0 ± mikrošum. Materiál `trava_zahrada`.

### 5.1 Dům
Modelovat jen průčelí a mělkou hmotu (hráč dovnitř nejde): kvádr X ∈ ⟨−5, 5⟩, Y ∈ ⟨−6, 0⟩, výška 4,2 m k okapu.
* Sedlová střecha, hřeben ve výšce 6,8 m, přesah 0,4 m na všechny strany, materiál `strecha`.
* Vstupní dveře ve stěně Y = 0, střed X = 0, 0,9 × 2,0 m, zapuštěné 8 cm, materiál `drevo_tmave`. Nad nimi malá stříška (kvádr 1,6 × 0,7 × 0,08 m ve výšce 2,3 m) na dvou šikmých vzpěrách.
* Dvě okna ve stěně Y = 0 na X = −2,8 a X = +2,8, 1,0 × 1,2 m, parapet 1,1 m, rám 8 cm `drevo_tmave`, sklo `kov` s Roughness 0,1.
* Okap: hranol 8 × 8 cm podél okapové hrany + jeden svod dolů na X = −4,6 do sudu.
* Práh: kamenný kvádr 1,4 × 0,5 × 0,12 m.
* Dva schody z dlažby mezi prahem a začátkem cesty.

### 5.2 Plot a branka
Dřevěný plot ohraničující zahradu po obvodu: strany X = ±12 (Y od 0 do 21) a čelo Y = 21 (X od −12 do 12). U domu plot navazuje na roh fasády.
* Sloupky 10 × 10 cm, výška 1,1 m, rozteč 1,8 m, každý s náhodným náklonem ±2,5° (plot není nový).
* Mezi sloupky dvě vodorovné latě 8 × 3 cm ve výškách 0,35 a 0,85 m.
* Svislé plaňky 10 × 2 cm, výška 1,0 m, rozteč (mezera) 6 cm, horní hrana seříznutá do špičky (jeden zkosený vrchol). 3–5 plaňek v celém plotě náhodně chybí, 4–6 je nakloněných o ±4°.
* **Branka** na Y = 21, X ∈ ⟨−0,7, 0,7⟩: rám z latí + 6 plaňek, výška 1,05 m, pootočená kolem levého sloupku o 12° (pootevřená). Dvě panty (kov, 12 × 4 cm) a jednoduchá klika/západka z kovu.

### 5.3 Trávník a záhonky
* Trávník: shluky stébel po celé ploše mimo cestu, dlažbu a půdorysy staveb. Hustota ~1,2 shluku / m². Shluk = 4–6 stébel, stéblo = 3 trojúhelníky (úzký zužující se pás, výška 8–14 cm, náhodné natočení a mírný ohyb). V zahradě nižší než na louce.
* **Záhonky** (3 ks): elipsy s obrubou z malých kamenů (8–12 kamenů kolem obvodu, každý ~15 cm).
  * Z1 střed (5,0, 6,0), rozměr 3,0 × 1,8 m
  * Z2 střed (6,5, 13,0), rozměr 2,2 × 2,2 m
  * Z3 střed (−6,0, 5,0), rozměr 2,6 × 1,4 m
  * Půda `hlina_holy`, mírně vypouklá (+6 cm ve středu).
  * Květiny: 18–30 na záhon. Stonek (3 tris, výška 20–35 cm), 5–6 okvětních lístků jako plochý ico/kužel o průměru 8–12 cm, střed žlutá kulička. Náhodně z 5 barev `kvet_*`. Náklon ±10°.

### 5.4 Studna s rumpálem — střed (−4,0, 12,0)
* Betonová skruž: válec, vnější Ø 1,2 m, vnitřní Ø 0,9 m, výška nad zemí 0,8 m, **8 segmentů** (nikoli 32). Materiál `beton`, horní hrana jako plochý prstenec.
* Dvě dřevěné svislé vzpěry 8 × 8 cm po stranách, výška 1,6 m nad korunou, nahoře spojené vodorovným trámem.
* **Rumpál:** vodorovný válec Ø 18 cm, délka 1,0 m, materiál `drevo_tmave`, mezi vzpěrami ve výšce 1,3 m. Na pravé straně klika: dvě kolena z hranolu 6 × 6 cm + válcová rukojeť.
* Lano: 3–4 segmenty tenkého válce Ø 2 cm vinuté kolem rumpálu (stačí naznačit 3 závity) + svislý úsek dolů do studny, na konci dřevěný okovaný kbelík (komolý kužel, Ø 26 → 22 cm, výška 28 cm, dvě kovové obruče, drátěné ucho).
* Stříška nad studnou: malá sedlová stříška 1,6 × 1,4 m opřená o vzpěry, 5 prkének na každou stranu, materiál `drevo_plot`.
* **Kontrast staré/nové:** z boku skruže vede **zahradní hadice**. Modelovat jako trubku o Ø 2,5 cm sledující polyline: vývod ze skruže ve výšce 0,5 m → přes okraj → po zemi obloukem → 3 volné smyčky (Ø ~60 cm) položené na trávě u studny → konec s **kovovou mosaznou koncovkou** směřující k záhonu Z1. Materiál `guma_hadice` + `kov`. U vývodu ze skruže malý moderní prvek: bílý plastový kvádr 12 × 8 × 20 cm (čerpadlo/box) s krátkým kabelem, materiál světle šedý.

### 5.5 Kůlna na nářadí — střed (−7,5, 14,5)
Půdorys 2,4 × 2,0 m, výška 2,0 m vpředu / 2,25 m vzadu (pultová střecha spádovaná dozadu). Vchod (bez dveří, nebo dveře opřené vedle) směrem k cestě.

**„Jen tak postavená“ — tohle musí být vidět:**
* Celá stavba **natočená o 6°** kolem osy Z oproti plotu a **nakloněná o 2°** v ose X.
* Bez základu — spodní hrana prken se místy nedotýká země (mezera 0–4 cm), místy je zapuštěná.
* Stěny z **jednotlivých svislých prken** 18 × 2 cm, mezery 1–4 cm, každé prkno s náhodným náklonem ±1,5° a náhodnou délkou (horní hrana není rovná, přesahy 0–8 cm).
* Rohové sloupky 8 × 8 cm, dva zapřené šikmé trámy (vzpěry) zvenku.
* Střecha: 6–7 prken přeložených přes sebe, na nich dva kameny „proti větru“. Jedno prkno posunuté = viditelná mezera.
* **Podlaha:** samostatná mesh — udupaná zemina, obdélník 2,6 × 2,2 m (přesahuje půdorys o 10 cm), Z = −0,02, materiál `hlina_holy`, okraj nepravidelný (vrcholy ±15 cm). **V tomto obdélníku a 30 cm kolem něj negenerovat žádnou trávu** — vyšlapaný, holý plac, který pokračuje ještě ~1 m směrem k cestě jako vyšlapaná stopa.
* Vybavení uvnitř a vně: opřené hrábě, lopata, motyka (násada = válec Ø 3,5 cm, délka 1,4 m, hlava jednoduchý plech), plechová konev, dva kbelíky, hromádka květináčů, dřevěný ponk 1,2 × 0,5 × 0,8 m, na něm 3–4 drobné předměty (bedýnka, plechovka).

### 5.6 Ostatní prvky zahrady (doplňkový detail)
* **Sud na dešťovku** pod svodem u domu, (−4,6, 0,8): válec Ø 0,7 m, výška 0,9 m, 10 segmentů, dřevěná prkna + 3 kovové obruče, uvnitř tmavá vodní hladina 12 cm pod okrajem.
* **Kolečko** (trakař) u kůlny, (−6,0, 12,0): korba jako komolý jehlan, jedno kolo, dvě rukojeti, dvě nožky. Natočené šikmo, ne v ose.
* **Hromada palivového dřeva** u boční stěny domu, (3,8, 1,5): 22–30 polen (válce Ø 10–14 cm, délka 35 cm, 6 segmentů) urovnaných do 4 vrstev, pár rozházených před hromadou. Zastřešená dvěma prkny.
* **Kompost** v rohu (−10,5, 18,5): otevřená bedna z prken 1,2 × 1,2 × 0,8 m, uvnitř vypouklá hmota `hlina_holy` s pár zelenými útržky.
* **Sušák na prádlo:** dva dřevěné kůly (Y = 8 a Y = 14 na X = 8) a mezi nimi 2 šňůry (tenké válce s mírným průvěsem — 5 segmentů). Na nich 3 kusy prádla jako mírně zvlněné ploché obdélníky (0,5 × 0,7 m) + 4 kolíčky.
* **Ptačí budka** na kůlu u plotu (10,0, 16,0), výška 2,2 m: kvádr 16 × 16 × 22 cm, kulatý otvor, stříška, bidýlko.
* **Dva okrasné keře** u domu na (−3, 1,2) a (3, 1,2): ico-sféra Ø 0,9 m, mírně zploštělá, subdivision 1, materiál `listi_tmave`, na krátkém kmínku.
* **Šlapák** — 3 volné dlažební kameny odbočující z hlavní cesty ke studni a další 3 ke kůlně.
* **Zapomenuté nářadí:** hrábě položené v trávě u záhonu Z1, konev vedle Z2.
* **Pařez** u plotu (−11, 3), Ø 45 cm, výška 30 cm, s letokruhy jako 2 soustředné prstence.

---

## 6. Sekce B — Louka a potok (Y ∈ ⟨21, 70⟩)

Materiál terénu `trava_louka`. Příčný sklon (viz 3). Cesta po vrstevnici, viz kap. 4.

### 6.1 Velký strom — pozice (9,0, 24,0)
Solitér vedle zahrady, dominanta přechodu mezi zahradou a loukou.
* Výška **14 m**, kmen Ø 1,1 m u země → 0,45 m pod korunou, 7 segmentů, mírně zakřivený (3–4 patra vrcholů s posunem ±10 cm).
* Náběhy kořenů: 5 klínů u paty, roztažení do 1,8 m.
* Větvení: 4 hlavní větve od výšky 5 m, každá se 2 podvětvemi.
* Koruna: **5–7 prorůstajících ico-sfér** (subdiv 1, Ø 3,5–5,5 m), nepravidelně rozmístěných, materiál `listi_svetle`, s mírnou variací odstínu (2 varianty materiálu, o 8 % tmavší/světlejší).
* Pod stromem: kruhový plac (Ø 3 m) s řidší trávou, 5–8 opadaných kamenů, provaz s pneumatikou nebo prkénková houpačka na jedné větvi (nepovinné, ale ano — přidat).

### 6.2 Luční tráva a květiny
* Tráva: shluky, hustota ~1,8 / m², výška 15–30 cm — výrazně vyšší a divočejší než v zahradě, větší rozptyl náklonu (±20°).
* Luční květiny: **cca 400–600 kusů** rozptýlených po celé louce, s ostrůvkovitým rozložením (shluky po 8–20 kusech kolem náhodných center, ne rovnoměrně). Typy:
  * kopretina (bílé lístky, žlutý střed, 40 cm)
  * vlčí mák (červená, 45 cm)
  * chrpa (fialová, 35 cm)
  * pampeliška — dvě varianty: žlutá a bílá odkvetlá koule (Ø 5 cm, ico subdiv 1)
  * zvonek (fialový zvonek jako obrácený kužel)
* Podél cesty pás 30 cm bez trávy (ušlapaný okraj), materiál terénu přechází do `hlina_cesta`.

### 6.3 Potůček
Velmi tenký, sotva pár desítek centimetrů široký. Teče po spádnici, tj. z +X směrem k −X.
* Trasa (polyline, meandrující): `(22, 52) → (16, 50.5) → (11, 49) → (6, 48) → (0, 46) → (-6, 45.5) → (-13, 45) → (-20, 44.5) → (-25.5, 44)` ústí do rybníka.
* **Koryto** zaříznuté do terénu: šířka 0,7 m na hraně, hloubka 0,18 m, dno šířka 0,3 m. Realizovat úpravou výšky vrcholů terénní mřížky v okolí polyline (vzdálenost < 0,35 m → snížit).
* **Hladina:** úzký pás geometrie šířky 0,25–0,4 m (proměnná), 5 cm nade dnem, materiál `voda_potok`. Hladina musí kopírovat spád — potok viditelně teče z kopce.
* Detaily: 25–40 malých kamenů v korytě a na okrajích (Ø 8–20 cm), 3 z nich vyčnívají nad hladinu; mokrý pás břehu (materiál `hlina_holy`, šířka 15 cm) po obou stranách; 6–8 trsů vyšší, tmavší trávy podél toku.
* **Křížení s cestou** na (0, 46): jednoduchý **brod** — 5 velkých plochých kamenů zapuštěných do koryta, plus vedle nich **prkenná lávka**: dvě prkna 2,2 × 0,25 × 0,05 m položená přes potok, podložená na obou koncích kamenem, jedno prkno mírně pootočené.
* Pramen: na (22, 52) malá kamenná mísa / vyvěračka — půlkulová prohlubeň Ø 60 cm obložená 7 kameny.

### 6.4 Doplňky louky
* 8–12 **volných balvanů** rozptýlených po louce (Ø 0,6–2,2 m), tvarované jako ico-sféra subdiv 1 s nerovnoměrným scale a náhodným natočením, částečně zapuštěné do terénu (−20 % výšky). Na vršcích těch větších skvrny mechu.
* 2 **kupky sena** (Ø 2,5 m, výška 1,8 m — kužel se zaobleným vrškem, materiál `#C9A94E`), u nich vidle opřené o kůl.
* Zbytek staré ohrady: 6 osamělých kůlů v linii přes louku, mezi dvěma z nich visí kus rezavého drátu (materiál `kov`, hnědorezavý odstín).
* 3 **pařezy** a 2 **spadlé kmeny** (délka 3–4 m, Ø 40 cm) v trávě.
* Vyšlapaná odbočka z hlavní cesty k rybníku (užší, 0,6 m, materiál `hlina_cesta`, mizející).
* 5–8 trsů kopřiv / vyššího plevele u balvanů a pařezů (tmavší zeleň, ostřejší tvar listu — jednoduché trojúhelníky).

---

## 7. Sekce C — Rybník (střed (−28, 44))

### 7.1 Mísa a hladina
* Půdorys: nepravidelná elipsa **22 × 16 m**, obrys tvořen 14–18 body s náhodným zvlněním ±1,2 m (žádný hladký ovál).
* Terén: eliptická deprese, hloubka **1,3 m** ve středu, břehy s různým sklonem — na jižní straně (−Y) pozvolný, mělký, na severní (+Y) strmější.
* **Hladina:** samostatná plochá mesh těsně nad terénem v úrovni Z = `height` dna + 1,1 m, tvarem kopíruje obrys rybníka 20 cm za hranu vody. Materiál `voda_rybnik`. Hladina musí zůstat **z velké části volná** — viz 7.3.
* Pás břehu široký 0,8–1,5 m: materiál `hlina_holy`, bez trávy, s 20–30 malými kameny a 4–6 většími u vody.

### 7.2 Husté křoví (jen jedna strana)
Podél **severozápadní strany** (X od −40 do −30, Y od 44 do 54) souvislý pás keřů:
* 14–20 keřů, každý = 3–5 prorůstajících ico-sfér Ø 1,2–2,4 m, výška 1,5–2,8 m, na krátkých větvičkách u země.
* Materiál `listi_tmave`, dvě varianty odstínu.
* Keře stojí těsně u vody, některé částečně **převisají nad hladinu** (posunout koule o 0,5–1,2 m nad vodu) — díky tomu vrhají stín na část hladiny. Pod nimi hladina ponechána bez leknínů.
* Mezi keři 2–3 suché větve trčící do vody.

### 7.3 Vodní vegetace — **řídce!**
Pravidlo: rákos a lekníny smí zabírat **max. 25 % plochy hladiny**. Střed rybníka zůstává zcela volný.
* **Rákos:** 12–18 trsů rostoucích z mělčiny do 1,5 m od břehu, hlavně na jižní a východní straně. Trs = 7–12 stébel, výška 1,2–1,8 m, stéblo = úzký 3–4trojúhelníkový pás s náklonem ±15°, na 5 z nich hnědá palice (válec Ø 3 cm, délka 15 cm, materiál `#7A5030`). Materiál `rakos`.
* **Lekníny:** 18–25 listů, ve třech shlucích (ne rovnoměrně), spíš blíž ke břehům. List = plochý osmiúhelník Ø 35–55 cm s výřezem (jeden klín vyříznutý ke středu), Z = hladina + 1 cm, materiál `lekniny`. Na 4–5 z nich květ (bílý/růžový, 6 lístků, Ø 15 cm).
* Několik oddělených listů plovoucích samostatně mimo shluky.

### 7.4 Doplňky u rybníka
* **Prkenné molo** / lávka: 3 prkna 3,5 m dlouhá na 4 kůlech, zasahuje 2,5 m nad vodu, na jižním břehu. Lehce prohnutá, jedno prkno chybí.
* Spadlý kmen napůl ve vodě.
* 2–3 velké ploché kameny u vody (jako na sezení).
* Přítok potoka: viditelné ústí, drobné rozšíření koryta, 3 kameny.
* Odtok na protilehlé straně: úzká strouha mizící za obrazem + malá hrázka z kamenů a dřeva.
* Nad vodou u břehu 2 nahnuté kůly se zbytkem provazu.

---

## 8. Sekce D — Les (Y ∈ ⟨70, 112⟩, X ∈ ⟨−22, 22⟩)

Malý, ale **hustý** borový les.

### 8.1 Přechod terénu
* V pásu Y ∈ ⟨68, 76⟩ přechází materiál terénu z `trava_louka` na `jehlici_zeme`. Přechod **nepravidelný**: hranice pro každý polygon určena jako `y > 68 + rng.uniform(0, 8)`, takže se prolíná. Uvnitř lesa (Y > 78) žádná travní stébla, jen jehličí.
* Do pásu přechodu rozptýlit 30–40 shluků trávy postupně řidnoucích a naopak přibývající drobné jehličnaté drti (malé ploché trojúhelníky 5–10 cm, materiál `jehlici_zeme` tmavší).
* Uvnitř lesa terén mírně zvlněný (amplituda 0,4 m, měřítko 8 m) — nikoli plochý.

### 8.2 Borovice — 55–70 kusů
Hustota: minimální rozestup 2,2 m, ale kolem cesty koridor 1,6 m volný na každou stranu.
* Výška 9–17 m (rozptyl důležitý — přidat i 6–8 mladých stromků 2–4 m).
* Kmen: 8 segmentů, Ø 0,45 m u paty → 0,18 m nahoře, **holý až do 55–65 % výšky** (charakteristika borovice!), materiál `drevo_kmen`, mírné zakřivení.
* Pahýly odlomených větví na kmeni: 4–6 krátkých kuželů 20 cm.
* Koruna: **3–5 zploštělých kuželů / nepravidelných ico-sfér** naskládaných jen v horní části, Ø 2,5–4 m, celková výška koruny 35–45 % stromu, materiál `jehlici_zelen` (2 varianty odstínu). Nikoli klasický „vánoční stromek“ — koruna je nahoře, rozvolněná, deštníkovitá.
* 4–6 stromů nakloněných o 5–8°, 2 suché (bez zeleně, materiál šedohnědý).

### 8.3 Mraveniště — pozice (2,5, 88,0), u cesty
Velké, dominantní.
* Kužel Ø **2,4 m**, výška **1,3 m**, 10 segmentů, vršek mírně zaoblený a nesymetrický (posun vrcholu o 20 cm).
* Povrch nepravidelný: každý vrchol posunut náhodně o ±8 cm → hrubý „hromadový“ vzhled.
* Materiál `jehlici_zeme`, tmavší varianta.
* Opřené o patu borovice (mraveniště staví u stromu) — kmen jím prochází.
* Kolem paty rozptýlené jehličí (30–40 drobných plošek), 3–5 vyčnívajících větviček a jedna vetší suchá větev zapíchnutá ve svahu.
* Kolem mraveniště kruh 1,5 m bez keříků. **Žádná zvířata** — mravenci se nemodelují.

### 8.4 Podrost
* **Keříky s lesními plody:** 35–50 kusů. Keřík = 3–4 zploštělé ico-sféry Ø 40–70 cm, výška 30–50 cm, materiál `listi_tmave`. Na 60 % z nich 5–12 plodů: kuličky Ø 4 cm, materiál `plody`, umístěné na povrchu koule. Shlukovat po 3–6 kusech.
* **Pařezy:** 8–10, Ø 30–60 cm, výška 20–45 cm, s prstenci letokruhů a 2–3 kořenovými náběhy, některé s mechem.
* **Spadlé kmeny:** 4–5, délka 3–6 m, Ø 30–50 cm, částečně zapuštěné, jeden přes cestu (přeskočitelný, nebo s vysekanou mezerou v místě cesty).
* **Hromady klestí:** 3 ks, 12–20 náhodně nakupených větví (válce Ø 4–8 cm, délka 0,8–1,6 m).
* **Houby:** 15–25 kusů ve skupinkách po 2–5 u pařezů a kmenů. Klobouk = kužel/půlkoule Ø 8–14 cm, nožka válec. Dvě barvy: hnědá `#7A5A3A` a červená s bílými tečkami `#C8302A` (tečky jako 4–5 malých plošek, nebo vynechat pro jednoduchost).
* **Kameny:** 12–18, částečně obrostlé mechem.
* **Balvan** s mechem u cesty na (−4, 96), Ø 1,8 m.
* **Turistická značka / zářez** na jednom kmeni u cesty: dva ploché obdélníčky (bílá–červená–bílá) 12 × 10 cm ve výšce 1,5 m.
* Světelné podmínky se řeší až ve scéně, ale koruny mají být dost husté, aby vznikaly ostrůvky prosvitu — nechat 3–4 mezery mezi stromy nad cestou.

---

## 9. Sekce E — Hora (Y ∈ ⟨112, 175⟩)

### 9.1 Tvar
* Kužel/masiv se středem osy na (0, 178), stoupající od Z = 4 na Y = 112 až po Z ≈ 46 na Y = 172. Sklon **není konstantní**: mírný v úpatí (10°), strmý ve střední části (35°), nahoře přechod ve skalní stěnu (55–70°).
* Silueta nepravidelná: na výšku terénu přidat velké nízkofrekvenční zvlnění (amplituda 2,5 m, měřítko 20 m) a v horní části ostré fasety — v pásmu skály přepnout terén do **plochých, velkých trojúhelníkových fazet** (rozlišení mřížky zhrubnout na 3 m, vrcholy posunout o ±0,8 m). Skála musí být hranatá, ne oblá.
* Dva boční hřbety, mezi nimi mělká rokle, kterou vede cesta.

### 9.2 Výškové zóny (přechody nepravidelné, ±2 m jitter)
| Zóna | Rozsah | Terén | Vegetace |
|---|---|---|---|
| Úpatí | Z 4–12 | `jehlici_zeme` → `trava_ridka` | doběh lesa, řídnoucí borovice |
| **Horní hranice lesa** | Z ≈ 13–15 | | poslední stromy: 8–12 nízkých (3–6 m), zkroucených, nakloněných po směru větru (náklon 8–14° konzistentně k jedné straně), 3 suché a holé |
| Travnatý pás | Z 15–25 | `trava_ridka` | **velmi řídké** trsy (hustota 0,25/m²), nízké (10 cm), ve shlucích ve spárách; 10–15 malých kvítků; kameny přibývají |
| Suťové pole | Z 22–30 | `kamen_balvan` | 120–200 kamenů Ø 0,2–1,2 m, hustě, sesypaných do jazyků po spádnici |
| Skála | Z > 28 | `kamen_skala` | žádná tráva, **mech ve skvrnách** |

### 9.3 Mech na skále
* 40–60 nepravidelných plochých skvrn kopírujících skálu, průměr 0,4–1,5 m, tloušťka 3 cm, materiál `mech`, offset 2 cm nad povrchem.
* Umisťovat přednostně do spár, na severní strany a k patám balvanů — ne rovnoměrně. Nikdy nepokrývají víc než ~15 % skalní plochy.

### 9.4 Doplňky hory
* **Mohyla** (kamenný muž) u cesty na (2, 148): 7–9 plochých kamenů na sobě, výška 0,9 m, mírně nakloněná.
* 3 velké **balvany** Ø 2,5–4 m ležící ve svahu, jeden zaklíněný nad cestou.
* Suchý zkroucený strom (holý, 4 m) na skalnaté vyhlídce (−6, 150).
* 2 malé skalní výběžky (věže) 3–5 m vysoké po stranách rokle.
* Odlomená deska skály opřená o stěnu (vytváří přístřešek).
* Osamocený trs trávy vyrůstající přímo ze spáry těsně u vchodu do jeskyně — detail kontrastu.

### 9.5 Vchod do jeskyně — pozice (0, 156), úroveň podlahy Z = `height(0,156)`
* Portál v kolmé skalní stěně: otvor **3,4 m široký, 3,0 m vysoký**, tvar nepravidelný osmiúhelník (žádný pravidelný oblouk).
* Stěna kolem portálu je svislá plocha 12 × 8 m, fasetovaná.
* Před vchodem plošina 5 × 4 m z ušlapané hlíny a kamenů.
* 4–6 velkých balvanů po stranách vchodu, 2 nad ním jako překlad.
* **Ze vchodu ven prosvítá oranžové světlo:** v ústí umístit ploché svítící pole (obdélník 3,2 × 2,8 m v rovině portálu, materiál `lava` s Emission Strength 3,0) — je to náznak, vlastní zdroj světla je uvnitř. Plus 3–4 oranžové skvrny na skále a zemi před vchodem (materiál s nízkou emisí, Strength 0,8), jako odlesk.

---

## 10. Sekce F — Jeskyně (Y ∈ ⟨156, 198⟩, uzavřený interiér)

Modelovat jako **samostatný objekt v samostatné kolekci** `F_Jeskyne`, ne jako výřez v terénu. Do terénu se pouze udělá otvor v místě portálu (odstranit polygony v obdélníku 4 × 3 m).

### 10.1 Tvar chodby
Chodba = protažená trubka podél polyline s **nepravidelným, hranatým** průřezem (8 vrcholů, poloměr 1,8–3,2 m, u každého řezu jiný, náhodně posunutý). Normály směřují dovnitř.
* Trasa: `(0, 156, 0) → (1.5, 162, -0.4) → (-1, 168, -1.0) → (0.5, 174, -1.2) → (2, 182, -0.8) → (0, 190, -0.5) → (0, 198, -0.5)` (Z relativně k úrovni portálu, chodba mírně klesá a pak se srovná).
* Řezy po 2 m, mezi nimi propojení quadem/trojúhelníky, flat shading.
* Podlaha: v každém řezu spodní vrcholy srovnat do plochy → chůze je možná; podlaha materiál `skala_jeskyne`, mírně nerovná (±10 cm).
* Strop v místě 3 zúžení klesá na 2,2 m (dramatizace), jinde 3,5–5 m.

### 10.2 Enklávy (postranní komory) — 4 ks
Napojené na chodbu, každá jiná. Realizovat jako samostatné nepravidelné dutiny navázané na chodbu krátkým hrdlem (2 m).
1. **E1 (levá, Y = 164):** malá, 4 × 4 m, výška 2,5 m, uvnitř **lávové jezírko** Ø 1,8 m — hlavní světelný zdroj této části.
2. **E2 (pravá, Y = 171):** vyšší komín, 3 × 3 m, strop 7 m, ze stropu visí 5 stalaktitů; suchá, tmavá, osvětlená jen odleskem.
3. **E3 (levá, Y = 179):** široká, 6 × 5 m, na podlaze **lávová puklina** (klikatá trhlina délky 4 m, šířka 0,3–0,7 m) a hromada ztuhlé lávy.
4. **E4 (pravá, Y = 187):** malá slepá kapsa 2,5 × 2,5 m, na podlaze rozsypané kameny, na stěně vyleštěná černá plocha (obsidián, Roughness 0,15).

### 10.3 Láva
* **Lávová jezírka:** 3 ks (E1, hlavní chodba na Y = 176 u stěny, E3-puklina). Tvar: nepravidelný mnohoúhelník, hladina 5 cm nad podlahou, mírně vypouklá.
* Struktura hladiny: **plochy materiálu `lava` prostoupené deskami krusty `lava_kura`** — hladinu rozdělit na 8–14 nepravidelných polygonů, z nichž 60 % dostane materiál `lava_kura` (tmavá krusta) a mezi nimi zůstanou svítící „žíly“. To je klíčový vzhled: čerstvá láva se ztuhlou krustou.
* **Slitky:** 6–10 menších tuhnoucích cákanců rozptýlených po podlaze chodby (ploché placky Ø 20–60 cm, tmavá krusta se svítícím okrajem).
* Ze dvou puklin ve stěně vytéká tenký lávový pramínek (šířka 15 cm) po stěně dolů do jezírka.
* **Emise nese osvětlení scény.** Doplnit 5 bodových světel (Point light, barva `#FF6A18`, energie 300–800 W, poloměr 0,5 m) umístěných 20 cm nad středy lávových ploch, do kolekce `X_Helpers`. Žádné jiné světlo uvnitř jeskyně.

### 10.4 Detaily jeskyně
* **Stalaktity** 20–30 ks (kužely dolů, délka 0,3–1,5 m, Ø 0,1–0,35 m, 6 segmentů) a **stalagmity** 12–18 ks (kužely nahoru), 2 dvojice spojené ve sloup.
* Rozsypané kameny po podlaze: 40–60 ks Ø 10–50 cm, hustěji u stěn.
* Ostré fasety na stěnách — několik plošných výběžků a říms.
* Praskliny: 6–10 tmavých úzkých zářezů ve stěnách (tenké prohlubně).
* U vchodu první 4 m ještě denní světlo → v tomto úseku bez emisních prvků, pár kapradin/mechu na kamenech.

### 10.5 Zasypaný východ (Y = 196) — dějově klíčový
* Chodba na konci pokračuje portálem 3,0 × 2,6 m, který je **zcela zavalený kameny**.
* Zával: **18–26 samostatných balvanů** Ø 0,5–1,8 m, naskládaných tak, aby vyplnily celý průřez. Každý je vlastní objekt s vlastním originem ve svém těžišti (**musí být jednotlivě animovatelné / odvalitelné**) a jménem `F_zaval_balvan_01`…, ve vlastní podkolekci `F_Zaval`.
* Mezi balvany 2–3 úzké škvíry, kterými prosvítá **slabé teplé bílé světlo** zvenčí (materiál emise `#FFF3D0`, Strength 1,5) — náznak, že za závalem něco je. Světlo musí být jasně odlišné od oranžové lávy.
* Za závalem umístit:
  * `X_helper_empty_ZaZavalem` (Empty Plain Axes) na (0, 199, podlaha) — kotva pro budoucí obsah,
  * zaslepovací plochu 4 × 3,5 m s materiálem `#FFF3D0`, Emission Strength 2,5, aby po odvalení nebyla vidět prázdnota,
  * skryté (`hide_viewport = True`, `hide_render = True`) prázdné podkolekce `F_ZaZavalem` pro pozdější obsah.
* Před závalem volný prostor 4 × 4 m (finální aréna), podlaha rovnější, po stranách 2 lávová jezírka jako osvětlení.

---

## 11. Akceptační kritéria (checklist pro kontrolu výstupu)

1. Skript proběhne bez chyb na čisté scéně a je opakovatelně spustitelný (idempotence).
2. Dva běhy se stejným `SEED` dají shodnou scénu.
3. Vše je flat-shaded, nikde nejsou smooth normály.
4. Žádný objekt se nevznáší nad terénem ani do něj nezapadá (kromě záměrně zapuštěných kamenů a balvanů).
5. Cesta je průchozí a spojitá od dveří domu až k závalu v jeskyni.
6. Sklon louky je příčný, potok teče viditelně z kopce, cesta vede po vrstevnici.
7. Hladina rybníka je z převážné části volná (vegetace ≤ 25 % plochy), keře jsou jen z jedné strany.
8. Kůlna je zjevně křivá a bez základu, pod ní a kolem ní neroste tráva.
9. V lese nejsou travní stébla, jen jehličí; borovice mají holé kmeny do poloviny výšky.
10. Horní hranice lesa je čitelná: je vidět místo, kde stromy končí.
11. Jediné světlo v jeskyni pochází z lávy; za závalem je odlišné teplé bílé světlo.
12. Balvany závalu jsou samostatné objekty s originem v těžišti.
13. **Ve scéně není žádné zvíře, hmyz, pták ani ryba.**
14. Celkový počet trojúhelníků je v rozpočtu; vypsat ho na konci skriptu do konzole po sekcích.

---

## 12. Doporučené pořadí promptů pro slabší model

Ke každému promptu přiložit kapitoly 1–3. Každý krok = samostatný skript, který lze spustit nezávisle (načte/vytvoří terén, pokud chybí).

| # | Prompt | Výstup |
|---|---|---|
| 1 | Kap. 1–3 + „vygeneruj terén a materiálovou paletu“ | `01_teren.py` |
| 2 | Kap. 4 | `02_cesta.py` |
| 3 | Kap. 5.1–5.2 | `03_dum_plot.py` |
| 4 | Kap. 5.3–5.6 | `04_zahrada.py` |
| 5 | Kap. 6 | `05_louka_potok.py` |
| 6 | Kap. 7 | `06_rybnik.py` |
| 7 | Kap. 8 | `07_les.py` |
| 8 | Kap. 9 | `08_hora.py` |
| 9 | Kap. 10 | `09_jeskyne.py` |
| 10 | Kap. 11 | kontrolní skript, který vypíše statistiky a ověří body 3, 4, 14 |

**Společné knihovní funkce** (`common.py` nebo blok na začátku každého skriptu): `get_material()`, `height()`, `snap_to_ground()`, `new_mesh_object()`, `scatter()` (rozptyl bodů s minimální roztečí, Poisson-like přes rejection sampling), `link_dup()` (linked duplicate s náhodnou rotací a scale), `jitter_verts()`.

---

## 13. Poznámky ke scéně (nepovinné, ale doporučené)

* **Slunce:** Sun light, energie 3,0, úhel 25°, natočení tak, aby svítilo zezadu-zprava (od +X, +Y) — velký strom i les tak vrhají dlouhé stíny přes cestu.
* **World:** obloha jednoduchý gradient `#8FC6E8` → `#DCEEF6`, Strength 0,6.
* **Kamera:** 3 uložené pohledy — zahrada od domu k brance, louka s rybníkem shora, vchod do jeskyně.
* **Export:** každou sekci samostatně jako `.glb` (`A_zahrada.glb`, …), aby šly v enginu načítat po částech a řídit viditelnost podle vzdálenosti.
