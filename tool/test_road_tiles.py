import sys; sys.path.insert(0, ".")
import numpy as np
from PIL import Image
from tool.snes_tiles import GRASS_PAL, WATER_PAL

# Road Palette (Warm Cobblestone / Packed Earth)
# 'C' light cobble (205, 185, 150)
# 'c' mid cobble (175, 155, 120)
# 'D' dark cobble (135, 115, 85)
# 'S' shadow / seam (95, 75, 55)
# '.' grass base (76, 158, 54)
# 'g' grass dark (56, 122, 38)
# 'e' dirt edge (120, 100, 70)

ROAD_PAL = {
    'C': (210, 190, 155),
    'c': (180, 160, 125),
    'D': (145, 125, 95),
    'S': (105, 85, 60),
    'e': (125, 105, 75),
    '.': (76, 158, 54),
    'L': (98, 184, 70),
    'g': (56, 122, 38),
    'd': (40, 92, 28),
}

# Bridge Palette
# 'P' plank highlight (180, 125, 75)
# 'p' plank mid (145, 90, 45)
# 'R' railing wood (95, 55, 25)
# 'w' river water deep (26, 90, 134)
# 'm' river water mid (42, 122, 170)
# 'l' river water shallow (64, 160, 204)
# 'K' bank shadow (96, 78, 48)
# 'B' bank dirt (138, 116, 76)
BRIDGE_PAL = {
    'P': (185, 130, 80),
    'p': (145, 90, 45),
    'R': (95, 55, 25),
    'w': (26, 90, 134),
    'm': (42, 122, 170),
    'l': (64, 160, 204),
    'K': (96, 78, 48),
    'B': (138, 116, 76), 'L': (98, 184, 70),
    '.': (76, 158, 54),
}

ART_ROAD_H = """
................
.L...g........L.
eeeeeeeeeeeeeeee
ScCSCcCSCcCSCcCS
cDScDScDScDScDSc
CSCcCSCcCSCcCSCc
cDScDScDScDScDSc
ScCSCcCSCcCSCcCS
cDScDScDScDScDSc
CSCcCSCcCSCcCSCc
cDScDScDScDScDSc
ScCSCcCSCcCSCcCS
eeeeeeeeeeeeeeee
....gd.d........
...L..g.........
................
"""

ART_ROAD_V = """
..eScDcScDcSe...
.LeCDcCDcCDceL..
..eScDcScDcSe...
..eCDcCDcCDce...
.geScDcScDcSeg..
.deCDcCDcCDced..
..eScDcScDcSe...
..eCDcCDcCDce...
..eScDcScDcSe...
.LeCDcCDcCDceL..
..eScDcScDcSe...
..eCDcCDcCDce...
.geScDcScDcSeg..
.deCDcCDcCDced..
..eScDcScDcSe...
..eCDcCDcCDce...
"""

# Vertical Bridge (over horizontal river)
# Water flows at rows 4..11 on left (cols 0..2) and right (cols 13..15)
# Bridge spans vertically across rows 0..15 on cols 3..12
ART_BRIDGE_V = """
...RPPPPPPPPR...
.L.RppppppppR.L.
...RPPPPPPPPR...
BBBRppppppppRBBB
KKKRPPPPPPPPRKKK
lllRppppppppRlll
mmmRPPPPPPPPRmmm
wwwRppppppppRwww
wwwRPPPPPPPPRwww
wwwRppppppppRwww
mmmRPPPPPPPPRmmm
lllRppppppppRlll
BBBRPPPPPPPPRBBB
KKKRppppppppRKKK
.L.RPPPPPPPPR.L.
...RppppppppR...
"""

# Horizontal Bridge (over vertical river)
ART_BRIDGE_H = """
..BKlmwwwmlKB...
.LBKlmwwwmlKBL..
..BKlmwwwmlKB...
RRRRRRRRRRRRRRRR
PPPPPPPPPPPPPPPP
pppppppppppppppp
PPPPPPPPPPPPPPPP
pppppppppppppppp
PPPPPPPPPPPPPPPP
pppppppppppppppp
PPPPPPPPPPPPPPPP
RRRRRRRRRRRRRRRR
..BKlmwwwmlKB...
.LBKlmwwwmlKBL..
..BKlmwwwmlKB...
..BKlmwwwmlKB...
"""

def parse_tile(art, pal):
    lines = [l.strip() for l in art.strip().split('\n') if l.strip()]
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    for y, line in enumerate(lines):
        for x, ch in enumerate(line):
            tile[y, x] = pal[ch]
    return tile

rh = parse_tile(ART_ROAD_H, ROAD_PAL)
rv = parse_tile(ART_ROAD_V, ROAD_PAL)
bv = parse_tile(ART_BRIDGE_V, BRIDGE_PAL)
bh = parse_tile(ART_BRIDGE_H, BRIDGE_PAL)

demo = np.zeros((16, 64, 3), dtype=np.uint8)
demo[0:16, 0:16] = rh
demo[0:16, 16:32] = rv
demo[0:16, 32:48] = bv
demo[0:16, 48:64] = bh

Image.fromarray(demo).save('tool/test_road_bridge_demo.png')
print("Saved tool/test_road_bridge_demo.png successfully!")
