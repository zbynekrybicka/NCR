# Nature Cybernetic Robots

*S roboty přes překážky do kybernetického nebe*

Zbyněk Rybička, 2026

> **Poznámka k tomuto dokumentu:** Toto je pracovní verze přenesená z původního PDF (viz `docs/Nature_Cybernetic_Robots.pdf` pokud je uloženo). Dokument není hotový — chybí mimo jiné dokončení kroku robota Dula, popis scény výběru robota a ovládání kamery. Hra je aktuálně v pre-alpha fázi zaměřené na funkčnost — vizuál (art styl, UI, zvuk) a téma počtu/struktury levelů se řeší až od verze 0.2.0, resp. jsou vyřešeny průběžným vznikem levelů v editoru (viz [2.2.2](#222-levely-a-jejich-původ)). Doplňuje se průběžně jako součást vývoje hry.

## Obsah

1. [Synopse](#1-synopse)
   1. [Roboti](#11-roboti)
2. [Scény](#2-scény)
   1. [Level](#21-level)
      1. [Zahájení levelu](#211-zahájení-levelu)
      2. [Klíč a cíl](#215-klíč-a-cíl)
      3. [Podmínka ukončení levelu / restart](#216-podmínka-ukončení-levelu--restart)
   2. [Editor](#22-editor)
      1. [Levely a jejich původ](#222-levely-a-jejich-původ)

---

## 1. Synopse

Logická hra, ve které hráč ovládá sedm robotů, z nichž každý má jiné schopnosti pohybu či ovlivňování okolního prostředí, a společně se snaží dostat do cíle. Hra se dělí na úrovně, které jsou tvořené krychlovou mřížkou, a jak roboti, tak ostatní předměty a překážky jsou součástí této mřížky a mohou se pohybovat pouze v rámci ní. Hra neobsahuje žádný prvek náhody ani umělé inteligence, vše je plně v rukou hráče.

Cílem každé úrovně je dostat všechny přidělené roboty na dané scéně do cíle, přičemž na scéně se vždy nachází i klíč, který je třeba najít předtím, a robot, který klíč najde, musí cílem projít jako první.

Každý robot má svoji hmotnost, na kterou mohou některé předměty reagovat. Transportní plošina má daný **hmotnostní práh** a rozjede se, teprve když na ní stojí aspoň tolik hmotnosti (viz [2.2.1](#221-ovládací-panel)) — horní mez nosnosti neexistuje, těžší náklad plošinu nezastaví. Každý robot má možnost sbírat a držet předměty — některé všichni, některé jen někteří. Nesené předměty nemají vlastní hmotnost a do celkové hmotnosti robota se nepočítají; množství, které robot může nést, je místo toho omezené kapacitou jeho inventáře (viz [2.1.2](#212-řízené-prvky--roboti)).

Roboti se standardně mohou pohybovat po souši. Do vody vstoupit nemohou (s výjimkou vodního, který se ve vodě chová jako ponorka). Vstoupí-li na led, sklouznou se po něm tak daleko, než přejdou na první políčko jiného povrchu nebo narazí na překážku — to celé proběhne jako **jeden příkaz hráče** (jeden dlouhý krok složený z více dílčích kroků), ne jako postupné opakované vstupování na led. Pokud je na konci ledové dráhy propast, na led vstoupit nejde — hra to ověří ještě před provedením kroku. Výjimkou je ledový robot, který se může po ledu pohybovat stejně jako po souši (a tedy vůbec neklouže), a létající robot, který se po zemi nepohybuje vůbec.

### 1.1 Roboti

#### 1.1.1 Zemní — Han

Základní hmotnost je 2. Může odstraňovat kostky hlíny, přičemž když jednu kostku odstraní, naplní se mu korba, kterou musí následně zase jinde vyložit, jinak nemůže kopat dál. Může vyhrabat kostku přímo před sebou, pod sebou (přičemž tím se dostane na nižší úroveň) nebo která je z jeho pohledu šikmo dolů před ním. Vysypávat hlínu může pouze za sebe. Ale může se otáčet na místě, takže směr není zásadní překážka. Pokud vykope kostku, na níž jsou další kostky či jiné předměty, vše se propadne o úroveň níž. Pokud robot vyklopí korbu, kostka spadne na nejbližší pevný podklad. Lze vyklápět i do vody. Při vyklopení na led se z ní stává pevná překážka.

**Akce 1 — Nahrábnutí:** Stojí-li Han před kostkou z hlíny, nebo hliněná kostka tvoří povrch jeden krok před ním, nebo stojí přímo na ní, provede nahrábnutí hliněné kostky na korbu. Tím kostku odstraní a daným místem je možné projít. Konkrétně: nahrábnutí je možné, má-li Han přímo před sebou prázdný prostor a povrch před ním (tedy „ahead_below") je hlína — to je hlavní/běžný případ; samotné odstranění kostky přímo před ním nebo pod ním se vyhodnocuje stejnou logikou. Pokud nad hliněnou kostkou byly jiné kostky, které mohou spadnout (dřevo, kámen, další hlína...), tyto kostky spadnou. Pád je záměrně pomalý a mírný a robotům neubližuje — pokud na vrcholu propadající se věže stojí jiný robot, sníží se s ní o jednu kostku dolů, aniž by se cokoli zničilo (platí i v případě, že robot stojí přímo na kostce hlíny, kterou Han vykopává). Hrabat lze pouze, pokud má Han prázdnou korbu. Pokud Han vyhrabe kostku v oblasti s mělkou vodou (do hluboké nemůže), voda ihned zaplní vyhrabanou díru a celková hladina klesne. Před samotným vyhrabáním se vždy kontroluje, zda přímo pod odstraňovanou kostkou nestojí jiný robot — pokud ano, nahrábnutí se neprovede.

**Akce 2 — Vysypání korby:** Pokud má Han za sebou volný prostor (nestojí zády přímo u zdi), korba se vysype a vytvoří tak za sebou hliněnou kostku stejné velikosti jako předtím nabíral. Před vysypáním se vždy nejprve zkontroluje, kam kostka spadne. Vysypání se **neprovede**, pokud by kostka měla dopadnout na jiného robota, nebo pokud by měla dopadnout do zcela plné (a ne neomezené) nádrže — do neomezené nádrže dopadnout může vždy. Pokud Han stojí zády nad propastí, kostka spadne dolů na nejbližší pevný povrch, na který natrefí. Pokud Han vysype korbu do vody, kapacita nádrže se o jednu kostku sníží a hladina se odpovídajícím způsobem zvýší; pokud by hladina měla stoupnout natolik, že by se v ní Han nebo jiný robot utopili (kromě Dula), vysypání není možné.

#### 1.1.2 Vodní — Dul

Základní hmotnost je 2. Vypadá jako cisterna s čerpadlem, disponuje i lodním šroubem. Po suchu se může pohybovat jako ostatní, tedy rovně a po šikminách, nemůže skákat. Může se pohybovat po vodě. Do vody může vstoupit pouze v případě, že povrch, na kterém stojí, je ve stejné výšce jako vodní hladina zatopené oblasti — s tolerancí podle [2.1.4 Voda](#214-statické-prvky--překážky): hladina smí být pod tímto povrchem, ale méně než o půl kostky. Ve stejné situaci jako jediný může z vody vylézt. Totéž platí i na rozhraní s ledem: klouže-li Dul po ledové cestě, která končí u vody, krok se provede, pokud hladina sahá do roviny ledu — tedy za stejné podmínky, jako by vstupoval z normálního břehu. Vystupuje-li naopak z vody na led, sklouže se až na konec ledové cesty, a to jak do vody, tak na pevný povrch. Ve vodě se může pohybovat vodorovně i svisle. Ponořit se může vždy až na dno, není limitován maximálním ponorem.

**Akce 1 — Načerpání vody:** Lze provést, má-li Dul prázdnou cisternu, a to ve dvou situacích: ze břehu (bez ponoření), pokud je zatopená oblast před ním zaplněná na více než 50 % kapacity; nebo ponořený přímo ve vodě, mělké i hluboké, kde žádné takové omezení není. Při načerpání klesne hladina zatopené oblasti adekvátně objemu — má-li zatopená oblast hladinu o rozloze pěti kostek, hladina klesne o jednu pětinu výšky kostky.

**Akce 2 — Vypuštění cisterny:** Cisterna se vypouští směrem dozadu. Vodu lze vypustit pouze do zatopených oblastí či oblastí určených pro zatopení, a to jak ze břehu, tak přímo do nádrže. Hladina zatopené oblasti stoupne adekvátně objemu jedné kostky. Pokud by zvýšení hladiny přesáhlo 50 % objemu dna nádrže, ve které stojí jiný robot (utonutí, viz [Voda](#214-statické-prvky--překážky)), vypuštění se neprovede.

> ℹ️ Krok Dula (po souši i ve vodě) se vyhodnocuje jedním vlastním rozhodovacím stromem, viz [Mechanismus vyhodnocení kroku (behavior tree)](#212-řízené-prvky--roboti). Jeden strom na obojí proto, že krok umí prostředí uprostřed změnit — sklouznout po ledu do vody nebo vylézt z vody na led a klouzat dál.

#### 1.1.3 Ohnivý — Set

Základní hmotnost je 2. Může se pohybovat po souši a po šikminách stejně jako ostatní roboti. Set je jedním ze čtyř robotů (spolu s Netem, Dou a Yeem), kteří mají možnost sbírat kanystry s palivem, které může následně použít pro svoji akci. Pro ostatní roboty jsou kanystry překážkou.

**Akce 1 — Zapálení a odstranění překážky:** Vyžaduje palivo a to, aby překážka před ním byla zničitelná ohněm (dřevo nebo led; efekt zničení ledu viz [Led](#214-statické-prvky--překážky), efekt zničení dřeva viz [Dřevo](#214-statické-prvky--překážky)). Po provedení akce přijde Set o kanystr s palivem. Pokud v dosahu není nic ke spálení/roztavení, akce se neprovede (žádné pálení naprázdno).

Pálení dřeva: Set může zničit dřevěnou překážku, kterou má krok před sebou vodorovně, šikmo nebo svisle (v tomto pořadí priority). Stejně jako u Hanova nahrábnutí platí, že pokud nad zničenou kostkou byly další kostky, které mohou spadnout (další dřevo, kámen, hlína...), tyto kostky spadnou — pomalu a mírně, takže i robot stojící na vrcholu propadající se věže se s ní jen sníží o jednu kostku, aniž by se cokoli zničilo. Před samotným zničením se vždy kontroluje, zda přímo pod ničenou kostkou nestojí jiný robot — pokud ano, akce se neprovede.

Roztavení ledu: na rozdíl od dřeva má roztavení užší dosah — jde jen o ledovou kostku, která je vůči Setovi „ahead_below" (šikmo dolů před ním). Kostka se změní na vodu: kapacita nádrže se zvýší o 1 a současně přibude právě 1 jednotka vody, takže se hladina zbytku vody v nádrži nepohne (přesná reverze vzniku ledu, viz [Led](#214-statické-prvky--překážky)). Před roztavením se navíc kontroluje, zda by roztavením nevznikla plovoucí ledová kra — tedy zda daná ledová kostka není jediná, která podpírá jiné kostky ledu (ledová kostka může „viset" na jiné kostce ledu, ne jen na pevném podkladu, viz [Led](#214-statické-prvky--překážky)); pokud by roztavením zbyl na vodě led bez jakéhokoli spojení s pevným podkladem, akce se neprovede.

**Akce 2 — Odložení kanystru:** Pokud má Set u sebe nevyužitý kanystr s palivem, nechá jej za sebou, aby uvolnil místo v inventáři nebo aby si ho mohl vzít kolega.

#### 1.1.4 Přírodní — Net

Základní hmotnost je 2. Může se pohybovat po souši stejně jako většina ostatních, nemůže do vody, ale za to může šplhat po stěnách jako brouk (vypadá jako brouk — šest nožiček místo koleček).

Na stěně však nemůže zůstat viset. Před krokem představujícím šplhání po stěně se kontroluje, zda je na vrcholu stěny pevný podklad, na kterém se může usadit. Pokud stěna končí stropem, krok není možné provést. Šplhání do výšky je podmíněné tím, že Net nese nejvýše dva předměty (viz [Inventář](#212-řízené-prvky--roboti)). Šplhání vzhůru není možné, pokud je jedna nebo více kostek na stěně z ledu.

Při šplhání směrem dolů se kontroluje, zda je možné sešplhat — stěna nesmí končit ve vzduchu ani ve vodě, pod ní musí být pevný podklad. Na šplhání dolů se nevztahuje limit počtu nesených předmětů — může slézt i se všemi čtyřmi, ale pak už nemůže nahoru, dokud je neodloží na dva nebo méně.

Vizuál šplhání: nožičky se hýbou stejně jako při běžné chůzi po zemi. Při přechodu ze země na stěnu (šplhání nahoru) se Net na začátku pohybu natočí o 90° směrem vzhůru a po vyšplhání nahoru (přechod zpět na vodorovný podklad) se otočí zpátky. Obdobně při sestupu dolů ze stěny se na začátku otočí o 90° směrem dolů; po doslezení na pevnou zem (poslední krok sestupu, kdy už je pod ním podklad) se narovná zpátky do vodorovné polohy, jako by na cílové políčko přišel z vodorovného směru — nezůstává na zdi viset nakloněný.

Sám nemůže nic stavět ani bořit — jedná se o pomocníka, který umí přinést, co je potřeba.

**Akce 1:** Net neprovádí.

**Akce 2 — Odložení předmětu:** Odloží předmět z inventáře, který se umístí za něj. Musí být volný prostor (nesmí být přímo za robotem zeď).

#### 1.1.5 Létající — Da

Základní hmotnost je 1. Vypadá jako dron. Může se pohybovat libovolně vodorovně i svisle, nemá-li před sebou překážku. Jeho limity jsou pevné překážky a hranice úrovně (nejsou vidět, ale robot skrze ně neprojde) horizontální i vertikální. Nemůže do vody. Rovněž nesmí zůstat ve vzduchu, pokud jej chcete vyměnit — pro výměnu je nutné nejprve přistát.

Může sebrat jeden předmět (viz [Inventář](#212-řízené-prvky--roboti)), avšak musí na něj naletět shora — pokud by byl předmět pod nízkým stropem, naložit jej nemůže; ze strany je pro Da předmět překážkou.

**Akce 1:** Da neprovádí.

**Akce 2 — Odhození předmětu:** Předmět musí odhodit pod sebe, alespoň o jednu kostku. V případě, že odhodí předmět, nemůže na daném místě přistát bez toho, aniž by jej znovu sebral.

#### 1.1.6 Ledový — Yeo

Základní hmotnost je 2. Nosí chladicí těleso jako hlavici. Po souši se může pohybovat stejně jako většina ostatních, nemůže do vody. Po ledu se na rozdíl od ostatních může pohybovat neomezeně stejně jako po souši.

**Akce 1 — Vytvoření ledové kostky:** Musí stát na pevném podkladu, nebo na jiné kostce ledu, a vodní hladina před ním musí být vyšší než do poloviny okrajové kostky. Vyžaduje kanystr s palivem, který se při úspěšném provedení akce spotřebuje. Vytvoří před sebou ledovou kostku, která je pevně uchycená o podklad, na kterém stojí on sám — nemůže spadnout a její nosnost je teoreticky nekonečná. Zmrazování lze provádět ze břehu i z mělké vody; na rozdíl od Setova roztavení ledu (viz [1.1.3 Set](#113-ohnivý--set)) tu není žádné bezpečnostní omezení, které by akci mohlo zabránit — jediný důvod, proč se akce neprovede, je, že není co zmrazit (žádná voda v dosahu splňující podmínku výše). Yeo se jako jediný může pohybovat po ledu libovolně a tvořit tak i ledové cesty (mosty), ovšem pokud po nich mají projít ostatní roboti, musí být cesta přímá.

**Akce 2 — Odložení předmětu:** Yeo může nést kanystry s palivem i pro jiného robota než pro sebe (např. je donést Setovi); Akce 2 slouží k odložení neseného kanystru, viz [Odhazování předmětů](#213-interaktivní-prvky--ostatní-předměty).

#### 1.1.7 Elektrický — Il

Základní hmotnost je 2. Inspirovaný astrodroidem R2-D2, disponuje pájecím zařízením a USB přípojkou. Může se pohybovat po souši stejně jako většina ostatních, nemůže do vody. Po ledu klouže.

**Akce 1 — Interakce se zařízením:** Sama o sobě neprovádí nic — její efekt závisí na tom, co je před Ilem:

- Stojí-li Il před **rozbitou elektrickou skříní** a má u sebe **service kit**, skříň se opravou stane funkční a Il o kit přijde (spotřebuje se). Opravená skříň je **rovnou pod napětím** — stejně jako skříň, která poruchu vůbec neměla (ta je pod napětím od startu levelu). Hráč tedy nemusí po opravě skříň ještě zvlášť zapínat: napojené automatické čerpadlo nebo plošina se rozjede hned, jakmile jsou splněné jejich ostatní podmínky. Vypnout skříň lze až následně dalším stiskem Akce 1. Je-li skříň rozbitá a Il kit nemá, akce se neprovede.
- Stojí-li Il před **funkčním ovládacím panelem** (elektrická skříň nebo řídicí jednotka) a je k němu otočený ze správné strany, Akce 1 **stiskne tlačítko, resp. přehodí přepínač** daného panelu: u elektrické skříně se tím přepne napájení (zapnuto ↔ vypnuto), u řídicí jednotky se sepne napojené zařízení (transportní plošina nebo čerpadlo, viz [Ovládací panel](#221-ovládací-panel)). Il jako jediný může elektrická zařízení ovládat. Nedá-li se sepnutí provést (plošina nesplňuje hmotnostní limit, čerpadlo nemá co čerpat apod.), akce se neprovede.

Žádný zvláštní režim ovládání panelu neexistuje — jeden stisk Akce 1 je jedno sepnutí. Chce-li hráč panel sepnout znovu, stiskne Akci 1 znovu; mezitím může s Ilem dělat cokoli jiného (i odejít, ovšem pak už panel není na dosah).

**Akce 2 — Odložení service kitu:** Il může sbírat service kity, které využívá k opravě rozbitých elektrických zařízení (viz Akce 1). Akce 2 odloží nesený service kit, většinou za účelem uvolnění místa v inventáři.

---

## 2. Scény

### 2.1 Level

#### 2.1.1 Zahájení levelu

Level se zahajuje načtením informací o levelu ze souboru (viz [Formát uložení levelu](#222-levely-a-jejich-původ)). Podle nich se umístí všechny prvky, které scéna obsahuje, na své pozice — včetně robotů. Kamera se poté zaměří na prvního aktivního robota; pořadí/identita prvního aktivního robota je rovněž součástí definice levelu.

**Úvodní přelet kamery** — Level může mít v souboru uloženou volitelnou úvodní pozici kamery (nastavuje se v editoru, viz [Ovládací panel](#221-ovládací-panel)). Má-li ji, hra mezi načtením levelu a začátkem hraní vloží krátkou intro animaci: kamera se nejdřív umístí přesně do uložené pozice a poté se během tří sekund plynule přesune do výchozí herní pozice, ve které už sleduje prvního aktivního robota (viz výše) — tou přelet končí a hra pokračuje běžným způsobem. Po dobu přeletu je ovládání uzamčené (nelze zadávat příkazy ani otáčet kamerou), stejně jako během přehrávání animace kroku (viz [2.1.2](#212-řízené-prvky--roboti)); přelet lze stejnou klávesou přeskočit. Nemá-li level úvodní pozici uloženou, žádná intro animace se nekoná a hra začíná rovnou pohledem na prvního robota.

**Úvodní textová zpráva** — Level může mít v souboru uloženou i volitelnou úvodní textovou zprávu (nastavuje se v editoru, viz [Ovládací panel](#221-ovládací-panel)) — prostý text bez zvýraznění, kde se odstavce oddělují prázdným řádkem. Má-li ji, zobrazí se hráči ihned po příjezdu kamery na její výchozí pozici, tj. po skončení úvodního přeletu (viz výše), nebo hned na začátku levelu, který žádný přelet nemá. Zpráva se objeví zacentrovaná na obrazovce na poloprůsvitném pozadí orámovaném černým rámem o tloušťce 5 px a zavírá se klávesou Enter nebo tlačítkem "Zavřít". Po dobu zobrazení je ovládání uzamčené stejně jako během přeletu kamery. Nemá-li level zprávu uloženou, žádná se nezobrazí a hra pokračuje rovnou.

**Kamera**

Kamera se vždy dívá směrem k aktuálně aktivnímu robotovi — při výměně aktivního robota (viz [Ovládání robotů](#212-řízené-prvky--roboti)) se přepne i cílový bod kamery na nově aktivního robota.

Hráč může kamerou kolem aktivního robota otáčet pomocí myši, a to jak vodorovně, tak svisle, a přibližovat/oddalovat ji kolečkem myši. **Vzdálenost kamery od robota se mění výhradně kolečkem myši** — nikdy se neupravuje automaticky. Kamera tedy nijak neuhýbá překážkám: leží-li mezi ní a robotem kostka, robot prostě není vidět a hráč si pohled sám otočí nebo oddálí. Není podmínkou, aby byl robot vždy viditelný; podmínkou je, že kamera na něj vždy míří.

Kameru lze dočasně přepnout do režimu **first person**, ve kterém hráč vidí scénu přímo z pohledu robota (přesně to, co má robot před sebou). Tento režim se hodí typicky v situacích, kdy robot vstupuje do uzavřených či jinak špatně přehledných prostor.

#### 2.1.2 Řízené prvky – roboti

**Ovládání robotů**

Každý robot může provádět až čtyři různé úkony: otočení, krok vpřed a dvě akce specifické pro každého robota. Aktivní je vždy jeden robot a v předem dané sekvenci je možné vybírat mezi jednotlivými roboty, kteří se nachází na scéně.

**Přepínání aktivního robota**

Roboti na scéně mají pevné, stále se opakující pořadí (definované levelem, viz [Zahájení levelu](#211-zahájení-levelu)). Klávesou Tab (mapování konfigurovatelné) se aktivní robot posune na dalšího v této sekvenci; po posledním robotovi se sekvence vrací na prvního.

Součástí UI scény je i možnost přímého výběru — kliknutím na konkrétního robota (jeho ikonu/reprezentaci v UI) se tento robot stane aktivním bez ohledu na pořadí v sekvenci.

Přepnutí (ať už přes Tab, nebo kliknutím) je podmíněné tím, že aktuálně aktivní robot je v bezpečí — přepnutí se neprovede, pokud by aktivní robot zůstal ve stavu, kde by mohl dojít k jeho zničení, kdyby byl ponechán bez zásahu hráče. Konkrétně se to týká robota Da: ten musí být přistálý na pevném podkladu, nemůže zůstat viset ve vzduchu. Pokud se hráč pokusí přepnout pryč z Da ve chvíli, kdy je ve vzduchu, přepnutí se odmítne a Da zůstává aktivní.

Obecná podmínka "robot je v bezpečí" je specifikovaná pro Da (vznášení se ve vzduchu, viz výše). Netovo šplhání (nahoru i dolů) naproti tomu žádnou takovou podmínku nepotřebuje — šplhání je od začátku do konce **jeden** krok (stejně jako klouzání po ledu, viz [Led](#214-statické-prvky--překážky)): po dobu jeho provádění je uživatelský vstup neaktivní a nelze provést žádnou jinou akci ani přepnutí, teprve po jeho dokončení může hráč zadat další příkaz. Net se tedy nikdy nezastaví uprostřed šplhání v mezistavu, ze kterého by šlo přepnout pryč — otázka je tím zodpovězená.

Otáčet se mohou všichni roboti neomezeně. Při provádění kroku vpřed i akcí je vždy třeba vyhodnotit, zda daný robot má možnost daný úkon provést a zda jsou splněné příslušné podmínky.

**Inventář**

Každý robot může nést až čtyři předměty současně, s výjimkou Da, který nese jen jeden. Má-li robot plný inventář, další předmět, na jehož políčko by vstoupil, se pro něj chová jako překážka — musí nejdřív nějaký nesený předmět odložit (viz Akce 2 u jednotlivých robotů, kde je definovaná). Robot Net může šplhat směrem vzhůru pouze tehdy, má-li u sebe nejvýše dva předměty; s více předměty může už jen sešplhat dolů (viz [1.1.4 Net](#114-přírodní--net)).

Robot se nemůže rozbít ani pokazit — pokud by jakýkoli krok či akce představovaly jeho zničení, úkon se neprovede. Kromě vodního robota nemůže žádný robot do hluboké vody. Žádný robot kromě létajícího nesnese pád z výšky. Žádný robot kromě přírodního nemůže šplhat po stěnách (a i ten má šplhání omezené jen na ideální podmínky popsané výše).

Základní úkony:

- **Vlevo vbok** – robot se otočí přesně o 90° vlevo
- **Vpravo vbok** – robot se otočí přesně o 90° vpravo
- **Čelem vzad** – robot se otočí přesně o 180°
- **Krok** – provedení kroku (a případných navazujících dílčích kroků) se vyhodnocuje mechanismem popsaným níže, viz *Mechanismus vyhodnocení kroku (behavior tree)*.
- **Akce 1** – akce specifická pro každého robota, je-li definovaná.
- **Akce 2** – jiná akce specifická pro každého robota, je-li definovaná.

*(Popisy jednotlivých robotů viz [1.1 Roboti](#11-roboti).)*

**Mechanismus vyhodnocení kroku (behavior tree)**

Krok robota (a obecně jakýkoli jeho pohyb v mřížce, včetně specifických případů jako pohyb Dula ve vodě) se vyhodnocuje pomocí behavior tree. Každý robot má vlastní strom odrážející jeho pohybové schopnosti — dodá je autor ručně, viz poznámka níže.

Kolem robota jsou umístěné raycasty, kterými strom při průchodu kontroluje obsah okolních kostek — typicky kostku před robotem, kostku pod ním a kostku, na kterou by měl robot následně vstoupit.

Souběžně s průchodem stromem se plní fronta dílčích kroků. Jeden krok hráče se totiž může skládat z více dílčích kroků (např. sjetí po sérii šikmin nebo skluz po ledu). Dílčí kroky jsou kódované čísly:

| Kód | Význam |
|---|---|
| `0` | Jeden krok vpřed bez další změny výšky |
| `1` | Krok vpřed a nahoru (po šikmině) |
| `2` | Krok svisle nahoru |
| `-1` | Krok vpřed a dolů (po šikmině) |
| `-2` | Krok svisle dolů |

Průchod stromem vrací jeden ze tří stavů:

- **SUCCESS** – provede se celá sekvence dílčích kroků nashromážděná ve frontě.
- **FAIL** – krok se neprovede vůbec, fronta se zahodí.
- **RUNNING** – kontrolní raycasty se posunou o právě zamýšlené dílčí kroky (ty se přidají do fronty) a vyhodnocení stromu proběhne znovu z nové pozice. To se může opakovat vícekrát, dokud vyhodnocení neskončí stavem SUCCESS nebo FAIL.

> ⚠️ *Nedokončeno:* konkrétní rozhodovací stromy jednotlivých robotů (jaké podmínky vedou k SUCCESS/FAIL/RUNNING a jaké dílčí kroky se přitom přidávají do fronty) dodá autor ručně, doplní se postupně mimo/do tohoto dokumentu.
>
> Obdobný rozhodovací mechanismus (ne nutně stejný behavior tree jako u kroku, ale analogická sada podmínek) bude potřeba i pro některé akce, ne jen pro krok samotný — typicky pro Akci 1 Hana a Seta, kde je třeba před zničením/odebráním kostky ověřit, zda pod ní nestojí jiný robot (viz [1.1.1 Han](#111-zemní--han) a [1.1.3 Set](#113-ohnivý--set)). Konkrétní podobu tohoto rozhodování dodá autor ručně stejně jako u kroku.

#### 2.1.3 Interaktivní prvky – ostatní předměty

**Sebrání předmětu** — Robot sebere předmět automaticky tím, že na jeho políčko vstoupí (nevyžaduje samostatnou akci), pokud pro daný typ předmětu a robota není uvedeno jinak. Výjimkou je Da, který musí na předmět naletět shora — ze strany je pro něj předmět překážkou (viz [1.1.5 Da](#115-létající--da)). Kapacita inventáře je popsaná v [2.1.2](#212-řízené-prvky--roboti).

**Palivo** — Předmět, který mohou sbírat roboti Set, Net, Da a Yeo, aby mohli provést svou akci (spálení, zmražení) nebo aby jej mohli doručit na jiné místo. Pro ostatní roboty je předmět překážkou, přes kterou nemohou přejít. Použitím (Set, Yeo) palivo zaniká.

**Opravářská sada (service kit)** — Předmět, který mohou sbírat roboti Net, Da a Il. Slouží k opravě rozbitých elektrických zařízení; opravovat je může pouze Il. Po úspěšné opravě service kit zaniká.

**Odhazování předmětů** — Roboti Set, Net, Da, Yeo a Il mohou sbírat některé předměty (viz výše), které si ukládají do inventáře; jejich Akce 2 slouží k odhození takového předmětu (u Da s vlastním omezením „pod sebe", viz [1.1.5 Da](#115-létající--da)). Před odhozením proběhne stejná kontrola místa dopadu jako u Hanova vysypávání korby ([1.1.1 Han](#111-zemní--han)) — odhození se neprovede, pokud by předmět dopadl na jiného robota. Odhození do vody je možné bez dalšího omezení a hladina vody se tím nezvýší (na rozdíl od hliněné kostky nemá předmět vlastní objem, který by nádrž zabíral). Odhozený předmět ve vodě je ale problematické znovu vylovit, protože Dul předměty nemůže sbírat — obecně se odhazování předmětů do vody nedoporučuje.

#### 2.1.4 Statické prvky – překážky

**Zeď** — Kostka tvořící neprůchodnou a nezničitelnou překážku (beton nebo ocel); nelze ji nijak přesunout ani zničit. Robotům ve stejné výšce, v jaké zeď je, brání v průchodu. Robot o úroveň výš se může po horním povrchu zdi normálně pohybovat, tj. může na něj vstoupit jako na kterýkoli jiný pevný povrch.

**Okraj levelu** — Level je kvádr, přísně ohraničený prostor; za jeho hranice se nelze dostat žádným způsobem.

**Šikmina** — Speciální druh zdi s nízkou a vysokou stranou (bokorys pravoúhlého trojúhelníku, objem jedné kostky). Může být natočená čtyřmi směry a představuje cestu mezi vertikálními úrovněmi. Ze stran je nepřůchodná, nelze na ni nic odložit ani na ni vysypat korbu, nelze na ní setrvat.

Z toho, že na šikmině nelze setrvat, plyne pravidlo pro krok: **dílčí krok na šikminu nikdy nesmí být poslední.** Hra proto ještě před provedením kroku ověří, že za šikminou je místo, na které robot může vstoupit podle ostatních pravidel (rovina, další šikmina v sérii, led, u Dula voda) — a teprve pak celý krok provede jako jeden příkaz hráče. Není-li kam pokračovat (propast, zeď, obsazená buňka), krok se **neprovede vůbec** a robot na šikminu ani nevstoupí — stejná logika jako u skluzu po ledu. "Být na šikmině" přitom znamená obojí: být v buňce šikminy (tam robot dojede při sestupu) i být v buňce nad ní (tam vyjde při výstupu).

**Hlína** — Kostka tvořící neprůchodnou překážku pro všechny kromě Hana, který ji může vykopat akcí 1 (viz výše). Kostky nad ní, které mohou spadnout, se posunou o úroveň níž.

**Kámen** — Nezničitelná překážka. Na rozdíl od zdi reaguje na gravitaci — pokud se prostor pod ní uvolní, posune se o úroveň níž. Stojí-li na zdi nebo na nejnižší úrovni levelu, chová se identicky se zdí.

**Dřevo** — Kostka tvořící neprůchodnou překážku, kterou může zničit robot Set svou akcí 1 (viz [1.1.3 Set](#113-ohnivý--set)). Po zničení po ní nezůstává vůbec nic. Stejně jako hlína a kámen podléhá gravitaci — uvolní-li se prostor pod ní, spadne o úroveň níž (a to i předtím, než je zničena). Pojem "dřevěná plošina" ze synopse je zrušen — dřevo je čistě zničitelná překážka, nemá žádnou zvláštní roli plošiny ani nosnostní chování.

**Led** — Ve stejné úrovni jako robot se chová jako zeď. Je-li robot o úroveň výš, může na led vstoupit, ale sklouzne po něm — pošle-li hráč (u jakéhokoli robota kromě Yea a Da) krok na led, hra nejdřív ověří, zda na konci ledové plochy ve směru pohybu čeká zeď nebo jiný pevný povrch; pokud ano, robot v rámci **jednoho příkazu** (jednoho stisku klávesy pro krok) sklouže celou tuto vzdálenost najednou jako jeden dlouhý krok složený z více dílčích kroků, směr nelze uprostřed klouzání změnit. Pokud cesta na konci ledu nekončí pevným povrchem (je tam propast), vstup na led se vůbec neprovede. Led nepodléhá gravitaci a nikdy nepadá — je vždy pevně ukotvený k místu, kde vznikl, bez ohledu na to, co se stane s podkladem pod ním.

Led může vzniknout pouze ve vodě, a to akcí 1 robota Yeo (viz [1.1.6 Yeo](#116-ledový--yeo)), a pouze tehdy, stojí-li Yeo na pevném podkladu, nebo na jiné kostce ledu — díky tomu může stavět ledové cesty/mosty kostku po kostce přes otevřenou vodu. Ledové kostky nelze umístit mimo nádrž (viz [Umístění objektů](#221-ovládací-panel)) — v levelu vždy existují jen jako zmrzlá voda uvnitř zatopené oblasti. Chceme-li zničitelnou překážku pro Seta mimo vodu, použije se dřevo (viz výše).

Vytvoření ledové kostky zmenší kapacitu nádrže o jednu kostku a zároveň o stejnou jednu kostku zmenší objem vody v nádrži — kapacita i objem klesnou 1:1, takže se hladina zbytku vody v nádrži vůbec nepohne. Roztaje-li Set ledovou kostku svou akcí 1 (viz [1.1.3 Set](#113-ohnivý--set)), děje se přesná reverze: kapacita nádrže i objem vody se zvýší o stejnou jednu kostku, takže se hladina opět nepohne — na rozdíl od vypuštění cisterny (viz [Akce 2 — Vypuštění cisterny](#112-vodní--dul)), kde kapacita zůstává stejná a přibývá jen objem, takže tam hladina skutečně stoupá (včetně kontroly na utonutí, viz [Voda](#214-statické-prvky--překážky)). Před roztavením se navíc kontroluje riziko plovoucí kry, viz [1.1.3 Set](#113-ohnivý--set).

**Voda** — Zatopené oblasti (nádrže) s danou kapacitou. Je-li v nádrži méně vody než polovina objemu dna, mohou do ní vstoupit všichni roboti (voda sahá max. po pás). Je-li vody více, může do nádrže pouze Dul. Je-li nádrž plná nebo blízko plná (méně místa než polovina kostek tvořících hladinu), Dul může vstoupit ze břehu i čerpat ze břehu; jinak musí použít šikminu nebo transportní plošinu. Šikmina počítá do kapacity nádrže jako půl kostky.

Nádrž lze označit jako **neomezenou** — její hladina se pak nikdy nemění, ať už se do ní čerpá, nebo se z ní čerpá. V editoru není možné nastavit čerpadlo tak, aby čerpalo *z* neomezené nádrže do jiné — čerpat *do* neomezené nádrže možné je. Dul z neomezené nádrže čerpat smí (jeho akce 1 není čerpadlo, viz [1.1.2 Dul](#112-vodní--dul)) — hladina se tím nezmění; stejně tak se hladina nezmění, vypustí-li do ní Dul svou cisternu.

**Maximální bezpečná hladina (utonutí).** Žádný robot kromě Dula nesmí být v situaci, kdy by mu voda sahala výš než po pás, tj. hladina nádrže, ve které stojí, přesahuje 50 % objemu dna — takový stav se považuje za utonutí a nesmí nastat. Toto omezení platí univerzálně pro jakýkoli způsob, kterým se hladina může zvýšit, ať už jde o krok robota do nádrže, vysypání korby (Han), vypuštění cisterny (Dul), roztavení ledu (Set), nebo automatické čerpadlo ovládané elektrickou skříní/řídicí jednotkou (viz [Nádrže a čerpadla](#221-ovládací-panel)). Kdykoli by daný úkon vedl k tomu, že by v nádrži s jiným robotem (kromě Dula) hladina po jeho provedení přesáhla 50 % objemu dna, úkon se **neprovede vůbec** — u čerpadla to znamená, že se zastaví celý přenos, neproběhne ani jeho "bezpečná" část. Stejně tak, chce-li Dul vypustit cisternu do nádrže s jiným robotem a hladina by tím překročila limit, akce se neprovede.

#### 2.1.5 Klíč a cíl

**Klíč** — Interaktivní předmět, který lze sebrat. Nemá žádnou hmotnost a pro žádného robota nepředstavuje žádné jiné omezení (nijak neomezuje pohyb ani nosnost). V každém levelu je vždy přesně jeden klíč — ani víc, ani méně.

**Cíl** — Kostka, do které se musí dostat všichni roboti přidělení danému levelu. Cíl je zpočátku zamčený a je neprůchodný. Odemyká se tak, že jej klíčem projde robot, který klíč sebral — tento robot tedy musí cílem projít jako první. Teprve po odemčení mohou cílem projít i ostatní roboti.

Dojde-li robot do cíle, zmizí ze scény a hra automaticky přepne aktivního robota na dalšího v sekvenci, stejně jako by přepnutí vyvolal hráč (viz [Přepínání aktivního robota](#212-řízené-prvky--roboti)); dokončený robot ze sekvence přepínání zcela vypadne. Robot, který vešel do cíle, tak už nemůže žádným způsobem pomoci ostatním robotům, ani kdyby to bylo pro dokončení levelu potřeba — hráč si na to musí dát pozor předem.

#### 2.1.6 Podmínka ukončení levelu / restart

Hra neobsahuje klasickou "prohru" ve smyslu game over. Robot nemůže provést krok ani akci, které by vedly k jeho zničení — pokud by daný úkon vedl ke zničení, mechanismus vyhodnocení kroku (behavior tree, viz [2.1.2](#212-řízené-prvky--roboti)) jej vyhodnotí jako neproveditelný a úkon se vůbec neprovede.

Jediný způsob, jak level "prohrát", je, že hráč dospěje do stavu, ze kterého už není možné najít řešení — buď proto, že řešení reálně nenašel, nebo udělal nevratnou chybu, která správné řešení znemožnila. V takovém případě hráč sám vyvolá restart levelu z menu; hra sama takový stav nedetekuje ani jej nijak nevynucuje.

### 2.2 Editor

#### 2.2.1 Ovládací panel

**Nastavení scény** — Velikost levelu se definuje rozměrem v kostkách (délka, šířka, výška). Výška určuje maximální počet úrovní a maximální vzletovou výšku robota Da. Maximální rozměry nejsou omezené (velké levely jsou ale těžko smysluplně navrhnutelné). Rozměry lze měnit i během editace: u okrajů levelu jsou rozklikávací prvky, jeden pár (rozšířit/zúžit) pro každý ze čtyř vodorovných směrů a pro nahoru — dno levelu (směr dolů) se rozměrem nikdy nemění. Klik na „rozšířit" přidá řadu kostek v daném směru. Klik na „zúžit" řadu odebere, ale jen je-li celá prázdná — obsahuje-li cokoli (zeď, robota, předmět, zařízení, nádrž, klíč), zúžení se neprovede.

**Umístění objektů** — Objekty se umisťují striktně do krychlové mřížky, standardně vedle existujícího objektu. Přesun objektu: označení + tažení myší, nebo editace souřadnic přímo. Objekty (kromě zdí a šikmin) nelze umístit volně do vzduchu — vždy se kontroluje pevný podklad pod nimi. Na šikminu nelze umístit nic.

**Nastavení objektu** — Každý objekt má vlastní nastavitelné vlastnosti. Hra je založená na grafické rozmanitosti — každému objektu (kromě robotů, kteří jsou vždy stejní) se přiřazuje model z dostupné knihovny. Každý objekt lze natočit do jednoho z šesti směrů, se zachováním smysluplnosti (např. šikminu nelze umístit svisle). Elektrické skříně a řídicí jednotky lze ovládat jen z jednoho směru — dostat se k nim ze správného směru může být samostatná hádanka. Elektrické skříně lze nastavit jako defaultně funkční/nefunkční (vyžadující opravu). Řídicí jednotky lze nastavit jako tlačítko nebo přepínač — u plošiny znamená tlačítko jednorázový přejezd do druhé polohy, přepínač posílá plošinu podle potřeby do jedné i druhé polohy; u čerpadla znamená tlačítko jednorázové přečerpání předem daným směrem, přepínač přečerpávání střídavě jedním i druhým směrem. Sepnout tlačítko/přepínač může jedině Il svojí Akcí 1 (viz [1.1.7 Il](#117-elektrický--il)), a to ze správného směru; jeden stisk = jedno sepnutí.

**Elektrická zařízení v mřížce** — Elektrická skříň i řídicí jednotka zabírají **vlastní kostku**, která se pro všechny roboty chová jako **zeď**: je neprůchodná, nezničitelná, nepodléhá gravitaci a musí mít pod sebou pevný podklad (nelze ji umístit volně do vzduchu). Ovládat je lze jen z jednoho **vodorovného** směru — Il stojí v sousední kostce ve směru ovládání a je k zařízení otočený; přístup ze svislého směru (shora/zdola) neexistuje. V jedné kostce může být nejvýš jedno zařízení. Je-li kostka se zařízením součástí transportní plošiny, přesouvá se zařízení **spolu s ní** — je její pevnou součástí. Jinak zařízení přesunout ani zničit nelze žádným způsobem (platí pro něj pravidla zdi).

**Transportní plošiny** — Jednotné pojmenování pro to, co se v synopsi a jinde v textu občas označuje jako „výtah" — jde o tentýž prvek, název „výtah" je zavádějící (plošina se nemusí pohybovat jen svisle) a dál se nepoužívá. Skládají se ze série zdí. Definuje se, které objekty jsou součástí plošiny (nemusí být fyzicky u sebe) a mezi kterými dvěma polohami se pohybuje — pohyb může být vodorovný, svislý i diagonální, druhá poloha je libovolný posun (offset) vůči té první. Plošina musí být napojená alespoň na jednu elektrickou skříň a má definovaný **hmotnostní práh** pro uvedení do pohybu.

Práh je **dolní** mez: plošina se rozjede, teprve když je na ní aspoň tolik hmotnosti (součet hmotností robotů na jejích kostkách; nesené předměty se nepočítají). Horní mez nosnosti neexistuje — těžší náklad plošinu nezastaví. Práh platí stejně pro automatickou i manuální plošinu. Je-li plošina napojená pouze na elektrickou skříň (bez řídicí jednotky), je **automatická**: rozjede se sama v okamžiku, kdy je práh poprvé splněný (náběžná hrana), a další přejezd nastane, až podmínka mezitím přestane a znovu začne platit — plošina tedy mezi polohami nekmitá každý tah. Automatická plošina proto musí mít práh aspoň 1 (nulový práh by ji rozjel hned na startu levelu). Napojením i na řídicí jednotku (tlačítko/přepínač) se stává manuální a pohyb spouští hráč přes Ila (viz [1.1.7 Il](#117-elektrický--il)), přičemž práh platí i tak. Editor musí kontrolovat, že dráha plošiny neprochází skrz jiné statické objekty, i při plném vytížení — dráha mezi oběma krajními polohami tak musí být vždy prázdná a ve hře samotné z principu nemůže na dráze plošiny vzniknout žádná překážka.

**Náklad plošiny.** S plošinou se přesouvá všechno, co na ní stojí nebo leží: roboti, odložené předměty (kanystr, service kit) i **klíč**, leží-li volně na zemi na některé z kostek plošiny. Předměty a klíč nemají hmotnost, takže se do prahu nezapočítávají a samy plošinu nikdy nespustí — jen s ní cestují. (Předměty nesené robotem cestují samozřejmě s robotem.) Zůstat na staré souřadnici by znamenalo, že náklad po přejezdu visí ve vzduchu nad prázdným místem.

**Transportní plošina a voda.** Má-li plošina jednu z krajních poloh uvnitř nádrže a její přejezd by vedl k tomu, že by robot jiný než Dul skončil v hladině přesahující 50 % objemu dna (viz [Maximální bezpečná hladina](#214-statické-prvky--překážky)), plošina se zablokuje a přejezd se neprovede — bez ohledu na to, zda jsou splněné ostatní podmínky pro spuštění (hmotnostní limit nebo stisknutí tlačítka/přepínače).

**Nádrže a čerpadla** — Tvar a kapacita nádrže se odvozuje ze sestavy zdí, které ji ohraničují (nádrž nelze umístit volně): autor levelu označí kteroukoli kostku uzavřené dutiny a tím z ní udělá nádrž. Dutina, ze které by voda vytekla (dotýká se bočního okraje levelu nebo jinak neuzavřené stěny), nádrží být nemůže. Výjimkou je dno — nádrž smí ležet přímo na dně levelu bez vlastní podlahy z kostek, protože dno levelu se pro vodu chová jako plná zeď (na rozdíl od bočního okraje). Kromě tvaru se u nádrže nastavuje **počáteční objem vody** (v půlkostkových jednotkách, aby šla zapsat i hladina uprostřed kostky a půlkostkový objem šikminy; 1 kostka = 2 jednotky) — počáteční objem nesmí přesáhnout kapacitu nádrže. Lze nastavit kapacitu jako neomezenou (hladina se pak nikdy nemění a čerpadlo z ní čerpat nesmí).

Čerpadlo se definuje označením dvou nádrží (vzdálenost neomezená, model nepovinný), napojuje se na **jednu i více elektrických skříní** a případně na řídicí jednotku; definuje se defaultní zdrojová/cílová nádrž, resp. defaultní směr u obousměrného čerpadla. Čerpadlo funguje jen tehdy, jsou-li **všechny** napojené skříně opravené a pod napětím.

Jedno sepnutí přečerpá **100 % obsahu zdrojové nádrže** do cílové — ne pevnou dávku. Podmínkou je, že **volná kapacita cílové nádrže je stejná nebo větší** než objem vody ve zdrojové. Není-li, nepřečerpá se **nic** — ani ta část, která by se do cíle vešla; částečný přenos neexistuje (stejný princip jako u kontroly utonutí). Pravidlo mluví o objemu, ne o celých kostkách: je-li ve zdroji jen zbytek pod celou kostku, přečerpá se i ten. Zdrojová nádrž je po sepnutí vždy prázdná.

Čerpadlo napojené jen na skříň (bez řídicí jednotky) je **automatické**: přečerpá jednorázově v okamžiku, kdy jsou poprvé splněné všechny podmínky přenosu — všechny napojené skříně jsou opravené a pod napětím, ve zdrojové nádrži je nějaká voda, v cílové je volné kapacity aspoň tolik, kolik je vody ve zdrojové, a přenos by žádného robota neutopil (viz [Maximální bezpečná hladina](#214-statické-prvky--překážky)). Jde tedy o sledování náběžné hrany: dokud podmínka platí dál, čerpadlo už znovu nesepne; sepne až poté, co podmínka mezitím přestala platit a je splněná znovu. Protože sepnutí zdrojovou nádrž vyprázdní, podmínka po přenosu sama přestane platit — automatické čerpadlo tedy čeká, až se do zdroje dostane nová voda.

**Umístění robotů** — Do levelu lze umístit 1 až 7 robotů dle výběru, včetně pozice a směru. Umístění je možné pouze na zem nebo plochou zeď; Dul může být umístěn i ve vodě.

**Úvodní pozice kamery** — Autor levelu nastaví pohled volné kamery a tlačítkem jej uloží jako úvodní pozici pro intro přelet při spuštění levelu (viz [Úvodní přelet kamery](#211-zahájení-levelu)). Ukládá se v režimu umístění levelu do krajiny (viz [2.2.2](#222-levely-a-jejich-původ)), ne v běžném režimu umisťování do mřížky — přelet totiž přilétá krajinou (mezi domy, stromy apod.), takže si autor musí polohu kamery ověřit přímo v krajině, ne v izolovaném pohledu na mřížku levelu. Level bez uložené pozice žádnou intro animaci nemá; samostatné tlačítko na zrušení uložené pozice není potřeba — přepsat ji stačí uložením nové. Uložená pozice je součástí souboru levelu.

**Úvodní textová zpráva** — Tlačítkem v ovládacím panelu jde otevřít textové pole, do kterého autor napíše prostý text (odstavce odděl prázdným řádkem) zobrazený hráči po příjezdu kamery na začátku levelu (viz [Úvodní textová zpráva](#211-zahájení-levelu)). Prázdné pole znamená, že level žádnou zprávu nemá. Text je součástí souboru levelu.

#### 2.2.2 Levely a jejich původ

Od verze 0.1.0 je editor součástí hry. Levely do oficiální hry nejsou dodávány předem navrženou sadou — vznikají v editoru (autorem nebo přáteli) a z takto vytvořených levelů se následně vybírají ty, které se stanou součástí oficiální hry. Počet a struktura levelů proto nejsou v této fázi vývoje relevantní a nejsou touto specifikací určovány.

**Formát uložení levelu** — Level (sestava kostek a předmětů, počáteční pozice robotů, propojení elektrických zařízení) se ukládá v binárním formátu, aby nebyl snadno editovatelný mimo editor. Konkrétní bajtová struktura a verzování formátu nejsou předmětem tohoto dokumentu.

---

## Otevřené otázky / TODO

Seznam částí, které dokument v aktuální podobě neřeší a je třeba je doplnit průběžně s vývojem:

- [x] ~~Doplnit konkrétní rozhodovací strom (behavior tree) pro krok robota Dula po souši/vodě~~ — pravidla kroku jsou doplněná v [1.1.2 Dul](#112-vodní--dul) (vstup do vody a výlez z ní včetně tolerance a rozhraní s ledem) a strom podle nich existuje.
- [ ] Doplnit konkrétní rozhodovací stromy jednotlivých robotů pro krok obecně (viz [2.1.2](#212-řízené-prvky--roboti)) — dodá autor postupně.
- [x] ~~Zahájení levelu — případné intro/cutscény~~ — úvodní přelet kamery z volitelné uložené pozice je popsaný v [2.1.1](#211-zahájení-levelu) a [2.2.1](#221-ovládací-panel).
- [ ] Scéna výběru/přepínání aktivního robota — logika (sekvence, klávesa Tab, klik v UI, podmínka bezpečí) je popsaná v [2.1.2](#212-řízené-prvky--roboti); vizuální stránka (podoba UI panelu s roboty) řešena až v 0.2.0.
- [ ] Konkrétní bajtová struktura a verzování binárního formátu levelu (viz [2.2.2](#222-levely-a-jejich-původ)) — až bude aktuální pro implementaci editoru/runtime.

> Poznámka: Vizuál (art styl, UI, zvuk, grafické zpracování) je záměrně mimo scope této fáze dokumentu — řeší se až od verze 0.2.0.
