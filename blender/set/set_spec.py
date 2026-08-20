# -*- coding: utf-8 -*-
"""
Set — ohnivý robot (červená). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §3.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu (k čelu)             up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

Vůdčí myšlenky tvaru (spec §3):

1. **"statická pozice při palbě"** — podvozek je robustnější než Hanův:
   šest velkých kol, široký rozchod, těžký rám nízko u země a čelní deska.
   Silueta má působit zapřeně, ne hbitě.
2. **"hlavice jako hlavní silueta-definující prvek"** — proto otočná věž
   a na ní dlouhá hlaveň s ústím. Věž je to první, co na robotovi uvidíš.
3. Spec chce dosah **vodorovně / šikmo / svisle** pro dřevo a **šikmo dolů**
   pro led, takže hlaveň potřebuje náměr zhruba od -45 do +90 stupňů.
   Věž se otáčí kolem Z, hlaveň se sklápí kolem X — dva klouby.
"""

ROBOT = "set"

# ---------------------------------------------------------------------------
# Podvozek (spec §3: "kola, robustnější než Han")
# ---------------------------------------------------------------------------

WHEEL_R = 0.112           # osa v up = WHEEL_R, kolo se dotýká podlahy buňky
WHEEL_WIDTH = 0.098
WHEEL_RIGHT = 0.272       # vnější hrana 0.321 -> rozchod 0.64u
WHEEL_FWD = (0.250, 0.000, -0.250)
WHEEL_LUGS = 12           # terénní vzorek na běhounu
LUG_H = 0.016             # vzorek tvoří vnějšek kola: plášť má o tolik menší
                          # poloměr, jinak by kolo dosedalo na podlahu vzorkem
                          # a propadlo se pod ni
TYRE_R = WHEEL_R - LUG_H
HUB_R = 0.046

FRAME_RIGHT = 0.215       # rám prochází mezi koly
FRAME_FWD = 0.315
FRAME_UP = (0.070, 0.215)

DECK_RIGHT = 0.335        # blatník nad koly
DECK_FWD = 0.335
DECK_UP = (0.225, 0.265)

BUMPER_FWD = (0.335, 0.378)   # čelní deska — část "zapřeného" dojmu
BUMPER_RIGHT = 0.300
BUMPER_UP = (0.130, 0.290)

# ---------------------------------------------------------------------------
# Trup
# ---------------------------------------------------------------------------

HULL_RIGHT = 0.230
HULL_FWD = (-0.330, 0.290)
HULL_UP = (0.265, 0.420)
HULL_NOSE_CHAMFER = 0.075

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 + §3: "na těle, mimo dráhu plamene")
# ---------------------------------------------------------------------------
#
# Vzadu na palubě, za věží a pod úrovní čepu hlavně: plamen míří od ústí
# pryč a hlaveň se sklápí nad přídí, takže jádro leží mimo. Cenou je běžné
# omezení každé skutečné věže — nad zádí se hlaveň nesklápí (viz README).

CORE_FWD = -0.220
CORE_UP = 0.480           # střed koule; spodek 0.330 je zapuštěný v palubě
CORE_RIVETS = 14
CORE_NAME_PITCH = 36.0

FAIRING_R = (0.152, 0.136)   # (doprava, dopředu) límec kolem paty jádra
FAIRING_UP = (0.390, 0.430)

# ---------------------------------------------------------------------------
# Věž (spec §3: "montovaná na rameni/rotující věži")
# ---------------------------------------------------------------------------

RING_FWD = 0.075          # osa otáčení věže
RING_R = 0.150
RING_UP = (0.420, 0.452)

TURRET_R = (0.140, 0.120)   # (dole, nahoře) — mírně kuželová
TURRET_UP = (0.452, 0.548)

TRUNNION_UP = 0.560       # čep náměru hlavně
TRUNNION_RIGHT = 0.084    # rozteč lící věže
CHEEK_UP = (0.486, 0.606)
CHEEK_FWD = (0.055, 0.200)
CHEEK_THICK = 0.032      # líce nesou čep náměru, tak ať to nejsou plechová žebra

TURRET_YAW = 0.0          # výchozí natočení věže (stupně kolem Z)

# ---------------------------------------------------------------------------
# Plamenomet (spec §3: "viditelná tryska/ústí", "vlastní nádrž na hlavici",
# "ohořelé/začouzené akcenty kolem ústí hlavně")
# ---------------------------------------------------------------------------
#
# Hlavice se staví v LOKÁLNÍM rámu, kde počátek je čep náměru a +Z míří
# podél hlavně. Díl 05 ji pak jedním pohybem natočí — origin proto sedí
# přesně v čepu a náměr je jedna rotace kolem X.

ELEVATION = 12.0          # výchozí náměr (stupně; kladné = nahoru)
ELEVATION_RANGE = (-45.0, 90.0)   # co spec vyžaduje: šikmo dolů až svisle

BARREL_LEN = 0.280
BARREL_R = 0.042
JACKET_R = 0.054          # chladicí plášť u závěru
JACKET_AT = (0.020, 0.130)   # (od, do) podél hlavně

MUZZLE_LEN = 0.052
MUZZLE_R = (0.048, 0.064)    # (u hlavně, na ústí) — rozšířené ústí
SCORCH_AT = 0.250            # prstenec sazí kus před ústím

TANK_R = 0.044               # vlastní nádrž NA HLAVICI, ne nesený kanystr
TANK_LEN = 0.130
# Odstup musí být větší než BARREL_R + TANK_R, jinak se nádrž do hlavně
# zapustí a přestane být čitelná jako nádrž.
TANK_OFFSET = (0.094, 0.082)   # (nad hlavní, podél hlavně) v lokálním rámu

PILOT_R = 0.011              # zapalovací hořáček
PILOT_UNDER = 0.072          # pod osou hlavně — vedle ústí by prostřelil trysku
PILOT_AT = (0.140, 0.302)    # (od, do) podél hlavně; končí až za ústím


def elevation_dir(elevation=None):
    """Směr hlavně ve svislé rovině robota."""
    from math import radians, cos, sin
    a = radians(ELEVATION if elevation is None else elevation)
    return (0.0, -cos(a), sin(a))


def muzzle_tip(elevation=None):
    """(fwd, up) špičky ústí — na kontrolu, že hlaveň nevyleze z buňky."""
    from math import radians, cos, sin
    a = radians(ELEVATION if elevation is None else elevation)
    reach = BARREL_LEN + MUZZLE_LEN
    return (RING_FWD + reach * cos(a), TRUNNION_UP + reach * sin(a))
