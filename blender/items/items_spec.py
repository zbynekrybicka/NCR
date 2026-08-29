# -*- coding: utf-8 -*-
"""
Klíč, kanystr (FUEL), service kit (SERVICE_KIT) — rozměry.

Stejný princip jako `<robot>_spec.py` / `devices_spec.py`: všechna čísla na
jednom místě, díly (`part_*.py`) žádnou konstantu nedefinují samy.

Rozměry v návrhovém rámci `ncr_common.p(fwd, right, up)` (`fwd` dopředu,
`right` doprava, `up` výška nad podlahou buňky, 0 = podlaha, 1 = strop).
Předměty ale na rozdíl od robotů/zařízení na podlaze nestojí — vznáší se
u `CENTER_UP` (střed buňky po výšce = `Blender z = 0`, přesně tam, kam je
dnes staví placeholder v `world_view.gd:refresh_items()`). `CENTER_UP` proto
zároveň sedí přesně na počátku Blenderu (`right = 0` i `fwd = 0` taky), což
je pohodlné: je to zároveň pivot, kolem kterého bude `ItemView` model ve hře
otáčet a pohupovat nahoru/dolů (§4.2 import-assets — otáčení a pohupování
dělá kód, model nese jen klidovou pózu).
"""

CENTER_UP = 0.500

# ---------------------------------------------------------------------------
# Klíč — mosazný, do klasického dózického zámku (oválná hlava s dírou, dřík,
# plochá čepel se zuby). Zadání: nakloněný 45° od vodorovné polohy — natáčí
# se root Empty kolem osy `fwd` (Blender Y), ať čepel se zuby i hlava zůstanou
# ploché a jen se celé natočí v rovině right/up.
# ---------------------------------------------------------------------------

KEY_TILT_DEG = 45.0

KEY_BOW_CENTER_RIGHT = -0.095
KEY_BOW_OUTER_R = 0.048
KEY_BOW_INNER_R = 0.026
KEY_BOW_THICK = 0.016

KEY_SHANK_R = 0.010
KEY_SHANK_RIGHT = (-0.062, 0.045)   # (u hlavy, u límce)

KEY_COLLAR_RIGHT = 0.045
KEY_COLLAR_R = 0.019
KEY_COLLAR_THICK = 0.012

KEY_BLADE_RIGHT = (0.045, 0.150)
KEY_BLADE_UP = (CENTER_UP - 0.018, CENTER_UP + 0.018)
KEY_BLADE_THICK = 0.012

# Zuby — zářezy od SPODNÍ hrany čepele (KEY_BLADE_UP[0]) nahoru, různá hloubka
# ať je siluetou čitelně "klíč", ne hřeben se stejnými zuby.
KEY_TEETH_RIGHT = (0.065, 0.088, 0.111, 0.134)
KEY_TEETH_DEPTH = (0.010, 0.020, 0.012, 0.024)
KEY_TEETH_WIDTH = 0.016

# ---------------------------------------------------------------------------
# Kanystr — vojenský na palivo (ItemType.FUEL), stojí rovně (svislá osa =
# `up`, žádný náklon jako u klíče). Tvar: NATO kanystr — lichoběžníkové tělo,
# X-výztuhy na čele/zádi, trojice madel nahoře, hrdlo s víčkem v rohu.
# ---------------------------------------------------------------------------

CAN_BODY_RIGHT = 0.085                 # poloviční šířka
CAN_BODY_FWD = 0.058                   # poloviční hloubka
CAN_BODY_HALF_HEIGHT = 0.115
CAN_BODY_UP = (CENTER_UP - CAN_BODY_HALF_HEIGHT, CENTER_UP + CAN_BODY_HALF_HEIGHT)
CAN_BEVEL = 0.008

CAN_NECK_RIGHT = -0.055
CAN_NECK_FWD = 0.040
CAN_NECK_R = 0.020
CAN_NECK_HEIGHT = 0.032
CAN_NECK_UP = (CAN_BODY_UP[1], CAN_BODY_UP[1] + CAN_NECK_HEIGHT)

CAN_CAP_R = 0.025
CAN_CAP_HEIGHT = 0.014

CAN_HANDLE_RIGHTS = (-0.045, 0.0, 0.045)
CAN_HANDLE_FWD = (-0.040, 0.040)       # (přední noha, zadní noha)
CAN_HANDLE_ARCH_UP = CAN_BODY_UP[1] + 0.048
CAN_HANDLE_BAR_R = 0.008

# X-výztuha na čele i zádi — dva zkřížené pruhy vyvýšené nad plášť.
CAN_BRACE_FWDS = (CAN_BODY_FWD, -CAN_BODY_FWD)
CAN_BRACE_LEN = 0.130
CAN_BRACE_THICK = 0.010
CAN_BRACE_DEPTH = 0.006
CAN_BRACE_ANGLE = 38.0

# Menší štítek se štouchancem (výrobní cejch), pod výztuhou na čele.
CAN_LABEL_RIGHT = 0.050
CAN_LABEL_UP = (CAN_BODY_UP[0] + 0.018, CAN_BODY_UP[0] + 0.044)
CAN_LABEL_DEPTH = 0.004

# ---------------------------------------------------------------------------
# Service kit — stočený drát + kleštičky + mikropájecí souprava, volně
# rozložené vedle sebe (design dok. §2.1.3 "opravářská sada").
# ---------------------------------------------------------------------------

KIT_COIL_POS = (0.105, -0.075, CENTER_UP - 0.010)   # (fwd, right, up)
KIT_COIL_ROT = (50.0, 10.0, 25.0)
KIT_COIL_R = 0.044
KIT_COIL_WIRE_R = 0.0075
KIT_COIL_PITCH = 0.026
KIT_COIL_TURNS = 4.5

KIT_PLIER_POS = (-0.045, 0.055, CENTER_UP + 0.006)
KIT_PLIER_ROT_DEG = (8.0, 0.0, 15.0)     # náklon celé sestavy kleští v bundlu
KIT_PLIER_JAW_LEN = 0.036
KIT_PLIER_HANDLE_LEN = 0.098
KIT_PLIER_ARM_WIDTH = 0.015
KIT_PLIER_ARM_THICK = 0.009
KIT_PLIER_CROSS_ANGLE = 16.0             # úhel mezi rameny kolem pivotu
KIT_PLIER_PIVOT_R = 0.013
KIT_PLIER_PIVOT_THICK = 0.011

KIT_IRON_POS = (-0.085, -0.020, CENTER_UP + 0.012)
KIT_IRON_ROT_DEG = (0.0, 24.0, 55.0)
KIT_IRON_GRIP_R = 0.015
KIT_IRON_GRIP_LEN = 0.072
KIT_IRON_SHAFT_R = 0.0065
KIT_IRON_SHAFT_LEN = 0.048
KIT_IRON_TIP_R1 = 0.0065
KIT_IRON_TIP_R2 = 0.0012
KIT_IRON_TIP_LEN = 0.018
