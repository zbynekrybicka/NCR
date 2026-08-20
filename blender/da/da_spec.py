# -*- coding: utf-8 -*-
"""
Da — létající robot (azurová). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §5.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu                      up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

Vůdčí myšlenky tvaru (spec §5):

1. **X-konfigurace, 4 ramena, 8 rotorů (koaxiální páry)** — celý tvar
   určuje rozteč rotorů. Ramena míří do rohů buňky, protože po úhlopříčce
   je nejvíc místa: disk rotoru se tak vejde největší.
2. **"musí přistát pro výměnu robota"** — Da se modeluje PŘISTÁLÝ, nohy
   na podlaze buňky. Vznášení je podle `docs/import-assets.md` §2.3 věc
   idle animace, ne pozice modelu.
3. **"sbírá předmět jen shora"** — hák visí pod trupem na ose, takže se
   nabírá svisle dolů.

Poznámka k senzoru: spec §5 chce vpředu kameru/čočku kvůli čitelné
orientaci. Je to jedno oko na gimbalu, tedy zjevné zařízení — ne tvář.
Da je stroj, ne brouk (srov. zadání u Neta).
"""

from math import cos, sin, radians

ROBOT = "da"

# ---------------------------------------------------------------------------
# Rám — X-konfigurace (spec §5)
# ---------------------------------------------------------------------------

# Úhly ramen měřené od "dopředu" ke "doprava". X-konfigurace, ne kříž:
# vpředu je mezi rameny volno pro kameru a dopředný pohled.
ARM_ANGLES = (45.0, 135.0, 225.0, 315.0)
ARM_R = 0.380             # osa rotoru od středu robota
ARM_SIZE = (0.048, 0.036)  # (šířka, tloušťka) ramene
ARM_UP = 0.268            # výška os ramen

HUB_R = 0.155             # centrální trup; o něco širší než jádro, aby na něm sedělo
HUB_UP = (0.200, 0.340)
HUB_TAPER = 0.86          # zúžení trupu nahoru

# ---------------------------------------------------------------------------
# Rotory (spec §5: "2 na rameno = 8 celkem")
# ---------------------------------------------------------------------------

ROTOR_R = 0.165           # dosah 0.269 + 0.165 = 0.434 od středu -> vejde se
ROTOR_UP = (0.208, 0.352)  # (dolní, horní) rovina koaxiálního páru
ROTOR_BLADES = 3
ROTOR_OFFSET = 60.0       # natočení dolního rotoru vůči hornímu

BLADE_CHORD = 0.040
BLADE_THICK = 0.007
BLADE_PITCH = 14.0        # úhel náběhu
HUB_CAP_R = 0.030

MOTOR_R = 0.044           # gondola mezi oběma rotory
MOTOR_UP = (0.196, 0.364)

# Roztočení (klip `rotors`, `anim_rotors.py`). Klip je jedna celá otáčka,
# takže se dá zacyklit bez ohledu na počet listů.
ROTOR_SPIN_FRAMES = 12    # 30 fps -> 0.4 s na otáčku, tedy 150 ot/min
ROTOR_SPIN_STEPS = 6      # klíčů na otáčku; víc než 180° mezi klíči glTF
                          # neumí zapsat (kvaternion jde vždycky nejkratší
                          # cestou), takže tohle číslo nesmí klesnout pod 3

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 + §5: "na vrcholu centrálního trupu")
# ---------------------------------------------------------------------------

CORE_FWD = 0.0
CORE_UP = 0.440           # spodek koule 0.290 je zapuštěný v trupu
CORE_RIVETS = 14
CORE_NAME_PITCH = 36.0

FAIRING_R = (0.158, 0.158)
FAIRING_UP = (0.318, 0.356)

# ---------------------------------------------------------------------------
# Přistávací nohy (spec §5: "drobné, pod trupem — funkčně nutné")
# ---------------------------------------------------------------------------

GEAR_ANGLES = ARM_ANGLES  # pod rameny, ať se síly nesou do rámu
GEAR_TOP_R = 0.100        # kde noha vychází z trupu
GEAR_FOOT_R = 0.178       # rozkročení dole
GEAR_SIZE = (0.020, 0.020)
FOOT_R = 0.034
FOOT_H = 0.014

# ---------------------------------------------------------------------------
# Hák (spec §5: "hák/gripper na spodní straně trupu, visí dolů")
# ---------------------------------------------------------------------------
#
# Visí na ose robota, takže se nabírá svisle shora, jak spec vyžaduje.
# Spodek háku je nad podlahou i po přistání.

HOOK_SHAFT_UP = (0.122, 0.204)   # (spodek, vršek) závěsné tyčky
HOOK_SHAFT_R = 0.016
HOOK_CURVE_UP = 0.088            # střed oblouku háku
HOOK_MAJOR_R = 0.044
HOOK_MINOR_R = 0.013
HOOK_GAP = 96.0                  # úhel ústí háku (kudy se předmět navlékne)

# ---------------------------------------------------------------------------
# Senzor (spec §5: "vpředu, kamera nebo čočka — čitelná orientace")
# ---------------------------------------------------------------------------

SENSOR_FWD = 0.150
SENSOR_UP = 0.252
SENSOR_PITCH = -22.0      # kouká dopředu a mírně dolů
SENSOR_BODY = (0.072, 0.062, 0.058)   # (šířka, délka, výška) gondoly
LENS_R = 0.026
LENS_LEN = 0.026


def arm_tip(angle_deg, radius=None):
    """(fwd, right) osy rotoru na daném rameni."""
    r = ARM_R if radius is None else radius
    a = radians(angle_deg)
    return (r * cos(a), r * sin(a))


def reach():
    """Největší dosah modelu od středu — kontrola, že se vejde do buňky."""
    fwd, right = arm_tip(ARM_ANGLES[0])
    return max(abs(fwd), abs(right)) + ROTOR_R
