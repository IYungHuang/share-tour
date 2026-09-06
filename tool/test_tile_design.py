import numpy as np
from PIL import Image
from tool.snes_tiles import MTN_PAL, FOREST_PAL, WATER_PAL, GRASS_PAL, parse_tile

# Let's design connected mountain tiles:
# 1. MTN_PEAK: Top of peak (Y=0..15), sharp pyramid summit
#    Top rows 0-3: Pointed crest
#    Rows 4-11: Faceted rock faces (NW highlight, SE shadow)
#    Rows 12-15: Connects seamlessly to MTN_BODY or grass

ART_MTN_PEAK_NEW = """
.......HH.......
......HLLD......
.....HLMMDD.....
....HLMMMMDD....
...HLMMMMMMDD...
..HLMMMMMMMMDD..
.HLMMMMMMMMMMDD.
HLMMMMMMMMMMMMDD
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDD
MMMMDDDSXDMMMMDD
MMMDDDSXXDMMMMDD
MMDDDSXXXDMMMMDD
MDDDSXXXXDMMMMDD
DDDSXXXXXDMMMMDD
"""

# 2. MTN_SNOW_PEAK: High snow summit (Yushan)
ART_MTN_SNOW_NEW = """
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
DDDSXXXXXDMMMMDD
"""

# 3. MTN_BODY: Mountain massif interior (connects seamlessly to peak above, body on sides, base below)
ART_MTN_BODY_NEW = """
DDDSXXXXXDMMMMDD
MDDDSXXXXDMMMMDD
MMDDDSXXXDMMMMDD
MMMDDDSXXDMMMMDD
HLMMMMMDDMMMMMDD
LMMMMMDDDMMMMMDD
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

# 4. MTN_BASE: Bottom of mountain range transitioning into scree & grass
ART_MTN_BASE_NEW = """
DDDSXXXXXDMMMMDD
MDDDSXXXXDMMMMDD
MMDDDSXXXDMMMMDD
MMMDDDSXXDMMMMDD
HLLMMMMDDMMMMDDX
.XDDMMDDXXDDMDX.
...XXDDX..XXDX..
................
.L...D........L.
....DD.S........
................
...L..D......L..
.L..D.....L...D.
....D...........
..L...D......L..
........L...DD.S
"""

# 5. MTN_SLOPE_W: West edge of mountain (slopes down into grass on west)
ART_MTN_SLOPE_W_NEW = """
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
MMDDDSXXXDMMMMDD
.XDDMMDDXXDDMMDD
..XXDDDDXXXDMMDD
...XXXXXXX..XMDD
............XDDD
"""

# 6. MTN_SLOPE_E: East edge of mountain (slopes down into grass on east)
ART_MTN_SLOPE_E_NEW = """
DDDSXXXXXD......
MDDDSXXXXD......
MMDDDSXXXD......
MMMDDDSXXDD.....
HLMMMMMDDMMD....
LMMMMMDDDMMMD...
MMMMMDDDSDMMMD..
MMMMDDDSXDMMMMD.
HLMMMMMDDMMMMMD.
LMMMMMDDDMMMMMDD
MMMMMDDDSDMMMMDX
MMMMDDDSXDMMMDXX
MMMDDDSXXDMMDXX.
MMDDDSXXXDMDXX..
MDDDSXXXXDDXX...
DDDSXXXXXDX.....
"""

print("Testing parsing new mountain tiles...")
p = parse_tile(ART_MTN_PEAK_NEW, MTN_PAL)
s = parse_tile(ART_MTN_SNOW_NEW, MTN_PAL)
b = parse_tile(ART_MTN_BODY_NEW, MTN_PAL)
base = parse_tile(ART_MTN_BASE_NEW, MTN_PAL)
sw = parse_tile(ART_MTN_SLOPE_W_NEW, MTN_PAL)
se = parse_tile(ART_MTN_SLOPE_E_NEW, MTN_PAL)

# Render a 3x3 test mountain massif!
test_mtn = np.zeros((48, 48, 3), dtype=np.uint8)
test_mtn[0:16, 0:16] = sw
test_mtn[0:16, 16:32] = s
test_mtn[0:16, 32:48] = se
test_mtn[16:32, 0:16] = sw
test_mtn[16:32, 16:32] = b
test_mtn[16:32, 32:48] = se
test_mtn[32:48, 0:16] = sw
test_mtn[32:48, 16:32] = base
test_mtn[32:48, 32:48] = se

Image.fromarray(test_mtn).save('tool/test_mtn_massif.png')
print("Saved tool/test_mtn_massif.png successfully!")
