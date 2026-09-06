import sys; sys.path.insert(0, ".")
import math
import numpy as np
from PIL import Image
from tool.snes_tiles import WATER_PAL

def make_river_straight(horizontal=True):
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    for y in range(16):
        for x in range(16):
            dist = abs(y - 7.5) if horizontal else abs(x - 7.5)
            if dist <= 2.0:
                ch = 'w'
            elif dist <= 3.0:
                ch = 'm'
            elif dist <= 4.2:
                ch = 'l'
            elif dist <= 5.2:
                ch = 'K'
            elif dist <= 6.2:
                ch = 'B'
            else:
                ch = '.'
            tile[y, x] = WATER_PAL[ch]
    return tile

def make_river_corner(center_x, center_y):
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    R = 8.5
    for y in range(16):
        for x in range(16):
            dist = abs(math.hypot(x - center_x, y - center_y) - R)
            if dist <= 2.0:
                ch = 'w'
            elif dist <= 3.0:
                ch = 'm'
            elif dist <= 4.2:
                ch = 'l'
            elif dist <= 5.2:
                ch = 'K'
            elif dist <= 6.2:
                ch = 'B'
            else:
                ch = '.'
            tile[y, x] = WATER_PAL[ch]
    return tile

# 4 Corner bends:
# ES: connects East (x=15) to South (y=15) -> center is at (15.5, 15.5) or (16, 16)
tile_es = make_river_corner(15.5, 15.5)
# WS: connects West (x=0) to South (y=15) -> center is at (-0.5, 15.5)
tile_ws = make_river_corner(-0.5, 15.5)
# EN: connects East (x=15) to North (y=0) -> center is at (15.5, -0.5)
tile_en = make_river_corner(15.5, -0.5)
# WN: connects West (x=0) to North (y=0) -> center is at (-0.5, -0.5)
tile_wn = make_river_corner(-0.5, -0.5)

tile_h = make_river_straight(horizontal=True)
tile_v = make_river_straight(horizontal=False)

# Test an S-curve:
# [H, ES]
# [WN, H]
# Row 0: H, ES
# Row 1: (empty), (empty) -- wait:
# If coming from West on row 0: [tile_h, tile_es]
# Then going down to row 1: [tile_wn, tile_h] (from South to East) -> wait, entered from North, going East is tile_wn!
scurve = np.zeros((32, 48, 3), dtype=np.uint8)
scurve[0:16, 0:16] = tile_h
scurve[0:16, 16:32] = tile_es
scurve[16:32, 16:32] = tile_wn
scurve[16:32, 32:48] = tile_h

Image.fromarray(scurve).save('tool/test_scurve.png')
print("Saved tool/test_scurve.png successfully!")
