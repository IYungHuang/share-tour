"""
Mountain tile definitions and procedural mountain range builder for SNES overworld.
"""
import numpy as np
from tool.snes_tiles import parse_tile, MTN_PAL, HILL_PAL

# 1. High Snow Peak (Yushan / Xueshan)
ART_MTN_SNOW = """
................
.......WW.......
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
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
"""

# 2. Sharp Rock Peak
ART_MTN_PEAK = """
................
.......HH.......
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

# 3. Mountain Ridge (Horizontally seamless connected crest)
ART_MTN_RIDGE = """
.HH.......HH....
HLLD.....HLLD...
LMMDD...HLMMDD..
MMMMDD.HLMMMMDD.
MMMMMDDLMMMMMMDD
MMMMMDDDMMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
MMMDDDSXXDMMMMDD
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
"""

# 4. Mountain Base (Scree & foothills meeting grass)
ART_MTN_BASE = """
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

# 5. Mountain Flank West (Tapering to west plain)
ART_MTN_FLANK_W = """
................
..........HH....
.........HLLD...
........HLMMDD..
.......HLMMMMDD.
......HLMMMMMMDD
.....HLMMMMMMMDD
....HLMMMMMMMMDD
...HLMMMMMMMMMDD
..HLMMMMMMMMMMDD
.HLMMMMMMMMMMMDD
HLMMMMMMMMMMMMDD
LMMMMMDDMMMMMMDD
MMMMMDDDMMMMMMDD
MMMMDDDSDMMMMMDD
MMMDDDSXXDMMMMDD
"""

# 6. Mountain Flank East (Cliff shadow facing east)
ART_MTN_FLANK_E = """
................
....HH..........
...HLLD.........
..HLMMDD........
.HLMMMMDD.......
HLMMMMMMDD......
LMMMMMMMDD......
MMMMMMMMDD......
MMMMMMMMMDD.....
MMMMMMMMMMDD....
MMMMMMMMMMMDD...
MMMMMMMMMMMMDD..
MMMMMMMDDMMMMDD.
MMMMMMDDDMMMMMDD
MMMMMDDSDMMMMMDD
MMMMDDDSXDMMMMDD
"""

# 7. Rolling Hills
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

MTN_TILES = {
    'snow': parse_tile(ART_MTN_SNOW, MTN_PAL),
    'peak': parse_tile(ART_MTN_PEAK, MTN_PAL),
    'ridge': parse_tile(ART_MTN_RIDGE, MTN_PAL),
    'base': parse_tile(ART_MTN_BASE, MTN_PAL),
    'flank_w': parse_tile(ART_MTN_FLANK_W, MTN_PAL),
    'flank_e': parse_tile(ART_MTN_FLANK_E, MTN_PAL),
    'hills': parse_tile(ART_HILLS, HILL_PAL),
}

print("Mountain engine ready!")
