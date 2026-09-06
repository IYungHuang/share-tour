"""
River router and tile generator for SNES 16-bit JRPG overworld.
"""
import numpy as np
from tool.snes_tiles import parse_tile, WATER_PAL

# River Tiles with 6px wide water channel (centered at cols/rows 5..10)
# Entrance/Exit ports are exactly at x=5..10 or y=5..10.

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

# Turn: West <-> South (connects (0, 5..10) to (5..10, 15))
ART_RIVER_WS = """
................
.L...D........L.
....DD.S........
BBBBBBBBBB......
KKKKKKKKKKKB....
llllllllllmlKB..
mmmmmmmmmmmlKB..
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwBKmlKB.
mmmmmmmmmBKmlKB.
lllllllllBKmlKBL
BBBBBBBBB..mlKB.
KKKKKKKKK..mlKB.
.L...D...DBmlKBD
....DD.S.SBmlKBS
"""

# Turn: East <-> South (connects (15, 5..10) to (5..10, 15))
ART_RIVER_ES = """
................
.L...D........L.
....DD.S........
......BBBBBBBBBB
....BKKKKKKKKKKK
..BKlmllllllllll
..BKlmmmmmmmmmmm
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmBKwwwwwwwww
.BKlmBKmmmmmmmmm
LBKlmBKlllllllll
.BKlm..BBBBBBBBB
.BKlm..KKKKKKKKK
DBKlmBD..D...L..
SBKlmBS.S.DD....
"""

# Turn: West <-> North (connects (0, 5..10) to (5..10, 0))
ART_RIVER_WN = """
.L...D...DBmlKBD
....DD.S.SBmlKBS
KKKKKKKKK..mlKB.
BBBBBBBBB..mlKB.
lllllllllBKmlKBL
mmmmmmmmmBKmlKB.
wwwwwwwwwBKmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
mmmmmmmmmmmlKB..
llllllllllmlKB..
KKKKKKKKKKKB....
BBBBBBBBBB......
....DD.S........
.L...D........L.
................
"""

# Turn: East <-> North (connects (15, 5..10) to (5..10, 0))
ART_RIVER_EN = """
DBKlmBD..D...L..
SBKlmBS.S.DD....
.BKlm..KKKKKKKKK
.BKlm..BBBBBBBBB
LBKlmBKlllllllll
.BKlmBKmmmmmmmmm
.BKlmBKwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
..BKlmmmmmmmmmmm
..BKlmllllllllll
....BKKKKKKKKKKK
......BBBBBBBBBB
....DD.S........
.L...D........L.
................
"""

# River Mouth West
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

# River Mouth East
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

RIVER_TILES = {
    'H': parse_tile(ART_RIVER_H, WATER_PAL),
    'V': parse_tile(ART_RIVER_V, WATER_PAL),
    'WS': parse_tile(ART_RIVER_WS, WATER_PAL),
    'ES': parse_tile(ART_RIVER_ES, WATER_PAL),
    'WN': parse_tile(ART_RIVER_WN, WATER_PAL),
    'EN': parse_tile(ART_RIVER_EN, WATER_PAL),
    'MOUTH_W': parse_tile(ART_RIVER_MOUTH_W, WATER_PAL),
    'MOUTH_E': parse_tile(ART_RIVER_MOUTH_E, WATER_PAL),
}

def get_river_tile(prev_dir, next_dir):
    """
    Given incoming direction (dx, dy) and outgoing direction (dx, dy),
    returns the appropriate river tile key.
    Directions are from previous tile to current tile, and current to next.
    """
    # Directions:
    # dx=-1 (going West), dx=1 (going East), dy=-1 (going North), dy=1 (going South)
    dirs = set([(-prev_dir[0], -prev_dir[1]), next_dir])
    
    if (-1, 0) in dirs and (1, 0) in dirs:
        return 'H'
    if (0, -1) in dirs and (0, 1) in dirs:
        return 'V'
    if (-1, 0) in dirs and (0, 1) in dirs:
        return 'WS'
    if (1, 0) in dirs and (0, 1) in dirs:
        return 'ES'
    if (-1, 0) in dirs and (0, -1) in dirs:
        return 'WN'
    if (1, 0) in dirs and (0, -1) in dirs:
        return 'EN'
    return 'H'

print("River engine ready!")
