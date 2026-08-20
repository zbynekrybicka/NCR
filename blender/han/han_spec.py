# -*- coding: utf-8 -*-
"""
Han — zemní robot (hnědá). Rozměry a attachment pointy.

Tohle je jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud
berou všechna čísla, samy žádnou konstantu nedefinují — když se tady změní
výška trupu, přesune se s ním rameno, korba i jádro.

Zdroj: `docs/robots-blender-spec.md` §0 a §1.

Všechny rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu (k čelu robota)      up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

Obálka buňky (kontrola, ať model nevyleze z [-0.5, 0.5]^3):
    fwd    -0.480 (záď korby)   ..  +0.481 (loket ramene v parkovací póze)
    right  -0.345               ..  +0.345 (vnější hrana blatníku)
    up      0.000 (podlaha)     ..   0.820 (temeno jádra)
Póza POSE_DIG je výjimka — rameno záměrně přesahuje do sousední buňky,
což spec §0 (hlavička) vizuálně povoluje; kolizně robot pořád sedí v jedné.
"""

from math import cos, sin, radians

ROBOT = "han"

# ---------------------------------------------------------------------------
# Podvozek — pásy (spec §1: "kola nebo pásy, nízko posazený, šířka ~0.7u")
# ---------------------------------------------------------------------------

TRACK_LEN = 0.70          # celková délka pásu (fwd)
TRACK_HEIGHT = 0.22       # výška pásu = 2x poloměr vodicího kola
TRACK_WIDTH = 0.15        # šířka jednoho pásu
TRACK_RIGHT = 0.275       # |right| osy pásu -> vnější hrana 0.350 = šířka 0.70
BELT_THICK = 0.028        # tloušťka pásu; uvnitř zbyde díra, kterou jsou vidět kola

GROUSER_H = 0.010         # výška ostruhy; ostruhy tvoří vnějšek pásu
GROUSER_COUNT = 11        # ostruhy na rovných úsecích pásu
GROUSER_FWD = 0.044       # rozteč ostruh
GROUSER_LEN = 0.016       # rozměr ostruhy dopředu

TRACK_R = TRACK_HEIGHT * 0.5                  # 0.110 osa kol nad podlahou
BELT_OUTER_R = TRACK_R - GROUSER_H            # 0.100 poloměr pláště pásu
BELT_INNER_R = BELT_OUTER_R - BELT_THICK      # 0.072 vnitřní světlost
DRIVE_FWD = (TRACK_LEN - TRACK_HEIGHT) * 0.5  # 0.240 osy hnacího a vodicího kola

DRIVE_R = 0.068           # hnací řetězka (vzadu) i napínací kolo (vpředu)
DRIVE_TEETH = 9
ROAD_R = 0.048            # pojezdová kola
ROAD_FWD = (-0.15, -0.05, 0.05, 0.15)
ROAD_UP = TRACK_R - BELT_INNER_R + ROAD_R     # 0.086 osa pojezdových kol

# ---------------------------------------------------------------------------
# Rám a blatníky
# ---------------------------------------------------------------------------

FRAME_RIGHT = 0.205       # rám prochází mezi pásy
FRAME_FWD = 0.300
FRAME_UP = (0.060, 0.200)  # (spodek, vršek) — 0.06 světlá výška

FENDER_RIGHT = 0.345      # kryje pásy shora
FENDER_FWD = 0.320
FENDER_UP = (0.220, 0.260)

# ---------------------------------------------------------------------------
# Trup
# ---------------------------------------------------------------------------

HULL_RIGHT = 0.240
HULL_FWD = (-0.160, 0.280)   # (záď, čelo)
HULL_UP = (0.260, 0.460)
HULL_NOSE_CHAMFER = 0.070    # zkosení čelní horní hrany

EXHAUST_AT = (0.190, -0.095)  # (right, fwd) výfuk na zádi trupu, před korbou
EXHAUST_R = 0.018
EXHAUST_TOP = 0.600

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 — sdílený asset, průměr 0.3u, na vrcholu těla mezi
# ramenem a korbou)
# ---------------------------------------------------------------------------

CORE_FWD = 0.040
CORE_UP = 0.670           # střed koule -> temeno 0.820
NECK_R = 0.062
NECK_UP = (0.440, 0.530)

CORE_RIVETS = 14          # spec dovoluje 12-16
CORE_NAME_PITCH = 38.0    # sklon nápisu na horní polokouli od vodorovné roviny

# ---------------------------------------------------------------------------
# Rameno (spec §1: kloubové, 2-3 segmenty, dosah ahead / ahead_below /
# ahead_diagonal_below)
# ---------------------------------------------------------------------------

ARM_ROOT = (0.245, 0.420)     # (fwd, up) — ramenní kloub sedí na zkosené přídi
ARM_YOKE_RIGHT = 0.090        # rozteč vidlice ramenního kloubu

# (jméno, délka). Třetí článek už není rameno, ale osa lžíce: vede z
# zápěstí k břitu a díl 05 podle něj lžíci natočí.
ARM_SEGMENTS = (("Boom", 0.280), ("Stick", 0.240), ("Link", 0.100))

# Relativní úhly kloubů ve stupních (kladné = nahoru), skládají se za sebou.
POSE_PARKED = (70.0, -140.0, -100.0)   # složené k tělu, jízdní póza
POSE_DIG = (-10.0, -35.0, -50.0)       # hrábnutí do buňky vepředu-dole
POSE_CARRY = (78.0, -133.0, -113.0)    # lžíce plná, zvednutá nad korbu

# POSE_DIG záměrně přesahuje do sousední buňky — proto ji `build_han.py`
# ohlásí jako překročení obálky. Pro export do hry se používá POSE_PARKED.

POSE = POSE_PARKED                    # výchozí póza modelu

BOOM_SIZE = (0.070, 0.075)            # (šířka, tloušťka) hranolu
STICK_SIZE = (0.055, 0.060)
PIN_R = 0.026                         # čepy kloubů


def arm_chain(pose=None):
    """Dopředná kinematika ramene.

    Vrací seznam dictů se souřadnicemi v návrhovém rámci (fwd, up):
        name, root, tip, length, angle (absolutní, ve stupních)
    """
    pose = pose if pose is not None else POSE
    fwd, up = ARM_ROOT
    angle = 0.0
    out = []
    for (name, length), rel in zip(ARM_SEGMENTS, pose):
        angle += rel
        tip = (fwd + length * cos(radians(angle)),
               up + length * sin(radians(angle)))
        out.append(dict(name=name, root=(fwd, up), tip=tip,
                        length=length, angle=angle))
        fwd, up = tip
    return out


# ---------------------------------------------------------------------------
# Lžíce (spec §1: hrabací, otevřená nahoru, use-wear na hraně)
# ---------------------------------------------------------------------------

# Lžíce se staví v LOKÁLNÍM rámu, kde počátek je zápěstní čep, +Z míří podél
# třetího článku řetězu a +X napříč robotem. Díl 05 ji pak jedním pohybem
# natočí do pózy — díky tomu je origin lžíce přesně v čepu.
BUCKET_WIDTH = 0.260
BUCKET_R = 0.078            # vnější poloměr korýtka
BUCKET_WALL = 0.012
BUCKET_CENTER = (0.078, 0.040)   # střed oblouku v lokálních (y, z)
BUCKET_GAP_DIR = -20.0      # kam kouká ústí (0 = pryč od čepu, +Z nahoru)
BUCKET_GAP = 130.0          # úhel ústí — zbytek oblouku je materiál
BUCKET_TEETH = 5
BUCKET_TOOTH_LEN = 0.042
BUCKET_TOOTH_W = 0.026
BUCKET_LUG_RIGHT = 0.055    # rozteč ok, kterými lžíce visí na zápěstí

# ---------------------------------------------------------------------------
# Korba (spec §1: na zádech, orientace dozadu, sklopná, čep vzadu dole,
# stav prázdná/plná čitelný zvenku)
# ---------------------------------------------------------------------------

HOPPER_RIGHT = 0.240
HOPPER_FWD = (-0.480, -0.160)   # (záď, čelo)
HOPPER_UP = (0.320, 0.545)      # dno výš, aby se pod něj vešel zvedací píst
HOPPER_WALL = 0.018
HOPPER_PIVOT = (-0.480, 0.320)  # (fwd, up) — čep vzadu dole
HOPPER_TIP_ANGLE = 0.0          # nastav např. -55 a korba se vyklopí dozadu

# Průhledy do korby: (fwd středu, výška středu), rozměr (fwd, up)
HOPPER_WINDOWS = ((-0.410, 0.410), (-0.290, 0.410))
HOPPER_WINDOW_SIZE = (0.090, 0.130)

# Hydraulický píst korby: z trupu na dno korby
RAM_FROM = (-0.140, 0.300)      # (fwd, up) v zádi trupu
RAM_TO = (-0.330, 0.296)        # (fwd, up) zespodu na dno korby
RAM_R = 0.020

LOAD_SIZE = (0.190, 0.140, 0.075)   # hromada hlíny (right, fwd, up)
LOAD_AT = (-0.320, 0.430)           # (fwd, up) střed hromady
BUILD_LOAD = True                   # postavit i variantu "korba plná"
