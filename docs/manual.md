# Manuál hry — Nature Cybernetic Robots

Tento dokument popisuje pravidla hry tak, jak je vidí hráč — bez vnitřní
implementace (žádné behavior tree, žádné raycasty). Účel: každé pravidlo
by mělo jít ověřit jedním jednoduchým, cíleným levelem, který dané
pravidlo přímo předvádí a nic jiného. Zdroj pravdy je
[design-document.md](design-document.md) — tento manuál je jeho čtenářsky
zjednodušený výtah.

## Obsah

1. [Cíl hry](#1-cíl-hry)
2. [Mřížka a pohyb](#2-mřížka-a-pohyb)
3. [Ovládání a přepínání robotů](#3-ovládání-a-přepínání-robotů)
4. [Hmotnost a inventář](#4-hmotnost-a-inventář)
5. [Klíč a cíl](#5-klíč-a-cíl)
6. [Překážky a povrchy](#6-překážky-a-povrchy)
7. [Voda a utonutí](#7-voda-a-utonutí)
8. [Předměty](#8-předměty)
9. [Roboti](#9-roboti)
10. [Elektronické systémy](#10-elektronické-systémy)
11. [Konec levelu a restart](#11-konec-levelu-a-restart)
12. [Návrh výukových levelů](#12-návrh-výukových-levelů)

---

## 1. Cíl hry

Level je tvořený krychlovou mřížkou. Hráč střídavě ovládá roboty, kteří
se v levelu nacházejí, a jeho úkolem je dostat **všechny** přidělené
roboty do **cíle**. Hra neobsahuje náhodu ani protivníky — jediná
překážka jsou pravidla pohybu a interakcí popsaná níže.

V každém levelu je vždy přesně jeden **klíč**. Robot, který klíč sebere,
musí projít cílem jako **první** — teprve tím se cíl pro ostatní roboty
odemkne (viz [5. Klíč a cíl](#5-klíč-a-cíl)).

## 2. Mřížka a pohyb

- Vše v levelu — roboti, předměty, překážky — žije v krychlové mřížce a
  pohybuje se výhradně po jedné kostce.
- Level je ohraničený kvádr; za jeho hranice se nedá dostat žádným
  způsobem, i když hranice není vidět.
- Standardní pohyb je krok vpřed po rovině, nebo vpřed a nahoru/dolů po
  **šikmině**.
- Do **vody** může vstoupit jen vodní robot (Dul) — pro ostatní je voda
  neprůchodná.
- Vstup na **led** funguje jinak než normální krok: robot se po ledu
  **sveze**, dokud nedorazí na jiný povrch nebo nenarazí na překážku.
  Celý sjezd proběhne jako jediný příkaz hráče — nejde ho zastavit
  uprostřed ani mu za jízdy změnit směr. Pokud by sjezd skončil nad
  propastí, hra na led vůbec nevstoupí (kontrola proběhne předem).
  Výjimky: ledový robot (Yeo) po ledu chodí normálně, nesklouzne se; a
  létající robot (Da) se po zemi ani po ledu vůbec nepohybuje.
- Na **šikmině** nejde zůstat stát. Pokud by měl krok skončit na
  šikmině (a ne za ní), krok se vůbec neprovede.

## 3. Ovládání a přepínání robotů

Každý robot umí čtyři typy úkonů:

- **Otočení** vlevo o 90°, vpravo o 90°, nebo čelem vzad o 180° —
  neomezeně, kdykoliv.
- **Krok vpřed** (případně několik navazujících kroků vyhodnocených jako
  jeden příkaz — viz led a šikminy výše).
- **Akce 1** a **Akce 2** — dvě schopnosti specifické pro každého
  robota, viz [9. Roboti](#9-roboti). Ne každý robot má obě definované.

Aktivní je vždy jen jeden robot. Roboti na scéně mají pevné pořadí;
klávesou pro přepnutí (výchozí Tab) se aktivní robot posouvá na dalšího
v pořadí a po posledním se vrací na prvního. Jde také kliknout přímo na
konkrétního robota v UI a přepnout se na něj mimo pořadí.

Přepnutí pryč od aktivního robota se **odmítne**, pokud by tím robot
zůstal v nebezpečné rozdělané situaci bez dohledu hráče. Konkrétně: Da
nesmí zůstat viset ve vzduchu — dokud nepřistane, nejde se od něj
přepnout na jiného robota.

## 4. Hmotnost a inventář

- Každý robot má vlastní **hmotnost** (základní hodnota u většiny
  robotů je 2, u Da je 1). Hmotnost ovlivňuje, jestli se rozjede
  transportní plošina — viz [10. Elektronické systémy](#10-elektronické-systémy).
  Nesené předměty žádnou vlastní hmotnost nemají a do součtu se
  nepočítají.
- Každý robot může nést až **čtyři předměty** současně, s výjimkou Da,
  který nese jen jeden. Má-li robot plný inventář, další předmět se pro
  něj chová jako překážka, dokud něco neodloží.
- Robot se nikdy nemůže rozbít ani zničit. Pokud by krok nebo akce vedly
  k jeho zničení, hra ho prostě neprovede.
- Kromě vodního robota (Dul) nemůže žádný robot do hluboké vody.
  Kromě létajícího robota (Da) nikdo nesnese pád z výšky. Kromě
  přírodního robota (Net) nikdo neumí šplhat po stěnách.

## 5. Klíč a cíl

- **Klíč** je předmět bez hmotnosti, který jde sebrat a který
  neomezuje pohyb ani nosnost žádného robota. V levelu je vždy přesně
  jeden.
- **Cíl** je zpočátku zamčený a neprůchodný. Odemkne ho teprve robot,
  který klíč nese, tím, že jím projde — musí to tedy udělat jako první
  ze všech robotů v levelu. Po odemčení mohou cílem projít i ostatní.
- Jakmile robot dojde do cíle, zmizí ze scény, hra automaticky přepne
  na dalšího robota v pořadí a dokončený robot navždy vypadne z výběru.
  **Robot, který už je v cíli, nemůže dál pomáhat ostatním** — je třeba
  si dopředu naplánovat, v jakém pořadí roboti do cíle dorazí.

## 6. Překážky a povrchy

| Prvek | Chování |
|---|---|
| **Zeď** | Neprůchodná a nezničitelná kostka. Nejde přesunout ani odstranit. O úroveň výš po jejím vrchu jde normálně chodit. |
| **Šikmina** | Cesta mezi patry, natočená do jednoho ze čtyř směrů. Ze stran neprůchodná, nedá se na ni nic položit ani na ní zůstat stát (viz [2. Mřížka a pohyb](#2-mřížka-a-pohyb)). |
| **Hlína** | Neprůchodná pro všechny kromě Hana, který ji umí odstranit (viz [9.1 Han](#91-zemní--han)). Podléhá gravitaci — co bylo nad odstraněnou kostkou, spadne o patro níž. |
| **Kámen** | Nezničitelný jako zeď, ale podléhá gravitaci — uvolní-li se prostor pod ním, spadne o patro níž. |
| **Dřevo** | Zničitelné jen Setovou akcí 1 (spálení); po zničení nezůstává nic. Stejně jako hlína a kámen podléhá gravitaci, a to i před zničením. |
| **Led** | Ve stejném patře jako robot se chová jako zeď. O patro výš po něm robot sklouzne (viz [2. Mřížka a pohyb](#2-mřížka-a-pohyb)), kromě Yea, který po něm chodí normálně. Led nikdy nepadá, i když se propadne podklad pod ním. Vzniká jen ve vodě (akcí Yea) a taje jen Setovou akcí. |
| **Propast / okraj levelu** | Za hranice mřížky se nikdo nedostane; pád do propasti přežije jen létající robot (ten se ale po zemi nepohybuje, takže do propasti spíš nespadne). |

## 7. Voda a utonutí

- Vodní plochy (nádrže) mají danou kapacitu a aktuální množství vody.
- Je-li vody méně než polovina objemu dna nádrže, může do ní vstoupit
  **kterýkoli** robot (voda mu sahá nejvýš po pás). Je-li vody víc, smí
  dovnitř **jen Dul**.
- **Utonutí:** žádný robot kromě Dula nesmí skončit v situaci, kdy mu
  voda sahá výš než po pás (tj. hladina nádrže, kde stojí, přesáhne 50 %
  objemu dna). Tohle pravidlo platí univerzálně — ať hladina stoupne
  proto, že do ní Han vysype korbu, Dul vypustí cisternu, Set roztaví
  led, nebo se do ní pustí automatické čerpadlo: kdykoli by úkon vedl k
  utonutí jiného robota, **celý úkon se vůbec neprovede** (u čerpadla to
  znamená, že se nepřečerpá vůbec nic, ne jen bezpečná část).
- Nádrž může být označená jako **neomezená** — taková nádrž nikdy
  nemění hladinu, ať se z ní čerpá nebo do ní přitéká.

## 8. Předměty

- Většina předmětů se sbírá automaticky tím, že na ně robot vstoupí —
  žádná zvláštní akce není potřeba. Výjimka: **Da** musí na předmět
  naletět shora, ze strany je pro něj předmět překážka.
- **Palivo (kanystr):** sbírají ho Set, Net, Da a Yeo — pro ostatní je
  to překážka. Set a Yeo ho spotřebují při své Akci 1 (spálení /
  zmražení).
- **Opravářská sada (service kit):** sbírají ji Net, Da a Il, ale
  používat (opravovat elektrická zařízení) ji umí jen Il. Po úspěšné
  opravě zaniká.
- **Odhazování:** roboti, kteří umí předměty nést (Set, Net, Da, Yeo,
  Il), je mohou i odložit svou Akcí 2. Předmět nespadne na jiného
  robota — pokud by tam dopadl, odhození se neprovede. Odhodit předmět
  do vody sice jde, ale takový předmět už (kromě Dula, který předměty
  vůbec nesbírá) nikdo nevyzvedne — nedoporučuje se.

## 9. Roboti

Sedm robotů, každý s jinými schopnostmi. Aktivní je vždy jeden; mezi
nimi se přepíná podle [3. Ovládání a přepínání robotů](#3-ovládání-a-přepínání-robotů).

### 9.1 Zemní — Han

Hmotnost 2. Umí odstraňovat kostky hlíny a přenášet je jinam pomocí
korby.

- **Akce 1 — Nahrábnutí:** odstraní hliněnou kostku před sebou, pod
  sebou nebo šikmo dole před sebou a naplní si tím korbu. Dokud je
  korba plná, nemůže hrabat dál. Cokoli bylo na odstraněné kostce,
  spadne o patro níž (pomalu, nikomu to neublíží). Nejde odstranit
  kostku, pod kterou stojí jiný robot.
- **Akce 2 — Vysypání korby:** vytvoří za sebou hliněnou kostku ze
  své plné korby. Neprovede se, pokud by kostka dopadla na jiného
  robota nebo do zcela plné nádrže. Vysypání do vody sníží kapacitu
  nádrže a zvýší hladinu — pokud by tím někdo utonul, akce se
  neprovede.

### 9.2 Vodní — Dul

Hmotnost 2. Jediný robot, který umí vstoupit do vody a pohybovat se v
ní volně (i svisle, až na dno). Vstoupit může jen tam, kde je hladina
zhruba v rovině s břehem (tolerance necelá půl kostky) — stejná
podmínka platí i pro vylézání z vody.

- **Akce 1 — Načerpání vody:** naplní prázdnou cisternu. Ze břehu jen
  pokud je nádrž zaplněná z víc než 50 %, ponořený může čerpat vždy.
  Sníží hladinu zdrojové nádrže.
- **Akce 2 — Vypuštění cisterny:** vypustí vodu za sebe do nádrže,
  zvýší jí hladinu. Neprovede se, pokud by tím jiný robot utonul.

### 9.3 Ohnivý — Set

Hmotnost 2. Umí sbírat a používat palivo ke spalování/tavení překážek.

- **Akce 1 — Zapálení:** vyžaduje kanystr paliva, který se spotřebuje.
  Zničí dřevěnou kostku před sebou (vodorovně, šikmo nebo nad sebou) —
  po zničení nezůstane nic. Nebo roztaví ledovou kostku šikmo dole
  před sebou — ta se změní na vodu (hladina zbytku vody se přitom
  nezvýší). Akce se neprovede, pokud není co spálit/roztavit, pokud by
  pod ničenou kostkou stál jiný robot, nebo (u ledu) pokud by tavením
  vznikla ledová kra bez spojení s pevným podkladem.
- **Akce 2 — Odložení kanystru:** nechá nesený kanystr za sebou.

### 9.4 Přírodní — Net

Hmotnost 2. Neumí do vody, ale jako jediný umí šplhat po svislých
stěnách.

- Šplhání nahoru je možné, jen pokud je na vrcholu stěny místo, kam se
  dá vystoupit, stěna není z ledu a Net nese nejvýš dva předměty.
  Šplhání dolů nejde, končí-li stěna nad vodou nebo nad propastí,
  ale limit počtu předmětů tu neplatí — sešplhat dolů může i se všemi
  čtyřmi (pak už ale nemůže zpátky nahoru, dokud dva neodloží).
- **Akce 1:** Net nemá.
- **Akce 2 — Odložení předmětu:** položí nesený předmět za sebe.

### 9.5 Létající — Da

Hmotnost 1. Jediný robot, který létá — pohybuje se volně vodorovně i
svisle, omezují ho jen pevné překážky a hranice levelu. Nemůže do
vody. Nesmí zůstat viset ve vzduchu, když ho chce hráč přepnout na
jiného robota — musí nejdřív přistát. Unese jen jeden předmět a musí
na něj naletět shora.

- **Akce 1:** Da nemá.
- **Akce 2 — Odhození předmětu:** upustí nesený předmět přímo pod
  sebe (aspoň o jednu kostku níž). Dokud předmět znovu nesebere,
  nemůže na to místo přistát.

### 9.6 Ledový — Yeo

Hmotnost 2. Jediný robot, který po ledu chodí normálně (neklouže se) a
který umí led vyrábět.

- **Akce 1 — Vytvoření ledu:** vyžaduje kanystr paliva (spotřebuje
  se). Funguje jen stojí-li Yeo na pevném podkladu nebo na jiné kostce
  ledu a hladina vody před ním sahá aspoň do poloviny kostky. Vytvoří
  před sebou pevně ukotvenou ledovou kostku (nikdy nespadne, unese
  cokoli) — tak lze stavět ledové cesty/mosty přes vodu, ale ostatní
  roboti po nich musí jít rovně.
- **Akce 2 — Odložení předmětu:** Yeo umí nosit kanystry i pro jiné
  roboty (např. donést palivo Setovi) a touto akcí je odloží.

### 9.7 Elektrický — Il

Hmotnost 2. Jediný robot, který umí ovládat elektrická zařízení a
opravovat je.

- **Akce 1 — Interakce se zařízením:** účinek závisí na tom, co má Il
  před sebou.
  - Před **rozbitou elektrickou skříní** a s **service kitem** u sebe:
    skříň opraví (kit se spotřebuje) a rovnou ji zapne pod napětí.
    Bez kitu se akce neprovede.
  - Před **funkční elektrickou skříní**: přepne napájení
    (zapnuto ↔ vypnuto).
  - Před **funkční řídicí jednotkou**, otočený ze správné strany:
    sepne napojené zařízení (transportní plošinu nebo čerpadlo) —
    viz [10. Elektronické systémy](#10-elektronické-systémy). Pokud
    sepnutí nesplňuje podmínky (např. plošina nemá dost hmotnosti,
    čerpadlo nemá co čerpat), akce se neprovede.
- **Akce 2 — Odložení service kitu:** odloží nesenou opravářskou sadu.

## 10. Elektronické systémy

Elektrická zařízení pohánějí dva typy strojů: **transportní plošiny** a
**čerpadla**. Ovládat je (zapínat skříně, mačkat tlačítka/přepínače)
umí jedině Il svou Akcí 1, a to jen když k zařízení stojí ze správného
směru.

- **Elektrická skříň** — buď je od začátku funkční a pod napětím,
  nebo je rozbitá a čeká na opravu service kitem. Funkční skříň jde
  vypnout a znovu zapnout stiskem Akce 1.
- **Řídicí jednotka** — napojená na plošinu nebo čerpadlo, buď jako
  **tlačítko** (jedno sepnutí = jeden přejezd/přenos jedním určeným
  směrem), nebo jako **přepínač** (sepnutí střídavě posílá zařízení tam
  a zase zpátky).
- **Transportní plošina** — sada kostek, která se pohybuje mezi dvěma
  polohami. Má **hmotnostní práh**: rozjede se, teprve když na ní
  stojí roboti s dostatečným součtem hmotnosti (horní mez nosnosti
  neexistuje, těžší náklad ji nezastaví). S plošinou se přesouvá
  všechno, co na ní stojí nebo leží — roboti, odložené předměty i
  klíč.
  - Je-li plošina napojená jen na skříň (bez řídicí jednotky), je
    **automatická**: rozjede se sama, jakmile je práh poprvé splněn, a
    znovu sepne až poté, co podmínka mezitím přestala a zase začala
    platit.
  - Je-li napojená i na řídicí jednotku, je **manuální** — přejezd
    spouští hráč přes Ila, hmotnostní práh musí být splněný i tak.
  - Vede-li přejezd k tomu, že by jiný robot než Dul utonul (viz
    [7. Voda a utonutí](#7-voda-a-utonutí)), plošina se **zablokuje** a
    nepřejede, i kdyby byly ostatní podmínky splněné.
- **Čerpadlo** — přesouvá vodu mezi dvěma nádržemi. Funguje jen tehdy,
  když jsou **všechny** napojené skříně opravené a pod napětím.
  - Jedno sepnutí přečerpá **veškerou** vodu ze zdrojové nádrže do
    cílové — nikdy jen část. Pokud se celý objem do cílové nádrže
    nevejde, nebo by přenos někoho utopil, **nepřečerpá se nic**.
  - Napojené jen na skříň (bez řídicí jednotky): **automatické** —
    sepne samo, jakmile jsou poprvé splněné všechny podmínky přenosu, a
    čeká, až se do zdrojové nádrže znovu nateče voda, než sepne podruhé.
  - Napojené i na řídicí jednotku: **manuální**, sepíná ho hráč přes
    Ila (tlačítko = jeden směr, přepínač = střídavě oba směry).

## 11. Konec levelu a restart

Hra nemá klasickou prohru ve smyslu "game over" — žádný krok ani akce,
které by robota zničily, se vůbec neprovedou. Level je hotový, jakmile
všichni přidělení roboti dojdou do cíle (v pořadí podle
[5. Klíč a cíl](#5-klíč-a-cíl)).

Jediný způsob, jak se dá level "prohrát", je dostat se do stavu, ze
kterého už neexistuje řešení (např. nevratně spotřebovat poslední
kanystr paliva, nebo poslat robota do cíle předčasně, ačkoliv byl
ještě potřeba jinde). V takovém případě hráč level restartuje sám z
menu — hra takový stav sama nedetekuje.

## 12. Návrh výukových levelů

Zadání pro sadu malých demo-levelů, každý cíleně na **jednu** novou
mechaniku (v duchu "po malých, samostatně ověřitelných krocích" —
viz [CLAUDE.md](../CLAUDE.md)). Levely jsou seřazené od nejjednodušší
mechaniky po nejsložitější a každý další z nich smí stavět na tom, co
už předchozí levely zavedly. U každého levelu je:

- **Mechanika** — na co odkazuje v tomto manuálu.
- **Roboti** — kdo je v levelu a proč.
- **Rozestavění** — stručný, buildovatelný návrh mřížky (přesné
  souřadnice nejsou potřeba, jde o topologii).
- **Řešení** — jedna až dvě věty, co hráč udělá, aby bylo vidět, že
  mechanika funguje.
- **Průvodní text** — hotový text pro pole "Úvodní textová zpráva" v
  editoru (viz [design-document.md, 2.2.1](design-document.md#221-ovládací-panel)),
  rovnou zkopírovatelný; prázdný řádek uvnitř odděluje odstavce přesně
  tak, jak to hra očekává.

Levely nemají čísla shodná s pořadím kapitol manuálu, protože gameplay
nejde nutně zavádět ve stejném pořadí jako popis pravidel (např. led je
jednodušší ukázat až po zavedení Yea).

### Fáze 1 — Základy: pohyb, klíč, cíl

#### L01 — První kroky

- **Mechanika:** [1. Cíl hry](#1-cíl-hry), [3. Ovládání a přepínání robotů](#3-ovládání-a-přepínání-robotů), [5. Klíč a cíl](#5-klíč-a-cíl)
- **Roboti:** Han (jeho speciální schopnost tu není potřeba).
- **Rozestavění:** Jedna rovná chodba v rovině, žádné patro navíc.
  Han startuje na jednom konci, klíč leží uprostřed chodby na zemi,
  cíl je na druhém konci.
- **Řešení:** Popojet vpřed, sebrat klíč automaticky průchodem přes
  jeho políčko, dojet do cíle a odemknout ho.
- **Průvodní text:**
  > Vítejte v NCR. Ovládáte robota — otáčí se na místě a krok za
  > krokem postupuje po mřížce.
  >
  > Na cestě leží klíč. Stačí na jeho políčko vstoupit a robot ho
  > automaticky zvedne. Klíč musí projít cílem jako první — jinak
  > zůstane cíl zamčený.

#### L02 — Zeď

- **Mechanika:** [6. Překážky a povrchy — Zeď](#6-překážky-a-povrchy)
- **Roboti:** Han.
- **Rozestavění:** Chodba s jedním zalomením do pravého úhlu kolem
  jednoho bloku zdi — přímá cesta k cíli je zdí zatarasená, jde se tam
  dostat jen oklikou. Klíč před zdí, cíl za ní.
- **Řešení:** Otočit se, obejít zeď bokem, znovu se natočit k cíli.
- **Průvodní text:**
  > Zeď je jediná naprosto neprůchodná a nezničitelná překážka ve hře.
  > Nedá se přesunout, prokopat ani spálit — jde jen kolem ní.

#### L03 — Šikmina

- **Mechanika:** [2. Mřížka a pohyb — led/šikminy](#2-mřížka-a-pohyb), [6. Překážky a povrchy — Šikmina](#6-překážky-a-povrchy)
- **Roboti:** Han.
- **Rozestavění:** Dvě patra. Klíč a start v dolním patře, šikmina
  vede nahoru do patra s cílem. Vedle použitelné šikminy umístit ještě
  druhou, kratší slepou šikminu, za kterou hned následuje propast bez
  pokračování (jen jako ukázka, nemusí ležet na cestě k cíli).
- **Řešení:** Vyjet po funkční šikmině nahoru do cíle. Pokus vyjet po
  slepé šikmině k propasti ukáže, že krok na ni hra vůbec neprovede.
- **Průvodní text:**
  > Šikmina spojuje dvě patra mřížky. Robot po ní vyjede nebo sjede,
  > ale nikdy na ní nezůstane stát — hra dovolí vstoupit na šikminu,
  > jen pokud je za ní místo, kam pokračovat. Vede-li šikmina do
  > prázdna, robot na ni vůbec nevkročí.

### Fáze 2 — Han: hlína a gravitace

#### L04 — Nahrábnutí

- **Mechanika:** [9.1 Han — Akce 1](#91-zemní--han)
- **Roboti:** Han.
- **Rozestavění:** Rovná chodba, uprostřed jedna kostka hlíny zcela
  blokující průchod. Klíč před hlínou, cíl za ní.
- **Řešení:** Han se postaví před hlínu a použije Akci 1 — kostka
  zmizí do korby a cesta je volná.
- **Průvodní text:**
  > Han umí hrabat. Postavte ho před hliněnou kostku a použijte
  > Akci 1 — kostku nahrne do korby a uvolní cestu. Dokud má korbu
  > plnou, další hlínu už nenahrábne.

#### L05 — Vysypání korby

- **Mechanika:** [9.1 Han — Akce 2](#91-zemní--han)
- **Roboti:** Han.
- **Rozestavění:** Chodba přerušená propastí širokou jednu kostku,
  příliš širokou na přeskočení (roboti neskáčou). Hned před propastí
  je samostatná kostka hlíny, kterou Han může nahrábnout Akcí 1. Klíč
  a start před propastí, cíl za ní.
- **Řešení:** Han nahrábne hlínu (Akce 1), otočí se čelem vzad k
  propasti, ustoupí na její okraj a použije Akci 2 — vysype korbu do
  propasti a vytvoří tak schod/most, po kterém přejde na druhou
  stranu.
- **Průvodní text:**
  > Co Han nahrábne, může zase vysypat — ale jen za sebe, ne dopředu.
  > Otočte ho zády k místu, kam chcete hlínu umístit, a použijte
  > Akci 2. Takhle se dá i zasypat propast.

#### L06 — Gravitace

- **Mechanika:** [6. Překážky a povrchy — Hlína/Kámen/Dřevo](#6-překážky-a-povrchy)
- **Roboti:** Han.
- **Rozestavění:** Sloupec dvou kostek: dole hlína, na ní kámen (nebo
  dřevo). Han stojí vedle sloupce v úrovni horní kostky, tak aby po
  vykopání spodní hlíny viděl kámen klesnout o patro níž na jeho
  místo. Cíl je za sloupcem v úrovni dna, dosažitelný teprve po pádu
  kamene (předtím ho kámen blokuje).
- **Řešení:** Han vyhrabe spodní hliněnou kostku; kámen nad ní spadne
  o patro níž a uvolní/zablokuje podle návrhu cestu k cíli.
- **Průvodní text:**
  > Hlína, kámen i dřevo poslouchají gravitaci. Odstraníte-li kostku,
  > na které něco leží, to, co bylo nad ní, klidně sklouzne o patro
  > níž. Robotům samotným pád neublíží.

### Fáze 3 — Voda a Dul

#### L07 — Mělká a hluboká voda

- **Mechanika:** [7. Voda a utonutí](#7-voda-a-utonutí)
- **Roboti:** Han, Dul.
- **Rozestavění:** Dvě oddělené nádrže vedle sebe. Jedna zaplněná
  málo (pod polovinu — mělká), druhá skoro plná (hluboká). Klíč leží
  na dně/kraji té mělké, cíl je za tou hlubokou, dosažitelný jen
  skrz ni.
- **Řešení:** Han (kterýkoli robot) projde mělkou vodou pro klíč, ale
  do hluboké nemůže — tam musí projít Dul.
- **Průvodní text:**
  > Do mělké vody, která sahá nejvýš po pás, může kterýkoli robot.
  > Do hluboké vody smí jen Dul — ten se ve vodě pohybuje jako
  > ponorka, i pod hladinou.

#### L08 — Čerpání a vypouštění

- **Mechanika:** [9.2 Dul](#92-vodní--dul)
- **Roboti:** Dul.
- **Rozestavění:** Dvě propojené nádrže: zdrojová plná (přes 50 %),
  cílová prázdná, obě dosažitelné ze břehu. Cíl levelu je dostupný
  jen tehdy, když hladina zdrojové nádrže klesne pod úroveň, která
  blokuje jinak nezbytnou šikminu/průchod vedle ní (např. šikmina do
  vody je použitelná, jen když je hladina dost nízko).
- **Řešení:** Dul načerpá vodu ze zdrojové nádrže (Akce 1) a vypustí
  ji do cílové (Akce 2) — hladina zdrojové klesne natolik, že Dul (a
  třeba i další robot) může pokračovat k cíli.
- **Průvodní text:**
  > Dul umí vodu přemisťovat sám — načerpá ji do cisterny Akcí 1 a
  > jinde ji Akcí 2 zase vypustí. Hladina zdrojové nádrže klesá,
  > cílové stoupá.

#### L09 — Bezpečná hladina

- **Mechanika:** [7. Voda a utonutí](#7-voda-a-utonutí)
- **Roboti:** Han, Dul.
- **Rozestavění:** Jedna nádrž naplněná těsně pod 50 % objemu dna, v
  ní stojí Han. Dul stojí opodál se stejnou nádrží na dosah pro Akci 2
  (vypuštění cisterny by hladinu zvedlo přes 50 %).
- **Řešení:** Hráč zkusí Dulem vypustit cisternu do nádrže s Hanem —
  hra akci odmítne, protože by Han "utonul". Teprve když Han nádrž
  opustí, vypuštění projde.
- **Průvodní text:**
  > Žádný robot kromě Dula nesmí skončit pod vodou výš než po pás.
  > Kdykoli by nějaká akce zvedla hladinu nad tuto mez u nádrže, kde
  > stojí jiný robot, hra tu akci prostě neprovede — ať už jde o
  > vysypání korby, vypuštění cisterny, roztavení ledu nebo čerpadlo.

### Fáze 4 — Yeo a led

#### L10 — Ledový most

- **Mechanika:** [9.6 Yeo](#96-ledový--yeo), [2. Mřížka a pohyb — led](#2-mřížka-a-pohyb)
- **Roboti:** Yeo (s kanystrem paliva u sebe nebo poblíž na zemi),
  Han.
- **Rozestavění:** Vodní nádrž zaplněná aspoň do poloviny, příliš
  široká na přeskočení, dělí start od cíle. Yeo stojí na jednom
  břehu, Han vedle něj.
- **Řešení:** Yeo použije Akci 1 opakovaně a postaví přímou řadu
  ledových kostek přes vodu až na druhý břeh. Han pak na led vstoupí a
  automaticky po celé jeho délce sklouže na druhou stranu (protože on,
  na rozdíl od Yea, klouže). Yeo sám může po svém mostě přejít i
  normálním krokem, beze skluzu.
- **Průvodní text:**
  > Yeo umí s troškou paliva zmrazit vodu před sebou a stavět tak
  > ledové mosty — musí ale stát na pevném podkladu nebo na jiné
  > ledové kostce. Ostatní roboti se po ledu nesvezou pomalu — jakmile
  > na něj vstoupí, sjedou po něm rovnou na konec jedním pohybem.
  > Ledová cesta pro ně proto musí být rovná.

#### L11 — Roztavení ledu

- **Mechanika:** [9.3 Set — roztavení ledu](#93-ohnivý--set)
- **Roboti:** Yeo (postaví led), Set (s kanystrem paliva).
- **Rozestavění:** Stejná vodní nádrž jako v L10, ale tentokrát vede
  ledový most na místo, které je zároveň zkratkou přes cíl uzavřenou
  jinam — přidejte druhou, delší suchou cestu k cíli. Cíl levelu:
  ukázat, že roztavením ledu jde vodní hladinu vrátit, aniž by se
  cokoli utopilo.
- **Řešení:** Yeo postaví led přes vodu, Set k němu dojde a jednu
  jeho kostku (tu, která je z jeho pohledu šikmo dole před ním)
  Akcí 1 roztaví zpátky na vodu — hladina zbytku nádrže se přitom
  nezmění.
- **Průvodní text:**
  > Set svým plamenem neumí roztavit led přímo před sebou, jen ten,
  > který je zešikma pod ním. Roztavená kostka se prostě vrátí zpátky
  > do vody, jako by tam led nikdy nebyl.

### Fáze 5 — Set a oheň

#### L12 — Pálení dřeva

- **Mechanika:** [9.3 Set — pálení dřeva](#93-ohnivý--set)
- **Roboti:** Set.
- **Rozestavění:** Rovná chodba s dřevěnou kostkou zatarasující
  průchod, kanystr paliva leží kousek před ní na zemi. Klíč před
  dřevem, cíl za ním.
- **Řešení:** Set nejdřív sebere kanystr (vejde na jeho políčko),
  postaví se před dřevo a použije Akci 1 — dřevo zmizí beze zbytku,
  kanystr se spotřebuje.
- **Průvodní text:**
  > Set potřebuje ke spálení překážky kanystr s palivem — bez něj se
  > Akce 1 neprovede. Dřevo po spálení nezanechá žádnou stopu, na
  > rozdíl od hlíny nejde nijak znovu použít.

### Fáze 6 — Net a šplhání

#### L13 — Šplhání nahoru

- **Mechanika:** [9.4 Net](#94-přírodní--net)
- **Roboti:** Net.
- **Rozestavění:** Svislá stěna o výšce dvou pater vedoucí z dolního
  patra (start, klíč) na horní patro (cíl), bez jiné cesty nahoru.
  Vrchol stěny má rovný pevný podklad, na který se dá vystoupit.
- **Řešení:** Net se postaví ke stěně a krokem po ní vyšplhá nahoru,
  jako by šlo o normální krok — nahoře se srovná do vodorovné polohy.
- **Průvodní text:**
  > Net je jediný robot, který umí šplhat po svislých stěnách jako
  > brouk. Nahoře ale potřebuje najít pevné místo, kam se postavit —
  > na hladké stěně bez vrcholu neuvízne, tam prostě nevyleze.

#### L14 — Sešplhání dolů a limit nákladu

- **Mechanika:** [9.4 Net — sestup a inventář](#94-přírodní--net)
- **Roboti:** Net (nese na startu tři předměty, např. kanystry —
  více, než kolik smí nést při výstupu nahoru).
- **Rozestavění:** Net startuje nahoře na plošině se třemi předměty a
  stěnou vedoucí dolů, dole je klíč a cíl. Stěna nekončí nad vodou ani
  propastí.
- **Řešení:** Net se třemi předměty dolů sešplhá bez problému (limit
  platí jen pro výstup). Pokud by se hráč pokusil vrátit zpátky nahoru
  bez odložení aspoň jednoho předmětu, výstup by se neprovedl.
- **Průvodní text:**
  > Dolů ze stěny sleze Net i se všemi čtyřmi předměty v inventáři.
  > Nahoru ale vyšplhá jen tehdy, když nese nejvýš dva — s víc věcmi
  > na zádech nahoru prostě nedosáhne.

### Fáze 7 — Da a létání

#### L15 — Let a přenos předmětu

- **Mechanika:** [9.5 Da](#95-létající--da)
- **Roboti:** Da.
- **Rozestavění:** Místnost rozdělená vysokou zdí bez průchodu po
  zemi; na jedné straně na zemi leží předmět (např. kanystr) pod
  otevřeným nebem (ne pod žádným stropem), na druhé straně za zdí je
  místo, kam předmět patří, a za ním cíl. Klíč leží volně na zemi na
  straně startu.
- **Řešení:** Da přeletí zeď, snese se shora na předmět a sebere ho,
  přeletí zpátky přes zeď, sníží se nad cílové místo a Akcí 2 předmět
  upustí aspoň o kostku níž pod sebe, poté přistane a pokračuje k cíli.
- **Průvodní text:**
  > Da lítá volně všemi směry a jako jediný přeletí i vysoké
  > překážky. Předmět ale musí sebrat náletem shora a upustit ho zase
  > pod sebe — a než znovu přistane, musí se země nejdřív dotknout
  > nohama, ne zůstat viset ve vzduchu.

### Fáze 8 — Il a elektronika

#### L16 — Oprava rozbité skříně

- **Mechanika:** [9.7 Il](#97-elektrický--il), [10. Elektronické systémy — skříň](#10-elektronické-systémy)
- **Roboti:** Il, Net (přinese service kit).
- **Rozestavění:** Rozbitá elektrická skříň napojená jen na
  automatickou transportní plošinu s nízkým hmotnostním prahem (např.
  práh splní jeden robot). Service kit leží mimo dosah Ila, ale v
  dosahu Neta. Plošina spojuje start s cílem přes propast.
- **Řešení:** Net přinese Ilovi service kit, Il se postaví před skříň
  ze správné strany a Akcí 1 ji opraví — skříň je rovnou pod napětím,
  plošina (jakmile na ní bude stát dostatek hmotnosti) se sama rozjede.
- **Průvodní text:**
  > Il jako jediný umí opravovat rozbitá elektrická zařízení — potřebuje
  > k tomu service kit. Jakmile skříň opraví, je rovnou pod napětím a
  > vše, co je na ni napojené, může začít fungovat.

#### L17 — Automatická plošina (hmotnostní práh)

- **Mechanika:** [10. Elektronické systémy — transportní plošina](#10-elektronické-systémy)
- **Roboti:** Han (sám nesplní práh), Net (společně s Hanem práh
  splní).
- **Rozestavění:** Funkční skříň napojená jen na plošinu s prahem
  odpovídajícím součtu hmotností dvou robotů. Plošina spojuje start s
  cílem.
- **Řešení:** Nastoupí-li na plošinu jen jeden robot, nic se nestane.
  Až když na ní stojí oba, plošina se sama rozjede.
- **Průvodní text:**
  > Automatická plošina se rozjede sama, jakmile na ní stojí dost
  > hmotnosti. Jeden robot na to nemusí stačit — zkuste přivést i
  > druhého.

#### L18 — Řídicí jednotka: tlačítko

- **Mechanika:** [10. Elektronické systémy — řídicí jednotka](#10-elektronické-systémy)
- **Roboti:** Il, Han.
- **Rozestavění:** Plošina s nízkým prahem napojená na skříň i na
  řídicí jednotku typu tlačítko, ovladatelná Ilem ze břehu vedle
  koleje. Han stojí na plošině (práh splněn), ale plošina se sama
  nerozjede, dokud ji nespustí Il.
- **Řešení:** Il se postaví ke správné straně řídicí jednotky a
  Akcí 1 stiskne tlačítko — plošina s Hanem přejede na druhou stranu.
- **Průvodní text:**
  > Napojíte-li plošinu i na řídicí jednotku, přestane jezdit sama —
  > i po splnění hmotnostního prahu čeká, dokud ji Il nespustí
  > tlačítkem.

#### L19 — Řídicí jednotka: přepínač (tam a zpět)

- **Mechanika:** [10. Elektronické systémy — řídicí jednotka](#10-elektronické-systémy)
- **Roboti:** Il, Han.
- **Rozestavění:** Stejná plošina jako v L18, ale řídicí jednotka je
  typu přepínač, dosažitelná pro Ila z obou stran dráhy plošiny; cíl
  je dosažitelný jen po druhé jízdě plošiny zpátky pro Ila samotného.
- **Řešení:** Il pošle Hana na plošině na druhou stranu (1. sepnutí),
  přejde tam jinudy nebo počká, a druhým sepnutím pošle plošinu (a
  sám sebe, pokud na ni nastoupí) zpátky.
- **Průvodní text:**
  > Přepínač na rozdíl od tlačítka posílá plošinu střídavě tam i
  > zpátky — každé další sepnutí ji vrátí do opačné polohy.

#### L20 — Automatické čerpadlo

- **Mechanika:** [10. Elektronické systémy — čerpadlo](#10-elektronické-systémy)
- **Roboti:** Han.
- **Rozestavění:** Dvě nádrže propojené čerpadlem napojeným jen na
  funkční skříň (bez řídicí jednotky). Zdrojová nádrž je plná, cílová
  prázdná s dostatečnou kapacitou. Cesta k cíli vede přes místo, které
  je proveditelné, jen když zdrojová nádrž klesne pod určitou hladinu
  (např. odkrytá šikmina ke dnu).
- **Řešení:** Jakmile je skříň pod napětím (rovnou od startu levelu),
  čerpadlo samo jednorázově přečerpá celý obsah zdrojové nádrže do
  cílové a uvolní cestu.
- **Průvodní text:**
  > Automatické čerpadlo sepne samo, jakmile je jeho skříň pod
  > napětím a je co čerpat. Přečerpá vždy celý obsah zdrojové nádrže
  > najednou, nikdy jen část.

#### L21 — Manuální čerpadlo (přepínač)

- **Mechanika:** [10. Elektronické systémy — čerpadlo](#10-elektronické-systémy)
- **Roboti:** Il, Han.
- **Rozestavění:** Dvě nádrže propojené čerpadlem napojeným na
  funkční skříň i na řídicí jednotku typu přepínač. Level vyžaduje
  vodu nejdřív v jedné nádrži (aby tam mohl třeba Han přejít mělkou
  vodou), pak zase ve druhé.
- **Řešení:** Il sepíná přepínač Akcí 1 pokaždé, když je potřeba
  přesunout vodu na opačnou stranu; Han mezitím využívá aktuální
  rozložení vody k postupu.
- **Průvodní text:**
  > Čerpadlo napojené na přepínač nesepne samo — čeká na Ila. Každé
  > sepnutí přesune celý obsah aktuální zdrojové nádrže na druhou
  > stranu a příště to bude fungovat obráceně.

#### L22 — Čerpadlo na více skříních

- **Mechanika:** [10. Elektronické systémy — čerpadlo](#10-elektronické-systémy)
- **Roboti:** Il, Net (přinese druhý service kit).
- **Rozestavění:** Čerpadlo napojené na dvě skříně, z nichž jedna je
  na startu rozbitá. Obě musí být pod napětím, aby čerpadlo fungovalo
  — je jedno, v jakém pořadí se opraví/zapnou.
- **Řešení:** Il opraví rozbitou skříň service kitem a ujistí se, že
  je zapnutá i ta druhá — teprve pak čerpadlo (automatické, nebo po
  sepnutí přes řídicí jednotku) skutečně přečerpá vodu.
- **Průvodní text:**
  > Některá čerpadla hlídají víc než jednu skříň najednou. Nestačí
  > opravit tu rozbitou — fungovat začnou, teprve až jsou úplně
  > všechny napojené skříně pod napětím zároveň.
