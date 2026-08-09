# Nature Cybernetic Robots

*S roboty přes překážky do kybernetického nebe*

Zbyněk Rybička, 2026

> **Poznámka k tomuto dokumentu:** Toto je pracovní verze přenesená z původního PDF (viz `docs/Nature_Cybernetic_Robots.pdf` pokud je uloženo). Dokument není hotový — chybí mimo jiné dokončení kroku robota Dula, popis scény výběru robota, menu, UI, počet a struktura levelů, art styl a ovládání kamery. Doplňuje se průběžně jako součást vývoje hry.

## Obsah

1. [Synopse](#1-synopse)
   1. [Roboti](#11-roboti)
2. [Scény](#2-scény)
   1. [Level](#21-level)
   2. [Editor](#22-editor)

---

## 1. Synopse

Logická hra, ve které hráč ovládá sedm robotů, z nichž každý má jiné schopnosti pohybu či ovlivňování okolního prostředí, a společně se snaží dostat do cíle. Hra se dělí na úrovně, které jsou tvořené krychlovou mřížkou, a jak roboti, tak ostatní předměty a překážky jsou součástí této mřížky a mohou se pohybovat pouze v rámci ní. Hra neobsahuje žádný prvek náhody ani umělé inteligence, vše je plně v rukou hráče.

Cílem každé úrovně je dostat všechny přidělené roboty na dané scéně do cíle, přičemž na scéně se vždy nachází i klíč, který je třeba najít předtím, a robot, který klíč najde, musí cílem projít jako první.

Každý robot má svoji hmotnost, na kterou mohou některé předměty reagovat. Při překročení maximální nosnosti se mohou rozbít (dřevěná plošina) nebo přestanou fungovat (výtah). Každý robot má možnost sbírat a držet předměty — některé všichni, některé jen někteří. Nesené předměty se přičítají do celkové hmotnosti.

Roboti se standardně mohou pohybovat po souši. Do vody vstoupit nemohou (s výjimkou vodního, který se ve vodě chová jako ponorka). Vstoupí-li na led, sklouznou se po něm tak daleko, než přejdou na první políčko jiného povrchu nebo narazí na překážku. Pokud je na konci ledové dráhy propast, na led vstoupit nejde. Výjimkou je ledový robot, který se může po ledu pohybovat stejně jako po souši.

### 1.1 Roboti

#### 1.1.1 Zemní — Han

Základní hmotnost je 2. Může odstraňovat kostky hlíny, přičemž když jednu kostku odstraní, naplní se mu korba, kterou musí následně zase jinde vyložit, jinak nemůže kopat dál. Může vyhrabat kostku přímo před sebou, pod sebou (přičemž tím se dostane na nižší úroveň) nebo která je z jeho pohledu šikmo dolů před ním. Vysypávat hlínu může pouze za sebe. Ale může se otáčet na místě, takže směr není zásadní překážka. Pokud vykope kostku, na níž jsou další kostky či jiné předměty, vše se propadne o úroveň níž. Pokud robot vyklopí korbu, kostka spadne na nejbližší pevný podklad. Lze vyklápět i do vody. Při vyklopení na led se z ní stává pevná překážka.

**Akce 1 — Nahrábnutí:** Stojí-li Han před kostkou z hlíny, nebo hliněná kostka tvoří povrch jeden krok před ním, nebo stojí přímo na ní, provede nahrábnutí hliněné kostky na korbu. Tím kostku odstraní a daným místem je možné projít. Pokud nad hliněnou kostkou byly jiné kostky, které mohou spadnout (dřevo, kámen, led, další hlína...), tyto kostky spadnou. Hrabat lze pouze, pokud má Han prázdnou korbu. Pokud Han vyhrabe kostku v oblasti s mělkou vodou (do hluboké nemůže), voda ihned zaplní vyhrabanou díru a celková hladina klesne.

**Akce 2 — Vysypání korby:** Pokud má Han za sebou volný prostor (nestojí zády přímo u zdi), korba se vysype a vytvoří tak za sebou hliněnou kostku stejné velikosti jako předtím nabíral. Pokud Han stojí zády nad propastí, kostka spadne dolů na nejbližší pevný povrch, na který natrefí. Je možné vysypat korbu i do vody — pokud by však na místě dopadu kostky byl jiný robot, vysypání není možné. Pokud Han vysype korbu do vody, stoupne celková hladina v zatopeném prostoru; pokud by hladina měla stoupnout natolik, že by se v ní Han nebo jiný robot utopili (kromě Dula), vysypání není možné.

#### 1.1.2 Vodní — Dul

Základní hmotnost je 2. Vypadá jako cisterna s čerpadlem, disponuje i lodním šroubem. Po suchu se může pohybovat jako ostatní, tedy rovně a po šikminách, nemůže skákat. Může se pohybovat po vodě. Do vody může vstoupit pouze v případě, že povrch, na kterém stojí, je ve stejné výšce jako vodní hladina zatopené oblasti. Ve stejné situaci jako jediný může z vody vylézt. Ve vodě se může pohybovat vodorovně i svisle. Ponořit se může vždy až na dno, není limitován maximálním ponorem.

**Akce 1 — Načerpání vody:** Lze provést, má-li Dul prázdnou cisternu a nachází se přímo ve vodě, nebo stojí čelem k zatopené oblasti s hladinou ve výšce maximálně půl kostky pod jeho polohou. Při načerpání klesne hladina zatopené oblasti adekvátně objemu — má-li zatopená oblast hladinu o rozloze pěti kostek, hladina klesne o jednu pětinu výšky kostky.

**Akce 2 — Vypuštění cisterny:** Cisterna se vypouští směrem dozadu. Vodu lze vypustit pouze do zatopených oblastí či oblastí určených pro zatopení. Hladina zatopené oblasti stoupne adekvátně objemu jedné kostky. Pokud by zvýšení hladiny způsobilo utopení jiného robota, vypuštění se neprovede.

> ⚠️ *Nedokončeno v originále:* popis akce "Krok" pro Dula (specifické podmínky kroku po souši/vodě) není v PDF dopsán — je třeba doplnit.

#### 1.1.3 Ohnivý — Set

Základní hmotnost je 2. Může se pohybovat po souši a po šikminách stejně jako ostatní roboti. Na rozdíl od ostatních může projít i skrze hořící oheň, aniž by mu to uškodilo. Set jako jeden ze dvou robotů (spolu s Netem, Dou a Yeem) má možnost sbírat kanystry s palivem, které může následně použít pro svoji akci. Pro ostatní roboty jsou kanystry překážkou.

**Akce 1 — Zapálení a odstranění překážky:** Vyžaduje palivo a to, aby překážka před ním byla ohněm zničitelná (dřevo nebo led, případně další materiály). Set může zničit překážku, kterou má krok před sebou vodorovně, šikmo nebo svisle (v tomto pořadí priority). Po provedení akce přijde Set o kanystr s palivem. Pokud zničí překážku, vše nad ní se propadne o úroveň níž.

**Akce 2 — Odložení kanystru:** Pokud má Set u sebe nevyužitý kanystr s palivem, nechá jej za sebou, aby odlehčil svoji váhu nebo aby si ho mohl vzít kolega.

#### 1.1.4 Přírodní — Net

Základní hmotnost je 2. Může se pohybovat po souši stejně jako většina ostatních, nemůže do vody, ale za to může šplhat po stěnách jako brouk (vypadá jako brouk — šest nožiček místo koleček).

Na stěně však nemůže zůstat viset. Před krokem představujícím šplhání po stěně se kontroluje, zda je na vrcholu stěny pevný podklad, na kterém se může usadit. Pokud stěna končí stropem, krok není možné provést. Šplhání do výšky je podmíněné maximální hmotností 4 — může tedy u sebe nést dva kanystry paliva nebo service kity. Šplhání vzhůru není možné, pokud je jedna nebo více kostek na stěně z ledu.

Při šplhání směrem dolů se kontroluje, zda je možné sešplhat — stěna nesmí končit ve vzduchu ani ve vodě, pod ní musí být pevný podklad. Na šplhání dolů se nevztahuje hmotnostní limit — může slézt i se čtyřmi kanystry, ale pak už nemůže nahoru, pokud je neodhodí.

Sám nemůže nic stavět ani bořit — jedná se o pomocníka, který umí přinést, co je potřeba.

**Akce 1:** Net neprovádí.

**Akce 2 — Odložení předmětu:** Odloží předmět z inventáře, který se umístí za něj. Musí být volný prostor (nesmí být přímo za robotem zeď).

#### 1.1.5 Létající — Da

Základní hmotnost je 1. Vypadá jako dron. Může se pohybovat libovolně vodorovně i svisle, nemá-li před sebou překážku. Jeho limity jsou pevné překážky a hranice úrovně (nejsou vidět, ale robot skrze ně neprojde) horizontální i vertikální. Nemůže do vody. Rovněž nesmí zůstat ve vzduchu, pokud jej chcete vyměnit — pro výměnu je nutné nejprve přistát.

Může sebrat jeden předmět, avšak musí na něj naletět shora — pokud by byl předmět pod nízkým stropem, naložit jej nemůže. Maximální nesená hmotnost je 2.

**Akce 1:** Da neprovádí.

**Akce 2 — Odhození předmětu:** Předmět musí odhodit pod sebe, alespoň o jednu kostku. V případě, že odhodí předmět, nemůže na daném místě přistát bez toho, aniž by jej znovu sebral.

#### 1.1.6 Ledový — Yeo

Základní hmotnost je 2. Nosí chladicí těleso jako hlavici. Po souši se může pohybovat stejně jako většina ostatních, nemůže do vody. Po ledu se na rozdíl od ostatních může pohybovat neomezeně stejně jako po souši.

**Akce 1 — Vytvoření ledové kostky:** Musí být na břehu a vodní hladina před ním vyšší než do poloviny okrajové kostky. Vyžaduje kanystr s palivem. Vytvoří před sebou ledovou kostku, která je pevně uchycená o podklad, na kterém stojí on sám — nemůže spadnout a její nosnost je teoreticky nekonečná. Yeo se jako jediný může pohybovat po ledu libovolně a tvořit tak i ledové cesty (mosty), ovšem pokud po nich mají projít ostatní roboti, musí být cesta přímá.

**Akce 2:** Yeo neprovádí.

#### 1.1.7 Elektrický — Il

Základní hmotnost je 2. Inspirovaný astrodroidem R2-D2, disponuje pájecím zařízením a USB přípojkou. Může se pohybovat po souši stejně jako většina ostatních, nemůže do vody. Po ledu klouže.

**Akce 1 — Interakce se zařízením:** Pokud stojí před elektrickým zařízením a napojí se na něj, hráč přebírá kontrolu nad daným zařízením. Il jako jediný může elektrická zařízení ovládat.

**Akce 2 — Odložení service kitu:** Il může sbírat service kity a jako jediný jimi opravovat rozbitá elektrická zařízení (po úspěšné opravě se kit spotřebuje). Akce 2 slouží k odložení neseného service kitu, většinou za účelem snížení celkové hmotnosti.

---

## 2. Scény

### 2.1 Level

#### 2.1.1 Zahájení levelu

> ⚠️ *Nedokončeno v originále* — potřeba doplnit (např. intro/úvodní stav levelu, výchozí kamera, cutscény?).

#### 2.1.2 Řízené prvky – roboti

**Ovládání robotů**

Každý robot může provádět až čtyři různé úkony: otočení, krok vpřed a dvě akce specifické pro každého robota. Aktivní je vždy jeden robot a v předem dané sekvenci je možné vybírat mezi jednotlivými roboty, kteří se nachází na scéně.

Otáčet se mohou všichni roboti neomezeně. Při provádění kroku vpřed i akcí je vždy třeba vyhodnotit, zda daný robot má možnost daný úkon provést a zda jsou splněné příslušné podmínky.

Robot se nemůže rozbít ani pokazit — pokud by jakýkoli krok či akce představovaly jeho zničení, úkon se neprovede. Kromě vodního robota nemůže žádný robot do hluboké vody. Žádný robot kromě létajícího nesnese pád z výšky. Žádný robot kromě přírodního nemůže šplhat po stěnách (a i ten má šplhání omezené jen na ideální podmínky popsané výše).

Základní úkony:

- **Vlevo vbok** – robot se otočí přesně o 90° vlevo
- **Vpravo vbok** – robot se otočí přesně o 90° vpravo
- **Čelem vzad** – robot se otočí přesně o 180°
- **Krok** – provede se kontrola, zda je možné krok provést, a je-li to možné, krok se provede. Není-li stanoveno jinak (viz jednotlivý robot výše), krok se vyhodnocuje následovně:

  *Podmínky pro provedení kroku:*
  - Je-li prostor před robotem prázdný.
  - Je-li v prostoru pod cílovou pozicí pevný podklad nebo šikmina.
  - Je-li před robotem šikmina, je třeba vyhodnotit i následující pozici o kostku vpřed a jednu úroveň výš.
  - Je-li v prostoru pod cílovou pozicí šikmina, je třeba vyhodnotit i následující pozici; je-li podkladem na cílové pozici opět šikmina, kontrola se provádí opakovaně, dokud nenarazí na jiný objekt.
  - Vede-li cesta tvořená šikminami do hluboké vody, podmínka pro krok není splněná.
  - Je-li podklad před robotem ledový, vyhodnocují se i další podklady v cestě, dokud je prostor před robotem volný a podklad ledový. Narazí-li na jiný než ledový podklad, na který může vstoupit, nebo narazí na pevnou překážku, krok se provede. Narazí-li na prostor bez pevného podkladu, krok provést nelze.

  *Provedení kroku:*
  - Robot se posune směrem, kterým je natočený, o vzdálenost jedné kostky.
  - Je-li robot před šikminou, projde celou cestu tvořenou šikminami a zastaví se až za nimi.
  - Je-li podklad ledový, robot klouže po celé ledové cestě jako jeden krok a nemůže během klouzání měnit směr.

- **Akce 1** – akce specifická pro každého robota, je-li definovaná.
- **Akce 2** – jiná akce specifická pro každého robota, je-li definovaná.

*(Popisy jednotlivých robotů viz [1.1 Roboti](#11-roboti).)*

#### 2.1.3 Interaktivní prvky – ostatní předměty

**Palivo** — Předmět, který mohou sbírat roboti Set, Net, Da a Yeo, aby mohli provést svou akci (spálení, zmražení) nebo aby jej mohli doručit na jiné místo. Pro ostatní roboty je předmět překážkou, přes kterou nemohou přejít. Použitím (Set, Yeo) palivo zaniká.

**Opravářská sada (service kit)** — Předmět, který mohou sbírat roboti Net, Da a Il. Slouží k opravě rozbitých elektrických zařízení; opravovat je může pouze Il. Po úspěšné opravě service kit zaniká.

#### 2.1.4 Statické prvky – překážky

**Zeď** — Neprůchodná a nezničitelná překážka (beton nebo ocel). Je-li zeď o úroveň níže než robot, je možné na ni vstoupit jako na vyvýšený povrch.

**Okraj levelu** — Level je kvádr, přísně ohraničený prostor; za jeho hranice se nelze dostat žádným způsobem.

**Šikmina** — Speciální druh zdi s nízkou a vysokou stranou (bokorys pravoúhlého trojúhelníku, objem jedné kostky). Může být natočená čtyřmi směry a představuje cestu mezi vertikálními úrovněmi. Ze stran je nepřůchodná, nelze na ni nic odložit ani na ni vysypat korbu, nelze na ní setrvat.

**Hlína** — Kostka tvořící neprůchodnou překážku pro všechny kromě Hana, který ji může vykopat akcí 1 (viz výše). Kostky nad ní, které mohou spadnout, se posunou o úroveň níž.

**Kámen** — Nezničitelná překážka. Na rozdíl od zdi reaguje na gravitaci — pokud se prostor pod ní uvolní, posune se o úroveň níž. Stojí-li na zdi nebo na nejnižší úrovni levelu, chová se identicky se zdí.

**Led** — Ve stejné úrovni jako robot se chová jako zeď. Je-li robot o úroveň výš, může na led vstoupit, ale sklouzne po něm (klouzání = jeden krok, nelze měnit směr, končí-li cesta pádem, vstup není možný). Set jej může roztavit svou akcí 1 (zmizí zcela, i voda). Yeo jej může vytvářet svou akcí 1 ze zmrzlé vody a jako jediný se po ledu pohybuje bez omezení.

**Voda** — Zatopené oblasti (nádrže) s danou kapacitou. Je-li v nádrži méně vody než polovina objemu dna, mohou do ní vstoupit všichni roboti (voda sahá max. po pás). Je-li vody více, může do nádrže pouze Dul. Je-li nádrž plná nebo blízko plná (méně místa než polovina kostek tvořících hladinu), Dul může vstoupit ze břehu i čerpat ze břehu; jinak musí použít šikminu nebo výtah. Nádrž s neomezenou kapacitou nemění hladinu při čerpání/napouštění. Šikmina počítá do kapacity nádrže jako půl kostky.

### 2.2 Editor

#### 2.2.1 Ovládací panel

**Nastavení scény** — Velikost levelu se definuje rozměrem v kostkách (délka, šířka, výška). Výška určuje maximální počet úrovní a maximální vzletovou výšku robota Da. Maximální rozměry nejsou omezené (velké levely jsou ale těžko smysluplně navrhnutelné). Rozměry lze měnit i během editace — rozšíření tažením za okraj, zúžení s potvrzením smazání zasažených objektů.

**Umístění objektů** — Objekty se umisťují striktně do krychlové mřížky, standardně vedle existujícího objektu. Přesun objektu: označení + tažení myší, nebo editace souřadnic přímo. Objekty (kromě zdí a šikmin) nelze umístit volně do vzduchu — vždy se kontroluje pevný podklad pod nimi. Na šikminu nelze umístit nic.

**Nastavení objektu** — Každý objekt má vlastní nastavitelné vlastnosti. Hra je založená na grafické rozmanitosti — každému objektu (kromě robotů, kteří jsou vždy stejní) se přiřazuje model z dostupné knihovny. Každý objekt lze natočit do jednoho z šesti směrů, se zachováním smysluplnosti (např. šikminu nelze umístit svisle). Elektrické skříně a řídicí jednotky lze ovládat jen z jednoho směru — dostat se k nim ze správného směru může být samostatná hádanka. Elektrické skříně lze nastavit jako defaultně funkční/nefunkční (vyžadující opravu). Řídicí jednotky lze nastavit jako tlačítko nebo přepínač.

**Transportní plošiny** — Skládají se ze série zdí. Definuje se, které objekty jsou součástí plošiny (nemusí být fyzicky u sebe) a mezi kterými dvěma polohami se pohybuje. Plošina musí být napojená alespoň na jednu elektrickou skříň a má definovaný hmotnostní limit pro uvedení do pohybu. Napojením na ovládací zařízení se stává manuální. Editor musí kontrolovat, že dráha plošiny neprochází skrz jiné statické objekty, i při plném vytížení.

**Nádrže a čerpadla** — Tvar a kapacita nádrže se odvozuje ze sestavy zdí, které ji ohraničují (nádrž nelze umístit volně). Lze nastavit kapacitu jako neomezenou (hladina se pak nikdy nemění a nelze z ní čerpat). Čerpadlo se definuje označením dvou nádrží (vzdálenost neomezená, model nepovinný), napojuje se na elektrickou skříň a případně řídicí jednotku; definuje se defaultní zdrojová/cílová nádrž, resp. defaultní směr u obousměrného čerpadla.

**Umístění robotů** — Do levelu lze umístit 1 až 7 robotů dle výběru, včetně pozice a směru. Umístění je možné pouze na zem nebo plochou zeď; Dul může být umístěn i ve vodě.

---

## Otevřené otázky / TODO

Seznam částí, které dokument v aktuální podobě neřeší a je třeba je doplnit průběžně s vývojem:

- [ ] Dokončit popis kroku (pohybu) robota Dula po souši/vodě.
- [ ] Zahájení levelu — co přesně se děje při startu (kamera, intro).
- [ ] Scéna výběru/přepínání aktivního robota (UI, sekvence).
- [ ] Menu, UI během hraní (indikátory hmotnosti, inventáře, palivo...).
- [ ] Podmínky prohry / restart levelu (existuje vůbec stav "prohry", nebo jen postup?).
- [ ] Počet a struktura levelů, progrese, ukládání postupu.
- [ ] Art styl, kamera (izometrie? volná 3D kamera?), zvuk.
- [ ] Přesná definice "klíče" a cíle — vizuál, umístění, více klíčů na scéně?
- [ ] Definice sad materiálů zničitelných ohněm nad rámec dřeva a ledu.
- [ ] Formát ukládání levelů (pro editor i runtime) — souborový formát, verzování.
