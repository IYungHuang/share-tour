import sys; sys.path.insert(0, '.')
import numpy as np
from PIL import Image
from tool.snes_tiles import parse_tile, GRASS_PAL, SAND_PAL, FOREST_PAL, PINE_PAL, MTN_PAL, HILL_PAL, WATER_PAL

# Refined Mountain Peaks
ART_MTN_PEAK_LUSH = """
................
.......H........
......HLLD......
.....HLMMDD.....
....HLMMMMDD....
...HLMMMMMMDD...
..HLMMMMMMMMDD..
.HLMMMMMMMMMMDD.
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
MMMDDDSXXDMMMMDD
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
"""

ART_MTN_SNOW_PEAK = """
................
.......W........
......WIIJ......
.....WIIJIJ.....
....WIIIJIJJ....
...WIIIJJIJJJ...
..WIIJJJJIJJJJ..
.WHHLMMMMDDSJXX.
HLMMMMMMMMMDDXX.
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
MMMDDDSXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
"""

# Mountain Ridge (Horizontally seamless)
ART_MTN_RIDGE_SEAMLESS = """
HLMMMMMMMDDMMMDD
HLMMMMMMMDDMMMDD
LMMMMMDDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
HLMMMMMDDMMMMMDD
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
MMMDDDSXXDMMMMDD
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
"""

# Mountain Base (Scree meeting grass)
ART_MTN_BASE_SEAMLESS = """
MMMDDDSXXDMMMMDD
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
HLLMMMMDDMMMMDDX
.XDDMMDDXXDDMDX.
..XXDDX...XXDX..
...X.X.....X....
................
.L...D........L.
....DD.S........
................
...L..D......L..
.L..D.....L...D.
....D...........
................
"""

# Dense Forest Cluster (3x3 modular)
ART_FOREST_NORTH = """
................
...HHHH...HHHH..
..HLLLLH.HLLLLH.
.HLMMMMMDLMMMMMD
HLMMMMMMDMMMMMMD
LMMMMMMMDMMMMMMM
MMMMMMMMDMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
"""

ART_FOREST_CENTER = """
MMMMMMMMDMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMDMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMDMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMDMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
"""

ART_FOREST_SOUTH = """
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM
DDMMMMMDDXDDMMMD
XDMMMMDDXXSDMMDD
.XDMDDXX..XXDDX.
..XTKTKXX..XTKTX
.g.T.TKggg..T.TK
...T..K.....T..K
...T..K.....T..K
................
.L...D........L.
....DD.S........
................
...L..D......L..
.L..D.....L...D.
"""

# Standalone Forest Clump
ART_FOREST_CLUMP = """
.....HHHH.......
....HLLLLH......
...HLMMMMMD.....
..HLMMMMMMMDD...
..LMMMMMMMMMDX..
.HLLMMMMMMMDDSX.
.LMMMMMMMMMDDSX.
.DMMMMMMMMMMDSX.
.SDMMMMMMMMDDXX.
.XXDMMMMMMMDXX..
..XXDMMMMDDX....
...XXDMDDDXX....
....XTKTKXX.....
....KT.TKg......
...g.T..Kg......
....gg.ggg......
"""

# Alpine Pine Trees (2 tiered conifer trees)
ART_FOREST_PINE_DUO = """
...H.......H....
..HMD.....HMD...
.HMMMD...HMMMD..
..HMD.....HMD...
.HMMMD...HMMMD..
HMMMMMD.HMMMMMD.
..HMD.....HMD...
.HMMMD...HMMMD..
HMMMMMD.HMMMMMD.
MMMMMMMDMMMMMMMD
.XDDMDDXXDDMDDX.
..XTKTX...XTKTX.
...T.Kg....T.Kg.
................
.L...D........L.
....DD.S........
"""

# Lake 3x3 Modular Tiles
ART_LAKE_NW = """
................
.L...D........L.
....DD.S........
.......BBBBBBBBB
.....BBKKKKKKKKK
...BBKllllllllll
..BKlmmmmmmmmmmm
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
"""

ART_LAKE_N = """
................
.L...D........L.
....DD.S........
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
llllllllllllllll
mmmmmmmmmmmmmmmm
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
"""

ART_LAKE_NE = """
................
.L...D........L.
....DD.S........
BBBBBBBBB.......
KKKKKKKKKBB.....
llllllllllKBB...
mmmmmmmmmmmKlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
"""

ART_LAKE_W = """
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
"""

ART_LAKE_CENTER_DEEP = """
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
wwmwwwmwwwwmwwww
wwwwmwwwwwmwwwww
wwwwwwmwwmwwwwww
wwwwwwwmmwwwwwww
wwwFwwwwwwwFwwww
wwwFFwwwwwwFFwww
wwwwwwwwwwwwwwww
wwmwwwwwwwwwwmww
wwwwmwwwwwmwwwww
wwwwwwmwwwwmwwww
wwwFwwwwwFwwwwww
wwwFFwwwFFFwwwww
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
"""

ART_LAKE_E = """
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
"""

ART_LAKE_SW = """
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
..BKlmmmmmmmmmmm
...BBKllllllllll
.....BBKKKKKKKKK
.......BBBBBBBBB
................
.L...D........L.
....DD.S........
................
"""

ART_LAKE_S = """
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
................
.L...D........L.
....DD.S........
................
...L..D......L..
.L..D.....L...D.
"""

ART_LAKE_SE = """
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
mmmmmmmmmmmKlKB.
llllllllllKBB...
KKKKKKKKKBB.....
BBBBBBBBB.......
................
.L...D........L.
....DD.S........
................
"""

print("Compiling test tile suite...")
tiles = {
    'mtn_peak': parse_tile(ART_MTN_PEAK_LUSH, MTN_PAL),
    'mtn_snow': parse_tile(ART_MTN_SNOW_PEAK, MTN_PAL),
    'mtn_ridge': parse_tile(ART_MTN_RIDGE_SEAMLESS, MTN_PAL),
    'mtn_base': parse_tile(ART_MTN_BASE_SEAMLESS, MTN_PAL),
    'forest_n': parse_tile(ART_FOREST_NORTH, FOREST_PAL),
    'forest_c': parse_tile(ART_FOREST_CENTER, FOREST_PAL),
    'forest_s': parse_tile(ART_FOREST_SOUTH, FOREST_PAL),
    'forest_clump': parse_tile(ART_FOREST_CLUMP, FOREST_PAL),
    'forest_pine_duo': parse_tile(ART_FOREST_PINE_DUO, PINE_PAL),
    'lake_nw': parse_tile(ART_LAKE_NW, WATER_PAL),
    'lake_n': parse_tile(ART_LAKE_N, WATER_PAL),
    'lake_ne': parse_tile(ART_LAKE_NE, WATER_PAL),
    'lake_w': parse_tile(ART_LAKE_W, WATER_PAL),
    'lake_c': parse_tile(ART_LAKE_CENTER_DEEP, WATER_PAL),
    'lake_e': parse_tile(ART_LAKE_E, WATER_PAL),
    'lake_sw': parse_tile(ART_LAKE_SW, WATER_PAL),
    'lake_s': parse_tile(ART_LAKE_S, WATER_PAL),
    'lake_se': parse_tile(ART_LAKE_SE, WATER_PAL),
}

# Test render a 3x3 lake:
lake_3x3 = np.zeros((48, 48, 3), dtype=np.uint8)
lake_3x3[0:16, 0:16] = tiles['lake_nw']
lake_3x3[0:16, 16:32] = tiles['lake_n']
lake_3x3[0:16, 32:48] = tiles['lake_ne']
lake_3x3[16:32, 0:16] = tiles['lake_w']
lake_3x3[16:32, 16:32] = tiles['lake_c']
lake_3x3[16:32, 32:48] = tiles['lake_e']
lake_3x3[32:48, 0:16] = tiles['lake_sw']
lake_3x3[32:48, 16:32] = tiles['lake_s']
lake_3x3[32:48, 32:48] = tiles['lake_se']

Image.fromarray(lake_3x3).save('tool/test_lake_3x3.png')
print("Saved tool/test_lake_3x3.png successfully!")
