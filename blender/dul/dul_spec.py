# -*- coding: utf-8 -*-
"""
Dul — vodní robot (modrá). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §2.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu (k přídi)          up  výška nad podlahou buňky
    right doprava                    1.0 = velikost jedné buňky mřížky

Vůdčí myšlenka tvaru (spec §2): trup je torpédo ~0.9u dlouhé a jeho
hladkost je *funkční* — Dul po ledu klouže a plave. Všechno ostatní se
tomu podřizuje: kola jsou zapuštěná do břicha, sání je zapuštěné do přídě
a výtok je součástí zádě, ne přílepek.
"""

from math import cos, sin, radians

ROBOT = "dul"

# ---------------------------------------------------------------------------
# Trup — torpédo (spec §2: "torpédovitý/hladký, ~0.9u délka")
# ---------------------------------------------------------------------------

HULL_AXIS_UP = 0.240      # výška podélné osy nad podlahou
HULL_SEGMENTS = 28        # dělení elipsových řezů po obvodu

# Profil trupu: (fwd, poloměr doprava, poloměr nahoru, převýšení osy).
# Od přídě k zádi. Osa se ke zádi mírně zvedá, aby tryska nemířila do země.
# Čtvrtá složka je relativní k HULL_AXIS_UP — posunutím jediné konstanty se
# tedy trup usadí výš nebo níž i s koly a vším ostatním.
_HULL_PROFILE = (
    ( 0.450, 0.062, 0.058, 0.000),   # ústí sání
    ( 0.410, 0.098, 0.092, 0.000),
    ( 0.350, 0.140, 0.130, 0.000),
    ( 0.270, 0.172, 0.157, 0.000),
    ( 0.140, 0.190, 0.170, 0.000),
    (-0.020, 0.190, 0.170, 0.000),
    (-0.150, 0.182, 0.163, 0.002),
    (-0.270, 0.152, 0.137, 0.006),
    (-0.360, 0.112, 0.102, 0.010),
    (-0.430, 0.082, 0.076, 0.012),   # čelo trysky
)

HULL_SECTIONS = tuple((fwd, r_right, r_up, HULL_AXIS_UP + off)
                      for fwd, r_right, r_up, off in _HULL_PROFILE)

HULL_BOW = HULL_SECTIONS[0][0]     #  0.450
HULL_STERN = HULL_SECTIONS[-1][0]  # -0.430

# Obvodové švy pláště — vystouplé pásky, ne vyřezané drážky: na eliptickém
# trupu by drážka vyžadovala boolean s tvarem, který nemám, kdežto pásek je
# jen další tenký loft o 6 mm většího poloměru.
SEAM_FWD = (0.300, -0.170)
SEAM_LEN = 0.018
SEAM_GROW = 0.006

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 + §2: "na hřbetu, nejvyšší bod trupu")
# ---------------------------------------------------------------------------

# Jádro sedí nad rovnou částí hřbetu, kde je trup nejvyšší. Cisterna je
# za ním — hřbet je tam ještě rovný, což je pro posazení kopule podstatné.
CORE_FWD = 0.150
CORE_UP = 0.500           # střed koule; spodek 0.350 je zapuštěný v trupu
CORE_RIVETS = 14
CORE_NAME_PITCH = 34.0    # sklon nápisu na horní polokouli

FAIRING_R = (0.130, 0.110)   # (doprava, dopředu) límec, kterým jádro sedí na hřbetu
FAIRING_UP = (0.340, 0.392)

# ---------------------------------------------------------------------------
# Podvozek (spec §2: "zatažitelná/nízkoprofilová kola — nesmí rušit
# hydrodynamickou siluetu")
# ---------------------------------------------------------------------------

WHEEL_FWD = (0.220, -0.220)
WHEEL_RIGHT = 0.135
WHEEL_R = 0.072           # osa v up = WHEEL_R, kolo se dotýká podlahy buňky
WHEEL_WIDTH = 0.052
WHEEL_WELL_R = 0.092      # zápustka v břiše, aby kolo nekoukalo ze siluety
WHEEL_WELL_WIDTH = 0.060  # užší než bok trupu — zápustka nesmí prorazit plášť,
                          # jinak je do ní z boku vidět a kolo trčí ze siluety

ARM_LEN = 0.080           # kyvné rameno; zataženo = rotace kolem svého čepu
ARM_UP = 0.135            # výška čepu ramene
ARM_SIZE = (0.020, 0.030)

# ---------------------------------------------------------------------------
# Sání na přídi — Akce 1, načerpání (spec §2)
# ---------------------------------------------------------------------------

INTAKE_R = 0.046          # světlost sacího hrdla
INTAKE_DEPTH = 0.120      # jak hluboko vede do trupu
INTAKE_LIP_R = 0.064      # vnější okraj náběhového prstence
INTAKE_BARS = 3           # mříž
INTAKE_BAR_H = 0.009

# ---------------------------------------------------------------------------
# Tryska na zádi — Akce 2, vypuštění, a zároveň pohon (spec §2: "vizuálně
# stejný prvek slouží jako pohon i jako vypouštěcí ústí")
# ---------------------------------------------------------------------------

NOZZLE_FWD = (-0.492, -0.428)   # (záď, čelo) — kryt trysky
NOZZLE_R_OUT = (0.076, 0.086)   # poloměr vzadu / vpředu (kuželová tryska)
NOZZLE_R_IN = 0.058             # světlost
IMPELLER_FWD = -0.452
IMPELLER_HUB_R = 0.026
IMPELLER_BLADES = 5
IMPELLER_PITCH = 28.0           # sklon lopatky ve stupních
STATOR_VANES = 4
STATOR_FWD = -0.482

# ---------------------------------------------------------------------------
# Cisterna (spec §2: "vnitřní objem naznačený průhledem/poklopem nahoře")
# ---------------------------------------------------------------------------
#
# Řešeno jako průhled i poklop zároveň: v hřbetu je skutečný otvor, pod ním
# nádrž s otevřenou hladinou a přes otvor skleněná kopule. Silueta zůstane
# hladká a stav "plná/prázdná" je čitelný zvenku stejně jako u Hanovy korby.

# Kopule je zapuštěná do pláště (TANK_SINK), takže nikde nevzniká plovoucí
# hrana — hřbet je zakřivený a jakýkoli plochý lem by na něm buď trčel,
# nebo se propadl. Přes průhlednou kopuli je vidět hladina, což dělá stav
# "plná/prázdná" čitelný zvenku stejně jako u Hanovy korby.
TANK_FWD = (-0.180, -0.020)     # (záď, čelo) půdorysu kopule
TANK_RIGHT = 0.088              # poloviční šířka kopule
TANK_RISE = 0.050               # kolik kopule vyčnívá nad plášť
TANK_SINK = 0.035               # jak hluboko je její pata zapuštěná
TANK_RIM = 0.011                # šířka límce kolem paty

WATER_FILL = 0.55               # jak vysoko sahá hladina v kopuli (0..1)
BUILD_WATER = True              # postavit i variantu "cisterna plná"


def hull_radius(fwd):
    """Lineárně interpolovaný poloměr trupu — díly si díky tomu umí samy
    spočítat, kde přesně na plášti mají něco posadit."""
    secs = HULL_SECTIONS
    if fwd >= secs[0][0]:
        return secs[0][1], secs[0][2], secs[0][3]
    if fwd <= secs[-1][0]:
        return secs[-1][1], secs[-1][2], secs[-1][3]
    for a, b in zip(secs, secs[1:]):
        if b[0] <= fwd <= a[0]:
            t = (fwd - a[0]) / (b[0] - a[0])
            return (a[1] + (b[1] - a[1]) * t,
                    a[2] + (b[2] - a[2]) * t,
                    a[3] + (b[3] - a[3]) * t)
    return secs[-1][1], secs[-1][2], secs[-1][3]


def hull_top(fwd):
    """Výška hřbetu v daném místě."""
    _, r_up, up_center = hull_radius(fwd)
    return up_center + r_up


def hull_bottom(fwd):
    """Výška břicha v daném místě."""
    _, r_up, up_center = hull_radius(fwd)
    return up_center - r_up
