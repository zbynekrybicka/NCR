# -*- coding: utf-8 -*-
"""
Šikmina (RAMP) — rozměry a texturování.

Jediné místo, kde se ladí čísla (stejný princip jako `<robot>_spec.py` a
`devices_spec.py`). Tvar sám (bokorys pravoúhlého trojúhelníku vyplňující
celou buňku, design dok. §2.1.4) žádné volné rozměry nemá — je to vždycky
přesně `[-0.5, 0.5]` na `fwd`/`right` a `[0, 1]` na `up`, viz
`common.ramp_wedge()`. Ladit jde jen textura a materiálové vlastnosti.
"""

# Ocelová textura sdílená s blokem WALL (§ zadání: "texturu mu dej ocelovou
# jako u zdí") — stejný soubor, který ve hře čte
# `WorldView.BLOCK_TEXTURES[GridTypes.BlockType.WALL]`.
RAMP_TEXTURE_FILE = "zed_ocel.jpg"

# Nízký metallic / vyšší roughness — texturový vzorek (viz
# docs/zadani_textury_kostky_urovne_dalle.md) už nese namalované nýty a
# oděr, vysoký metallic/lesk by ho pod Cycles/Godot osvětlením vymyl do
# ploché zrcadlové plochy.
RAMP_METALLIC = 0.10
RAMP_ROUGHNESS = 0.60

# 1.0 = jedna dlaždice textury na jednu jednotku buňky, stejná hustota jako
# výchozí UV krychle `BoxMesh` u bloku WALL (§3.5 import-assets — šikmina i
# zeď mají vypadat jako stejná rodina materiálu).
RAMP_UV_SCALE = 1.0
