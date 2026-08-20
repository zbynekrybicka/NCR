# -*- coding: utf-8 -*-
"""
Il — elektrický robot (žlutá). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §7.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu                      up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

Vůdčí myšlenky tvaru (spec §7):

1. **"R2-D2 základ"** — soudkovitý trup, tři kola (dvě boční nohy a jedna
   přední), černé pruhy na žluté karoserii. Proporce jsou vzaté z reference:
   výška trupu zhruba rovná jeho průměru, hlava o něco užší než trup.
2. **"Jádro na vrcholu kupole/hlavy — Il je jediný, kde hlava v běžném
   smyslu splývá s pozicí jádra nejpřirozeněji"** — čteno doslova: jádro
   TU HLAVU JE. Místo kupole s koulí navrch sedí koule přímo na trupu
   a límec kolem ní hraje roli krčního prstence. U žádného jiného robota
   to takhle nevychází.
3. **"Rameno 1 pájecí, Rameno 2 USB — výsuvná"** — dvě různé ruce, každá
   na svou práci: opravu skříně a ovládání panelu. Obě jsou dvoudílné
   (pouzdro + vysunutá tyč), takže se dají zasunout posunem.
"""

ROBOT = "il"

# ---------------------------------------------------------------------------
# Trup (spec §7: "soudkovitý/válcový, R2-D2 proporce")
# ---------------------------------------------------------------------------

BODY_R = 0.178
BODY_UP = (0.185, 0.530)
BODY_SEGMENTS = 40

RIM_GROW = 0.008          # obruby nahoře a dole
RIM_H = 0.022

# ---------------------------------------------------------------------------
# Jádro = hlava (spec §0.1 + §7)
# ---------------------------------------------------------------------------

CORE_FWD = 0.0
CORE_UP = 0.600           # spodek koule 0.450 je zapuštěný v trupu
CORE_RIVETS = 14
CORE_NAME_PITCH = 26.0

COLLAR_R = 0.152          # krční prstenec, na kterém hlava sedí
COLLAR_UP = (0.512, 0.548)

# ---------------------------------------------------------------------------
# Podvozek (spec §7: "kola (2-3, jako u referenčního droida)")
# ---------------------------------------------------------------------------

SIDE_SHOULDER = (0.0, 0.168, 0.428)   # (fwd, right, up) uchycení boční nohy
SIDE_FOOT = (0.0, 0.248, 0.086)       # (fwd, right, up) osa bočního kola
SIDE_LEG_SIZE = (0.058, 0.098)        # (tloušťka napříč, hloubka)
SIDE_WHEEL_R = 0.086
SIDE_WHEEL_WIDTH = 0.062

CENTER_SHOULDER = (0.128, 0.0, 0.296)
CENTER_FOOT = (0.206, 0.0, 0.062)
CENTER_LEG_SIZE = (0.048, 0.072)
CENTER_WHEEL_R = 0.062
CENTER_WHEEL_WIDTH = 0.050

# ---------------------------------------------------------------------------
# Ramena (spec §7: "výsuvné, pájecí špička" a "výsuvné, USB konektor")
# ---------------------------------------------------------------------------
#
# Obě se staví v lokálním rámu, kde počátek je ústí pouzdra a +Z míří ven.
# Vysunutí je pak posun podél lokálního Z, zasunutí totéž se záporným
# znaménkem — proto je origin právě tam.

ARM_RIGHT = 0.078         # rozteč obou ramen od osy
ARM_HOUSING = (0.076, 0.034, 0.064)   # (šířka, výška, hloubka pouzdra)

SOLDER_UP = 0.418
SOLDER_LEN = 0.148
SOLDER_R = 0.015
SOLDER_TIP = (0.013, 0.003)   # (u tyče, na špičce) — tenký, přesný nástroj

USB_UP = 0.318
USB_LEN = 0.132
USB_R = 0.015
USB_PLUG = (0.030, 0.012, 0.026)   # (šířka, tloušťka, délka) konektoru

EXTEND = 1.0              # 0.0 = zasunuto do pouzdra, 1.0 = plně vysunuto

# ---------------------------------------------------------------------------
# Černé pruhy (spec §7: "černé akcenty na žluté karoserii")
# ---------------------------------------------------------------------------

STRIPE_RINGS = ((0.496, 0.024), (0.232, 0.020))   # (výška středu, výška pruhu)
STRIPE_GROW = 0.005

PANEL_ANGLES = (45.0, 135.0, 225.0, 315.0)   # mimo čelo, kde jsou ramena
PANEL_SIZE = (0.062, 0.014, 0.215)           # (šířka, výstupek, výška)
PANEL_UP = 0.364


def body_face(right, radius=None):
    """Jak daleko vpředu je plášť trupu v dané vzdálenosti od osy —
    aby pouzdra ramen dosedla na válec a ne do vzduchu."""
    r = BODY_R if radius is None else radius
    return (max(0.0, r * r - right * right)) ** 0.5
