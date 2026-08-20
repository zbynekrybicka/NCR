# -*- coding: utf-8 -*-
"""
Yeo — ledový robot (bílá). Rozměry a attachment pointy.

Jediné místo, kde se ladí proporce. Díly (`part_*.py`) si odsud berou
všechna čísla a samy žádnou konstantu nedefinují.

Zdroj: `docs/robots-blender-spec.md` §0 a §6.

Rozměry jsou v návrhovém rámci `ncr_common.p(fwd, right, up)`:
    fwd   dopředu                      up  výška nad podlahou buňky
    right doprava                      1.0 = velikost jedné buňky mřížky

Vůdčí myšlenky tvaru (spec §6):

1. **"chladicí hlavice — dominantní prvek siluety"** — velký žebrovaný
   chladič sedí nahoře jako hlava a je nejvýraznější věc na robotovi.
   Všechno ostatní se mu podřizuje.
2. **"po ledu chodí normálně — podvozek potřebuje grip"** — a spec k tomu
   výslovně chce **kontrast vůči Dulovu hladkému podvozku**. Yeo má proto
   hrubá kola s hroty: co je u Dula zatažené a obtékané, je tady vystrčené
   a zubaté.
3. **"jádro umístit tak, aby nekolidovalo s chladičem — např. níž na
   hrudi"** — jádro je zapuštěné do čela trupu a vyklenuje se dopředu.
   Vršek patří chladiči.
"""

ROBOT = "yeo"

# ---------------------------------------------------------------------------
# Podvozek (spec §6: "terénní kola nebo hroty — kontrast vůči Dulovi")
# ---------------------------------------------------------------------------

WHEEL_R = 0.118           # osa v up = WHEEL_R, kolo se dotýká podlahy buňky
SPIKE_H = 0.024           # hroty tvoří vnějšek kola, plášť je o tolik menší
TYRE_R = WHEEL_R - SPIKE_H
WHEEL_WIDTH = 0.104
WHEEL_RIGHT = 0.272
WHEEL_FWD = (0.235, -0.235)
SPIKES = 10               # hroty v jedné řadě
SPIKE_ROWS = (-0.026, 0.026)   # dvě řady vedle sebe napříč běhounem
HUB_R = 0.046

FRAME_RIGHT = 0.200
FRAME_FWD = 0.285
FRAME_UP = (0.075, 0.200)

FENDER_RIGHT = 0.340
FENDER_FWD = 0.310
FENDER_UP = (0.228, 0.266)

# ---------------------------------------------------------------------------
# Trup
# ---------------------------------------------------------------------------

HULL_RIGHT = 0.200
HULL_FWD = (-0.290, 0.295)
HULL_UP = (0.266, 0.545)

# ---------------------------------------------------------------------------
# Jádro (spec §0.1 + §6: "níž na hrudi místo na vrcholu")
# ---------------------------------------------------------------------------
#
# Střed koule leží UVNITŘ trupu, takže se z čela vyklenuje jen její přední
# část — hrudní koule. Vršek zůstává volný pro chladič.

CORE_FWD = 0.243          # jen 0.052 za čelem trupu, ať se koule pořádně vyklene
CORE_UP = 0.405
CORE_RIVETS = 14
CORE_NAME_PITCH = 12.0    # nápis skoro vodorovně — koule kouká dopředu, ne nahoru

FAIRING_R = 0.158         # límec na čelní stěně kolem koule
FAIRING_LEN = 0.024

# ---------------------------------------------------------------------------
# Chladicí hlavice (spec §6: "velký žebrovaný chladič, dominantní prvek")
# ---------------------------------------------------------------------------

RAD_FWD = 0.000           # střed chladiče
RAD_RIGHT = 0.200         # poloviční šířka
RAD_DEPTH = 0.100         # poloviční hloubka
RAD_UP = (0.545, 0.862)   # (spodek, vršek) celé hlavice — vyšší i širší
                          # než trup, aby byla podle spec dominantní

FIN_COUNT = 11
FIN_THICK = 0.014
FIN_INSET = 0.008         # žebra jsou o kousek užší než obrys hlavice

PLATE_H = 0.020           # krycí desky nahoře a dole
POST_SIZE = 0.026         # rohové sloupky. Plné boční nosníky by stoh žeber
                          # z boku zakryly a hlavice by z profilu byla hladká
                          # deska — přesně to, čím dominantní prvek siluety není.

NECK_R = 0.070            # krk mezi trupem a hlavicí
NECK_UP = (0.505, 0.557)

# --- jinovatka (spec §6: "led usazený na žebrech chladiče") ----------------
FROST_PER_FIN = 4         # kusů ledu na žebro
FROST_SIZE = (0.034, 0.026, 0.016)
FROST_SEED = 7            # ať je rozmístění náhodné, ale opakovatelné


def fin_heights():
    """Výšky středů jednotlivých žeber chladiče."""
    lo = RAD_UP[0] + PLATE_H
    hi = RAD_UP[1] - PLATE_H
    if FIN_COUNT < 2:
        return [(lo + hi) * 0.5]
    step = (hi - lo - FIN_THICK) / (FIN_COUNT - 1)
    return [lo + FIN_THICK * 0.5 + step * i for i in range(FIN_COUNT)]
