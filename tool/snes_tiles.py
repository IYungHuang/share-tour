"""
SNES 16-bit JRPG Tile Definitions and Palette Mappings
All tiles are 16x16 pixels with strictly indexed palettes.
"""
import numpy as np

# --- 16-bit SNES Color Palettes ---
OCEAN = (30, 111, 159)  # #1E6F9F Mandatory exact flat ocean color

# Universal Background Grass Colors
GRASS_BASE = (76, 158, 54)
GRASS_LIGHT = (98, 184, 70)
GRASS_DARK = (56, 122, 38)
GRASS_DEEP = (40, 92, 28)

# Grass / Plains Palette
GRASS_PAL = {
    '.': GRASS_BASE,
    'L': GRASS_LIGHT,
    'D': GRASS_DARK,
    'S': GRASS_DEEP,
    'W': (88, 166, 58),    # Warm base green
    'H': (112, 194, 76),   # Warm highlight green
    'Y': (236, 220, 94),   # Wildflower yellow
    'F': (242, 246, 232),  # Wildflower white
    'R': (224, 118, 138),  # Wildflower red/pink
    'E': (136, 112, 72),   # Earth / soil speck
}

# Sand / Coast Palette
SAND_PAL = {
    '1': (232, 214, 156),  # Sand highlight
    '2': (210, 188, 128),  # Sand base
    '3': (178, 154, 100),  # Sand shadow
    '4': (144, 122, 76),   # Sand deep
    '.': GRASS_BASE,
    'L': GRASS_LIGHT,
    'D': GRASS_DARK,
    'S': GRASS_DEEP,
}

# Forest Palette
FOREST_PAL = {
    'H': (112, 204, 76),   # Canopy bright highlight
    'L': (82, 172, 58),    # Canopy mid-highlight
    'M': (52, 136, 40),    # Canopy base green
    'D': (34, 98, 28),     # Canopy shadow green
    'S': (20, 66, 18),     # Canopy deep shadow
    'X': (12, 42, 12),     # Canopy outline / deepest notch
    'T': (132, 92, 52),    # Trunk highlight
    'K': (86, 56, 32),     # Trunk shadow
    '.': GRASS_BASE,
    'g': GRASS_DARK,
    'd': GRASS_DEEP,
}

# Pine / Conifer Palette (High Altitude)
PINE_PAL = {
    'H': (76, 164, 96),    # Pine highlight
    'M': (46, 118, 68),    # Pine mid green
    'D': (28, 82, 48),     # Pine dark green
    'S': (16, 52, 30),     # Pine deep shadow
    'X': (10, 34, 20),     # Pine outline
    'T': (112, 80, 48),    # Trunk
    'K': (70, 48, 28),     # Trunk dark
    '.': GRASS_BASE,
    'g': GRASS_DARK,
    'd': GRASS_DEEP,
    'L': GRASS_LIGHT,
    'D': GRASS_DARK,
    'S': GRASS_DEEP,
}

# Mountain Palette
MTN_PAL = {
    'W': (252, 254, 255),  # Snow white peak
    'I': (212, 230, 246),  # Snow light ice
    'J': (158, 186, 212),  # Snow shadow ice
    'H': (182, 170, 156),  # Rock NW highlight
    'L': (148, 136, 122),  # Rock mid-light
    'M': (116, 106, 94),   # Rock base
    'D': (80, 72, 64),     # Rock SE shadow
    'S': (52, 46, 40),     # Rock deep shadow
    'X': (32, 28, 24),     # Rock darkest crack
    '.': GRASS_BASE,
    'g': GRASS_DARK,
    'd': GRASS_DEEP,
}

# Hills Palette
HILL_PAL = {
    'h': (118, 182, 74),   # Hill crest highlight
    'm': (84, 146, 52),    # Hill mid green
    'k': (58, 110, 36),    # Hill shadow green
    'E': (136, 114, 76),   # Hill earth exposed
    'e': (136, 114, 76),
    'B': (96, 78, 50),     # Hill earth shadow
    'b': (96, 78, 50),
    'S': (38, 76, 24),     # Base shadow
    's': (38, 76, 24),
    '.': GRASS_BASE,
    'L': GRASS_LIGHT,
    'D': GRASS_DARK,
    'g': GRASS_DARK,
    'd': GRASS_DEEP,
}

# Water / Lake / River Palette
WATER_PAL = {
    'F': (168, 226, 252),  # Glint / foam
    'l': (64, 160, 204),   # Shallow water
    'm': (42, 122, 170),   # Mid water
    'w': (26, 90, 134),    # Deep water
    'B': (138, 116, 76),   # Bank dirt / pebble
    'K': (96, 78, 48),     # Bank shadow
    '.': GRASS_BASE,
    'L': GRASS_LIGHT,
    'D': GRASS_DARK,
    'S': GRASS_DEEP,
    'g': GRASS_DARK,
    'd': GRASS_DEEP,
}

def parse_tile(art_lines, palette):
    lines = [line.strip() for line in art_lines.strip().split('\n') if line.strip()]
    assert len(lines) == 16, f"Expected 16 lines, got {len(lines)}"
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    for y, line in enumerate(lines):
        assert len(line) == 16, f"Line {y} expected 16 chars, got {len(line)}: '{line}'"
        for x, ch in enumerate(line):
            if ch not in palette:
                raise KeyError(f"Char '{ch}' at ({x},{y}) not in palette keys: {list(palette.keys())}")
            tile[y, x] = palette[ch]
    return tile


# --- TILE BITMAPS (16x16) ---

# 1. Plain Grass
ART_GRASS_1 = """
................
.L...D........L.
....DD.S........
.L...D......L...
..........L..D..
...L..D.........
.L..D.....L...D.
....D...........
..L...D......L..
........L...DD.S
.L...D..........
....DD.S....L.D.
..........L.....
...L..D......D..
.L..D.....L...S.
....D...........
"""

# 2. Grass with Flowers
ART_GRASS_FLOWERS = """
................
.L...D....Y...L.
....DD.S.YYF....
.L...D....F.L...
..........L..D..
.R.L..D.....Y...
RRFL.D....L.YYF.
.F..D........F..
..L...D......L..
........L...DD.S
.L...D....R.....
....DD.S.RRF..D.
..........F..L..
...L..D......D..
.L..D..Y..L...S.
....D.YYF.......
"""

# 3. Warm Pastoral Plain (Western Plains)
ART_GRASS_WARM = """
WWWWWWWWWWWWWWWW
WW.H...D.WWWWW.H
WWWW.DD.SWWWWWWW
W.H...D.WWWW.HWW
WWWWWWWWWW.H..DW
WWW.H..D.WWWWWWW
W.H..D.WWWW.H..D
WWWW.D.WWWWWWWWW
WW.H...D.WWWW.HW
WWWWWWWW.H..DD.S
W.H...D.WWWWWWWW
WWWW.DD.SWWW.H.D
WWWWWWWWWW.HWWWW
WWW.H..D.WWWW.DW
W.H..D.WWWW.H..S
WWWW.D.WWWWWWWWW
"""

# 4. Coastal Sand
ART_SAND = """
1222332212223322
2212232222122322
2334432123344321
3443321234433212
2223322122233221
2122322221223222
3344321233443212
4433212344332123
1222332212223322
2212232222122322
2334432123344321
3443321234433212
2223322122233221
2122322221223222
3344321233443212
4433212344332123
"""

# 5. Forest Solo (Classic rounded clumps with trunks)
ART_FOREST_SOLO = """
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

# 6. Dense Forest Center
ART_FOREST_DENSE = """
HLLMMMMMDDHLLMMM
LMMMMMMMDDLMMMMM
MMMMMMMMDSMMMMMM
MMMMMMMMDXMMMMMM
DDMMMMMDDXDDMMMD
XDMMMMDDXXSDMMDD
.XDMDDXX..XXDDX.
HLLMMMMMDDHLLMMM
LMMMMMMMDDLMMMMM
MMMMMMMMDSMMMMMM
MMMMMMMMDXMMMMMM
DDMMMMMDDXDDMMMD
XDMMMMDDXXSDMMDD
.XDMDDXX..XXDDX.
..XTKTKXX..XTKTX
.g.T.TKggg..T.TK
"""

# 7. Alpine Conifer / Pine
ART_FOREST_PINE = """
.......H........
......HMD.......
.....HMMMD......
....HMMMMMD.....
.....HMMMD......
....HMMMMMD.....
...HMMMMMMMD....
..HMMMMMMMMMD...
....HMMMMMD.....
...HMMMMMMMD....
..HMMMMMMMMMD...
.HMMMMMMMMMMMD..
...XDDMMMDDXX...
....XXTKTKXX....
.....XTKTKX.....
....gg.T.Kggg...
"""

# 8. Rolling Hills
ART_HILLS = """
................
.....hhhhh......
...hhmmmmmd.....
..hmmmmmkkdd....
.hmmmmmmkkkdd...
.mmmmmmkkkkkd...
dmmmeeeebmmmdd..
dmeeeeeeebmmdds.
.deeeeeeebbddss.
..sbbbbbbbdss...
...ssdddddss....
.....sssss......
................
.L...D........L.
....DD.S........
................
"""

# 9. Snow-Capped High Mountain Peak (Yushan / Central Range)
ART_MTN_SNOW = """
.......WI.......
......WIJI......
.....WIIJIJ.....
....WIIIJIJJ....
...WIIIJJIJJJ...
..WIIJJJJIJJJJ..
.WHHLMMMMDDSJXX.
.HLLMMMMMMDSJXX.
HLMMMMMMMMMDDXX.
LMMMMMMMMMMMDDX.
MMMMMMMMMMMMMDD.
DMMMMMMMMMMMMDDX
SDMMMMMMMMMMDDXX
XSDMMMMMMMDDDXX.
.XXDDMMMMDDDXX..
..XXDDDDDDXXX...
"""

# 10. Rocky Mountain Peak
ART_MTN_ROCK = """
.......H........
......HLLD......
.....HLMMDD.....
....HLMMMDDX....
...HLMMMMMDDX...
..HLMMMMMMMDDX..
.HLMMMMMMMMMDDX.
.LMMMMMMMMMMDDX.
HLMMMMMMMMMMMDDX
LMMMMMMMMMMMMDDX
MMMMMMMMMMMMMDDX
DMMMMMMMMMMMMDDX
SDMMMMMMMMMMDDXX
XSDMMMMMMMDDDXX.
.XXDDMMMMDDDXX..
..XXDDDDDDXXX...
"""

# 11. Mountain Ridge / Body (seamless horizontal mountain range)
ART_MTN_RIDGE = """
HLMMMMMMMMMMMDDX
LMMMMMMMMMMMMDDX
HLMMMMMMMMMMMDDX
LMMMMMMMMMMMMDDX
MMMMMMMMMMMMMDDX
DMMMMMMMMMMMMDDX
MMMMMMMMMMMMMDDX
DMMMMMMMMMMMMDDX
SDMMMMMMMMMMDDXX
DMMMMMMMMMMMMDDX
MMMMMMMMMMMMMDDX
DMMMMMMMMMMMMDDX
SDMMMMMMMMMMDDXX
XSDMMMMMMMDDDXX.
.XXDDMMMMDDDXX..
..XXDDDDDDXXX...
"""

# 12. Lake Center (Calm inland water)
ART_LAKE_CENTER = """
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

# 13. Lake Shore North (Water south, grass north)
ART_LAKE_SHORE_N = """
................
.L...D........L.
....DD.S........
................
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
llllllllllllllll
mmmmmmmmmmmmmmmm
wwwwwwwwwwwwwwww
wwwwFwwwwwwwFwww
wwwwFFwwwwwwFFww
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
wwwwwwwwwwwwwwww
wwwFwwwwwwwFwwww
wwwwwwwwwwwwwwww
"""

# 14. Lake Shore South (Water north, grass south)
ART_LAKE_SHORE_S = """
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
wwwFwwwwwwwFwwww
wwwwFFwwwwwwFFww
wwwwwwwwwwwwwwww
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
................
.L...D........L.
....DD.S........
.L...D......L...
..........L..D..
...L..D.........
................
"""

# 15. Lake Shore West (Water east, grass west)
ART_LAKE_SHORE_W = """
...BKlmwwwwwwwww
.L.BKlmwwwmwwwww
...BKlmwwwwwwwww
.L.BKlmwwwwwwwww
...BKlmwwwFwwwww
...BKlmwwwFFwwww
.L.BKlmwwwwwwwww
...BKlmwwwwwwwww
...BKlmwwwwwwwww
...BKlmwwwmwwwww
.L.BKlmwwwwwwwww
...BKlmwwwwwwwww
...BKlmwwwFwwwww
...BKlmwwwFFwwww
.L.BKlmwwwwwwwww
...BKlmwwwwwwwww
"""

# 16. Lake Shore East (Water west, grass east)
ART_LAKE_SHORE_E = """
wwwwwwwwwmlKB...
wwwmwwwwwmlKB.L.
wwwwwwwwwmlKB...
wwwwwwwwwmlKB.L.
wwwwwFwwwmlKB...
wwwwFFwwwmlKB...
wwwwwwwwwmlKB.L.
wwwwwwwwwmlKB...
wwwwwwwwwmlKB...
wwwmwwwwwmlKB...
wwwwwwwwwmlKB.L.
wwwwwwwwwmlKB...
wwwwwFwwwmlKB...
wwwwFFwwwmlKB...
wwwwwwwwwmlKB.L.
wwwwwwwwwmlKB...
"""

# 17. Horizontal River
ART_RIVER_H = """
................
.L...D........L.
....DD.S........
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
llllllllllllllll
mmmmmmmmmmmmmmmm
wwwFwwwwwwwwFwww
wwwFFwwwwwwFFwww
wwwwwwwwwwwwwwww
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
.L...D........L.
....DD.S........
"""

# 18. Vertical River
ART_RIVER_V = """
..BKlmwwmwwmlKB.
.LBKlmwwmwwmlKBL
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
.DBKlmwwmwwmlKBD
.SBKlmwwmwwmlKBS
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
.LBKlmwwmwwmlKBL
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
.DBKlmwwmwwmlKBD
.SBKlmwwmwwmlKBS
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
"""

# 19. River Bend: West to South
ART_RIVER_WS = """
................
.L...D........L.
....DD.S........
BBBBBBBBBBB.....
KKKKKKKKKKKKB...
lllllllllllmlKB.
mmmmmmmmmmmmlKBL
wwwFwwwwwBKmlKB.
wwwFFwwwwBKmlKB.
wwwwwwwwwBKmlKB.
mmmmmmmmmBKmlKB.
lllllllllBKmlKBL
BBBBBBBBB..mlKB.
KKKKKKKKK..mlKB.
.L...D...DBmlKBD
....DD.S.SBmlKBS
"""

# 20. River Bend: North to East
ART_RIVER_NE = """
..BKlmwwmwwmlKB.
.LBKlmwwmwwmlKBL
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
.DBKlmwwBBBBBBBB
.SBKlmwwKKKKKKKK
..BKlmwwllllllll
..BKlmwwmmmmmmmm
..BKlmwwwwFwwwww
.LBKlmwwwwFFwwww
..BKlmwwwwwwwwww
..BKlmwwmmmmmmmm
.DBKlmwwllllllll
.SBKlmwwBBBBBBBB
..BKlmwwKKKKKKKK
..BKlmww........
"""

# 21. River Bend: East to South
ART_RIVER_ES = """
................
.L...D........L.
....DD.S........
.....BBBBBBBBBBB
...BKKKKKKKKKKKK
.BKlmlllllllllll
LBKlm mmmmmmmmmm
.BKlmBKwwFwwwwww
.BKlmBKwwFFwwwww
.BKlmBKwwwwwwwww
.BKlmBKmmmmmmmmm
LBKlmBKlllllllll
.BKlm..BBBBBBBBB
.BKlm..KKKKKKKKK
DBKlmBD..D...L..
SBKlmBS.S.DD....
"""

# 22. River Bend: North to West
ART_RIVER_NW = """
..BKlmwwmwwmlKB.
.LBKlmwwmwwmlKBL
..BKlmwwmwwmlKB.
..BKlmwwmwwmlKB.
BBBBBBBBwwmlKBD.
KKKKKKKKwwmlKBS.
llllllllwwmlKB..
mmmmmmmmwwmlKB..
wwwwwFwwwwmlKB..
wwwwFFwwwwmlKBL.
wwwwwwwwwwmlKB..
mmmmmmmmwwmlKB..
llllllllwwmlKBD.
BBBBBBBBwwmlKBS.
KKKKKKKKwwmlKB..
........wwmlKB..
"""

# 23. River Mouth West (Emptying into ocean on west)
ART_RIVER_MOUTH_W = """
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
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
.L...D........L.
....DD.S........
"""

# 24. River Mouth East (Emptying into ocean on east)
ART_RIVER_MOUTH_E = """
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
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
.L...D........L.
....DD.S........
"""

TILES = {
    'grass_1': parse_tile(ART_GRASS_1, GRASS_PAL),
    'grass_flowers': parse_tile(ART_GRASS_FLOWERS, GRASS_PAL),
    'grass_warm': parse_tile(ART_GRASS_WARM, GRASS_PAL),
    'sand': parse_tile(ART_SAND, SAND_PAL),
    'forest_solo': parse_tile(ART_FOREST_SOLO, FOREST_PAL),
    'forest_dense': parse_tile(ART_FOREST_DENSE, FOREST_PAL),
    'forest_pine': parse_tile(ART_FOREST_PINE, PINE_PAL),
    'hills': parse_tile(ART_HILLS, HILL_PAL),
    'mtn_snow': parse_tile(ART_MTN_SNOW, MTN_PAL),
    'mtn_rock': parse_tile(ART_MTN_ROCK, MTN_PAL),
    'mtn_ridge': parse_tile(ART_MTN_RIDGE, MTN_PAL),
    'lake_center': parse_tile(ART_LAKE_CENTER, WATER_PAL),
    'lake_shore_n': parse_tile(ART_LAKE_SHORE_N, WATER_PAL),
    'lake_shore_s': parse_tile(ART_LAKE_SHORE_S, WATER_PAL),
    'lake_shore_w': parse_tile(ART_LAKE_SHORE_W, WATER_PAL),
    'lake_shore_e': parse_tile(ART_LAKE_SHORE_E, WATER_PAL),
    'river_h': parse_tile(ART_RIVER_H, WATER_PAL),
    'river_v': parse_tile(ART_RIVER_V, WATER_PAL),
    'river_ws': parse_tile(ART_RIVER_WS, WATER_PAL),
    'river_ne': parse_tile(ART_RIVER_NE, WATER_PAL),
    'river_es': parse_tile(ART_RIVER_ES.replace(' ', 'm'), WATER_PAL),
    'river_nw': parse_tile(ART_RIVER_NW, WATER_PAL),
    'river_mouth_w': parse_tile(ART_RIVER_MOUTH_W, WATER_PAL),
    'river_mouth_e': parse_tile(ART_RIVER_MOUTH_E, WATER_PAL),
}
