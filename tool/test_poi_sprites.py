import numpy as np
from PIL import Image

# 1. TAIPEI 101 (16 x 28)
# Colors:
# '.' transparent (background)
# 'W' silver/white spire (240, 245, 250)
# 'S' spire shadow (160, 180, 200)
# 'H' pagoda highlight jade (80, 180, 160)
# 'M' pagoda base jade (40, 128, 110)
# 'D' pagoda shadow jade (25, 88, 75)
# 'Y' gold coin ornament (235, 195, 60)
# 'B' base concrete light (160, 168, 175)
# 'K' base concrete dark (110, 118, 125)

PAL_101 = {
    'W': (240, 245, 250),
    'S': (160, 180, 200),
    'H': (80, 180, 160),
    'M': (40, 128, 110),
    'D': (25, 88, 75),
    'Y': (235, 195, 60),
    'B': (160, 168, 175),
    'K': (110, 118, 125),
}

ART_101 = """
.......WS.......
.......WS.......
.......WS.......
......HWSD......
......HWSD......
.....HMMMDD.....
.....HMMMDD.....
....YMMMMMMY....
....HMMMMMMD....
...HMMMMMMMMD...
...YMMMMMMMMY...
...HMMMMMMMMD...
..HMMMMMMMMMMD..
..YMMMMMMMMMMY..
..HMMMMMMMMMMD..
.HMMMMMMMMMMMMD.
.YMMMMMMMMMMMMY.
.HMMMMMMMMMMMMD.
.HMMMMMMMMMMMMD.
.YMMMMMMMMMMMMY.
.HMMMMMMMMMMMMD.
.HMMMMMMMMMMMMD.
.YMMMMMMMMMMMMY.
.HMMMMMMMMMMMMD.
..HMMMMMMMMMMD..
.KBBBBBBBBBBBBK.
KBBBBBBBBBBBBBBK
KKKKKKKKKKKKKKKK
"""

# 2. TAICHUNG OPERA (22 x 16)
PAL_OPERA = {
    'W': (245, 242, 235),
    'L': (220, 215, 205),
    'M': (180, 175, 165),
    'D': (130, 125, 115),
    'G': (60, 130, 165),    # Glass blue
    'B': (30, 75, 105),     # Glass dark
    'R': (195, 55, 45),     # Theater red accent
    'K': (85, 80, 75),      # Base
}

ART_OPERA = """
......WWWWWWWWWW......
....WWLLLLLLLLLLWW....
...WLLLLLLLLLLLLLLW...
..WLLLLGGLLLLGGLLLLW..
..WLLLGBBGLLGBBGLLLW..
.WLLLLGBBGLLGBBGLLLLW.
.WLLRRGBBGRRGBBGRRLLW.
.WLLRRGBBGRRGBBGRRLLW.
.WLLLLGBBGLLGBBGLLLLW.
.WLLLLGGLLLLLLGGLLLLW.
.WLLLLLLLLGGLLLLLLLLW.
.WLLLLLLLGGBGLLLLLLLW.
.WLLLLLLLGGBGLLLLLLLW.
..MDDDDDDDDDDDDDDDDM..
...MDDDDDDDDDDDDDDM...
....KKKKKKKKKKKKKK....
"""

# 3. SUN MOON LAKE PAGODA (18 x 22)
PAL_PAGODA = {
    'Y': (245, 215, 60),    # Gold finial
    'O': (210, 150, 40),
    'R': (215, 60, 40),     # Red pillar/roof
    'D': (150, 30, 20),     # Deep red
    'W': (240, 235, 225),   # Wall/stone
    'S': (160, 155, 145),   # Stone shadow
    'G': (80, 140, 90),     # Jade eave accent
    'K': (60, 50, 45),
}

ART_PAGODA = """
........YO........
........YO........
.......YYOO.......
.....RRRRRRRR.....
....DGGGGGGGGD....
...DGRRRRRRRRGD...
....DKWWWWWWKD....
....DKWWWWWWKD....
...RRRRRRRRRRRR...
..DGGGGGGGGGGGGD..
.DGRRRRRRRRRRRRGD.
...DKWWWWWWWWKD...
...DKWWWWWWWWKD...
.RRRRRRRRRRRRRRRR.
DGGGGGGGGGGGGGGGGD
GRRRRRRRRRRRRRRRRG
..DKWWWWWWWWWWKD..
..DKWWWWWWWWWWKD..
.SWWWWWWWWWWWWWWS.
.SWWWWWWWWWWWWWWS.
KKKKKKKKKKKKKKKKKK
.KKKKKKKKKKKKKKKK.
"""

# 4. KAOHSIUNG 85 (18 x 28)
PAL_85 = {
    'W': (240, 245, 250),   # Spire
    'S': (160, 180, 200),
    'L': (110, 150, 185),   # Blue-steel light
    'M': (75, 110, 145),    # Blue-steel mid
    'D': (45, 70, 95),      # Blue-steel shadow
    'G': (30, 45, 65),      # Glass dark/void
    'K': (20, 30, 45),      # Deep shadow
}

ART_85 = """
.......WS......
......HLLD.....
......HMMD.....
.....HMMMMD....
....HMD..HMD...
...HMMD..HMMD..
...HMMD..HMMD..
..HMMMD..HMMMD.
..KMMMK..KMMMK.
"""

# Test rendering all 4
def parse_sprite(art_str, pal):
    lines = [l.strip() for l in art_str.strip().split('\n') if l.strip()]
    h = len(lines)
    w = len(lines[0])
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for y, line in enumerate(lines):
        assert len(line) == w, f"Line {y} len {len(line)} != {w}"
        for x, ch in enumerate(line):
            if ch == '.':
                arr[y, x] = [0, 0, 0, 0]
            else:
                c = pal.get(ch, (200, 200, 200))
                arr[y, x] = [c[0], c[1], c[2], 255]
    return arr

s1 = parse_sprite(ART_101, PAL_101)
s2 = parse_sprite(ART_OPERA, PAL_OPERA)
s3 = parse_sprite(ART_PAGODA, PAL_PAGODA)
s4 = parse_sprite(ART_85.replace('H', 'L'), PAL_85)

print("Sprite 101 shape:", s1.shape)
print("Sprite Opera shape:", s2.shape)
print("Sprite Pagoda shape:", s3.shape)
print("Sprite 85 shape:", s4.shape)

# Create a showcase strip
canvas = np.zeros((36, 100, 4), dtype=np.uint8)
canvas[4:4+s1.shape[0], 4:4+s1.shape[1]] = s1
canvas[10:10+s2.shape[0], 26:26+s2.shape[1]] = s2
canvas[7:7+s3.shape[0], 52:52+s3.shape[1]] = s3
canvas[4:4+s4.shape[0], 76:76+s4.shape[1]] = s4

Image.fromarray(canvas).save('tool/test_pois_showcase.png')
print("Saved tool/test_pois_showcase.png successfully!")
