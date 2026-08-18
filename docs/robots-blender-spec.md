# Nature Cybernetic Robots — Modelovací spec

> Zdroj pravdy pro **vizuální tvar** robotů. Herní mechaniku definuje `design-document.md` §1.1 a `technical-design.md` §10 — tento dokument z nich vychází, ale neopakuje pravidla hry, jen jejich fyzický výraz. Kde spolu nesouhlasí, vyhrává design dokument.
>
> **Jednotka:** 1 grid cube = 1.0 Blender unit (u). Všechny rozměry níže jsou v `u` a vztahují se k tomu, jak robot sedí v jedné buňce mřížky (pokud není řečeno jinak — někteří roboti mohou přesahovat do sousední buňky vizuálně, ale ne kolizně).
>
> **Stav:** koncept, před prvním modelováním. Rozměry jsou návrh k ověření na prvním pilotním robotovi, ne finální čísla.

---

## 0. Sdílené prvky (platí pro všech 7)

### 0.1 Centrální jednotka ("hlava/jádro")

Jediný geometricky identický prvek napříč roboty — modeluje se **jednou** jako samostatný objekt/asset a linkuje/instancuje do každého robota, ne kopíruje.

| Parametr | Hodnota |
|---|---|
| Tvar | 2× polokoule, spojené rovníkovým švem |
| Průměr | 0.3u (fixní, stejný u všech 7 robotů) |
| Spoj | viditelný prstenec nýtů na švu — 12–16 nýtů, rovnoměrně |
| Materiál | šedý kov, matný, pokrytý lesklým lakem barvy příslušného robota, jemné škrábance (use-wear) |
| Nápis | hangul, foneticky jméno robota — vypálený/gravírovaný, na horní polokouli, čelem ke „přední" straně robota, světlejším nebo tmavším odstínem stejné barvy |
| Umístění na robotovi | nejvyšší/nejexponovanější bod siluety — funguje jako „hlava" i tam, kde tělo samo hlavu nemá (Dul, Han) |

**Poznámka k hangulu:** přepis jmen napřesno (Han, Dul, Set, Net, Da, Yeo, Il) doladit při modelování — jde o fonetický přepis, ne o existující korejská slova, takže si zaslouží samostatnou kontrolu (např. přes IME nebo rodilého mluvčího), než se vypálí do 7 modelů.

### 0.2 Barevná konvence

Barva = plášť/karoserie, ne celý model. Klouby, nástroje a mechanismy zůstávají neutrální kov (tmavá ocel/hliník), aby barva čitelně označovala „tohle je Han" z dálky a nepřebíjela funkční detaily.

| Robot | Barva pláště |
|---|---|
| Han | hnědá |
| Dul | modrá |
| Set | červená |
| Net | zelená |
| Da | azurová |
| Yeo | bílá |
| Il | žlutá |

### 0.3 Konvence konstrukce

- CSG přístup jako u architektury: hrubá hmota → subtrakce/detaily → ruční overlay.
- Funkční mechanismus (lžíce, tryska, plamenomet...) modelovat jako **samostatný objekt** napojený na tělo kloubem/attachment pointem — usnadní to pozdější animaci v Godotu i nezávislé úpravy.
- Kola/nohy jsou vždy samostatné objekty (kvůli případné budoucí animaci pohybu).

---

## 1. Han — Zemní (hnědá)

**Funkce → tvar:** hrábne kostku hlíny do korby (Akce 1), korbu vyklopí za sebe (Akce 2). Dosah dopředu/dolů/šikmo-dolů.

| Prvek | Popis |
|---|---|
| Podvozek | kola nebo pásy, nízko posazený, šířka ~0.7u |
| Hlavní rameno | kloubové, 2–3 segmenty, vpředu, dosah pokrývá „ahead", „ahead_below", „ahead_diagonal_below" |
| Nástroj na rameni | hrabací lžíce, otevřená nahoru, use-wear barva (hlína/rez na hraně) |
| Korba | na zádech, orientace dozadu, sklopná (čep vzadu dole) |
| Stav „prázdná" vs „plná" | korba musí být čitelná zvenku — buď průhled dovnitř, nebo viditelný násyp hlíny při „plná" |
| Jádro | na vrcholu těla, mezi ramenem a korbou |

---

## 2. Dul — Vodní (modrá)

**Funkce → tvar:** obojživelný. Na souši kola, ve vodě vodní tryska (nasává vepředu, vytlačuje vzadu → tah). Vertikální pohyb ve vodě bez limitu ponoru.

| Prvek | Popis |
|---|---|
| Trup | torpédovitý/hladký, ~0.9u délka — hladkost je funkční (klouže po ledu, plave) |
| Podvozek | zatažitelná/nízkoprofilová kola pro souš — nesmí rušit hydrodynamickou siluetu |
| Sání (příď) | mřížka/otvor vepředu, napojené na Akci 1 (načerpání) |
| Výtok (záď) | tryska/lodní šroub vzadu, napojené na Akci 2 (vypuštění) — vizuálně stejný prvek slouží jako pohon i jako vypouštěcí ústí |
| Cisterna | vnitřní objem naznačený průhledem/poklopem nahoře |
| Jádro | na hřbetu, nejvyšší bod trupu |

---

## 3. Set — Ohnivý (červená)

**Funkce → tvar:** pálí dřevo (dosah vodorovně/šikmo/svisle) nebo taví led (jen šikmo-dolů). Spotřebovává kanystr.

| Prvek | Popis |
|---|---|
| Podvozek | kola, robustnější než Han (statická pozice při palbě) |
| Hlavice plamenometu | montovaná na rameni/rotující věži, viditelná tryska/ústí jako hlavní silueta-definující prvek |
| Vlastní nádrž | malá přídavná nádrž na hlavici (odlišná od neseného kanystru v inventáři) |
| Use-wear | ohořelé/začouzené akcenty kolem ústí hlavně |
| Jádro | na těle, mimo dráhu plamene |

---

## 4. Net — Přírodní (zelená)

**Funkce → tvar:** jediný bez koleček. Šplhá po svislých stěnách (nahoru max. 2 předměty, dolů bez limitu). Nese předměty na zádech.

| Prvek | Popis |
|---|---|
| Tělo | nízké těžiště, chitinózní krunýř |
| Nohy | 6× článkované, přísavky nebo hroty na koncích (úchyt na svislou stěnu) |
| Záda | sklopný/otevírací krunýř jako úložný prostor — vizuálně odlišit „nese 0–2" vs „nese 3–4" předměty |
| Jádro | na hřbetě, mezi krunýřem a hlavou — nejmenší profil ze všech (kompaktnost kvůli šplhání) |

---

## 5. Da — Létající (azurová)

**Funkce → tvar:** volný let všemi směry, musí přistát pro výměnu robota, sbírá předmět jen shora.

| Prvek | Popis |
|---|---|
| Rám | X-konfigurace, 4 ramena |
| Rotory | 2 na rameno (koaxiální pár) = 8 celkem |
| Úchyt | hák/gripper na spodní straně trupu, visí dolů, pro nesený předmět |
| Přistávací nohy | drobné, pod trupem — funkčně nutné (musí umět stát na pevném podkladu) |
| Senzor/"obličej" | vpředu, kamera nebo čočka — čitelná orientace „kam se dron dívá" |
| Jádro | na vrcholu centrálního trupu |

---

## 6. Yeo — Ledový (bílá)

**Funkce → tvar:** mrazí vodu na led (spotřebovává kanystr). Po ledu chodí normálně — jediná výjimka z klouzání, takže podvozek potřebuje grip.

| Prvek | Popis |
|---|---|
| Podvozek | terénní kola nebo hroty — kontrast vůči Dulově hladkému podvozku |
| Chladicí hlavice | velký žebrovaný chladič/radiátor, umístěný jako „hlava" nebo rameno, dominantní prvek siluety |
| Detail | jinovatka/led usazený na žebrech chladiče |
| Jádro | umístit tak, aby nekolidovalo s chladičem — např. níž na hrudi místo na vrcholu |

---

## 7. Il — Elektrický (žlutá)

**Funkce → tvar:** R2-D2 základ. Opravuje skříně (service kit → pájení), ovládá panely (USB).

| Prvek | Popis |
|---|---|
| Trup | soudkovitý/válcový, R2-D2 proporce |
| Podvozek | kola (2–3, jako u referenčního droida) |
| Rameno 1 | výsuvné, pájecí špička na konci — tenký, přesný nástroj |
| Rameno 2 | výsuvné, USB konektor na konci |
| Povrchové pruhy | černé akcenty na žluté karoserii |
| Jádro | na vrcholu kupole/hlavy — Il je jediný, kde „hlava" v běžném smyslu splývá s pozicí jádra nejpřirozeněji |

---

## Poznámka k dalšímu postupu

Tento dokument je krok mezi konceptem a Blender skriptem. Než se z něj generuje geometrie, doporučuji ověřit na jednom pilotním robotovi (Han nebo Net — nejjasnější tvar), jestli:

1. jednotka `0.3u` pro jádro sedí vizuálně vůči tělu v měřítku 1 grid cube,
2. je rozumné centrální jádro modelovat jako sdílený `.blend` asset (link/instance) vs. per-robot kopie,
3. text výše stačí jako zadání pro parametrický Python skript, nebo je potřeba rozepsat konkrétní souřadnice/úhly kloubů.
