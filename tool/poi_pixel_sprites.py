import numpy as np

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

# ==============================================================================
# 1. 台北 101 (Taipei 101) - 18 x 48 (Hero Scale)
# - Red aircraft warning beacon & slender silver antenna spire
# - 8 distinct inverted flared pagoda / bamboo segment modules
# - Multi-tone teal/cyan reflective glass facade with diagonal sun glare
# - Gold ancient coin medallion / ruyi ornaments on module tips
# - Multi-level shopping mall podium base with glass atrium and entrance portal
# ==============================================================================
PAL_101 = {
    'R': (255, 45, 35),     # Red aircraft warning beacon
    'r': (180, 25, 20),     # Beacon dark
    'S': (245, 250, 255),   # Spire bright silver
    's': (165, 185, 200),   # Spire silver shadow
    'T': (110, 130, 145),   # Spire structural ring
    'L': (210, 255, 245),   # Sun glare white-cyan highlight
    'H': (115, 235, 210),   # Bright cyan-teal reflection
    'M': (40, 168, 142),    # Taipei 101 signature green-teal glass
    'D': (18, 105, 88),     # Glass shadow
    'd': (10, 60, 50),      # Dark window recess / mullion
    'Y': (255, 220, 55),    # Gold coin / ruyi medallion
    'y': (180, 145, 25),    # Gold shadow
    'W': (240, 235, 225),   # Mall granite light
    'w': (175, 170, 160),   # Granite shadow
    'G': (70, 125, 155),    # Mall glass atrium
    'g': (35, 75, 95),      # Atrium dark glass
    'K': (25, 30, 40),      # Base void / entrance canopy
}

ART_101 = """
........RS........
........sS........
........sS........
........sS........
.......TsST.......
........sS........
........sS........
.......TsST.......
.......ssss.......
......dLLMMd......
.....dLLHMMMD.....
....dYHHMMMMMYd...
....dLLHMMMMMDd...
.....dMMMMMMDd....
.....dddddddd.....
...dYHHMMMMMMMYd..
...dLLHMMMMMMMDd..
....dMMMMMMMMDd...
....dddddddddd....
..dYHHMMMMMMMMMYd.
..dLLHMMMMMMMMMDd.
...dMMMMMMMMMMDd..
...dddddddddddd...
..dYHHMMMMMMMMMYd.
..dLLHMMMMMMMMMDd.
...dMMMMMMMMMMDd..
...dddddddddddd...
.dYHHMMMMMMMMMMMYd
.dLLHMMMMMMMMMMMDd
..dMMMMMMMMMMMMDd.
..dddddddddddddd..
.dYHHMMMMMMMMMMMYd
.dLLHMMMMMMMMMMMDd
..dMMMMMMMMMMMMDd.
..dddddddddddddd..
dYHHMMMMMMMMMMMMMY
dLLHMMMMMMMMMMMMMD
.dMMMMMMMMMMMMMMDd
.dddddddddddddddd.
.WWWWWWWWWWWWWWWW.
.WHHWWGGWWGGWWHHw.
.WggWWggWWggWWggw.
WWWWWWWWWWWWWWWWWW
WWWWWWKKKKKKWWWWWW
WWWWWWKKKKKKWWWWWW
wwwwwwKKKKKKwwwwww
.wwwwwKKKKKKwwwww.
..KKKKKKKKKKKKKK..
"""

# ==============================================================================
# 2. 國立故宮博物院 (National Palace Museum) - 32 x 20
# Imperial yellow glazed curved roofs, green eave trim, red pillars, triple white terraces
# ==============================================================================
PAL_PALACE = {
    'Y': (250, 220, 60),    # Imperial Yellow tile
    'y': (190, 150, 25),    # Yellow shadow
    'G': (50, 140, 80),     # Eave trim green
    'g': (30, 90, 50),      # Green shadow
    'R': (205, 50, 40),     # Red pillars
    'r': (135, 30, 25),     # Red shadow
    'W': (245, 245, 250),   # White marble platform
    'w': (180, 185, 195),   # Marble shadow
    'K': (40, 35, 45),      # Door / opening
}

ART_PALACE = """
............YYYYYYYY............
...........yYYYYYYYYy...........
..........gGGGGGGGGGGg..........
.........gGGGGGGGGGGGGg.........
........yYYYYYYYYYYYYYYy........
.......gGGGGGGGGGGGGGGGGg.......
........rRR..RR....RR..RRr......
........rRK..RK....RK..RKr......
.....yYYYYYYYYYYYYYYYYYYYYy.....
....gGGGGGGGGGGGGGGGGGGGGGGg....
...yYYYYYYYYYYYYYYYYYYYYYYYYy...
..gGGGGGGGGGGGGGGGGGGGGGGGGGGg..
..rRR..RR..RR.KKKK.RR..RR..RRr..
..rRK..RK..RK.KKKK.RK..RK..RKr..
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
wWWWWWWWW.WWWWWWWW.WWWWWWWWWWWWw
.wwwwwwww.wwwwwwww.wwwwwwwwwwww.
..WWWWWWWWWWWWWWWWWWWWWWWWWWWW..
...wwwwwwwwwwwwwwwwwwwwwwwwww...
"""

# ==============================================================================
# 3. 九份老街 (Jiufen Old Street) - 28 x 28
# Hillside stacked tea houses, red lanterns, dark slate roofs, stone stairs
# ==============================================================================
PAL_JIUFEN = {
    'R': (245, 55, 40),     # Glowing red lantern
    'r': (165, 30, 25),     # Lantern shadow
    'Y': (255, 230, 90),    # Lantern warm glow
    'W': (125, 85, 55),     # Dark timber wall
    'w': (80, 50, 30),      # Timber shadow
    'T': (55, 60, 70),      # Slate tile roof
    't': (35, 40, 48),      # Roof shadow
    'S': (165, 165, 160),   # Stone steps
    's': (110, 110, 105),   # Stone shadow
    'K': (25, 20, 25),      # Window void
    'G': (60, 130, 60),     # Mountain greenery
}

ART_JIUFEN = """
........TTTTTTTTTT..........
.......TTTTTTTTTTTT.........
......tTTTTTTTTTTTTt........
......tWKWKWKWKWKWKt.TTTT...
......tWRYWRYWRYWRYttTTTTT..
......tWKWKWKWKWKWKttWKWKt..
.....tTTTTTTTTTTTTTttWRYt...
....tTTTTTTTTTTTTTTt.tWKWt..
...tTTTTTTTTTTTTTTTTttTTTT..
...tWKWKWKWKWKWKWKWKtSSSSS..
...tWRYWRYWRYWRYWRYWtSSSSSs.
...tWKWKWKWKWKWKWKWKt.SSSSs.
..tTTTTTTTTTTTTTTTTTt..SSSs.
.tTTTTTTTTTTTTTTTTTTTt.SSSs.
.tWKWKWKWKWKWKWKWKWKWt.SSSs.
.tWRYWRYWRYWRYWRYWRYWt.SSSs.
.tWKWKWKWKWKWKWKWKWKWt.SSSs.
tTTTTTTTTTTTTTTTTTTTTt.SSSs.
tWKWKWKWKWKWKWKWKWKWKt.SSSs.
tWRYWRYWRYWRYWRYWRYWKt.SSSs.
tWKWKWKWKWKWKWKWKWKWKt.SSSs.
tWRYWRYWRYWRYWRYWRYWKt.SSSs.
tWKWKWKWKWKWKWKWKWKWKt.SSSs.
SSSSSSSSSSSSSSSSSSSSSS.SSSs.
SSSSSSSSSSSSSSSSSSSSSS.SSSs.
ssssssssssssssssssssss.ssss.
.sssssssssssssssssssssssss..
...sssssssssssssssssssss....
"""

# ==============================================================================
# 4. 台中國家歌劇院 (National Taichung Theater) - 34 x 24
# Curved white sound walls, blue hourglass glass curtain, red theater interior
# ==============================================================================
PAL_OPERA = {
    'W': (248, 245, 240),   # Pure curved concrete white
    'L': (225, 220, 212),   # Concrete highlight
    'M': (185, 180, 170),   # Concrete midtone
    'D': (135, 130, 120),   # Concrete shadow
    'G': (65, 140, 180),    # Blue curved glass
    'B': (35, 80, 115),     # Glass shadow / frame
    'R': (205, 55, 45),     # Grand theater red interior
    'K': (75, 70, 65),      # Base shadow
}

ART_OPERA = """
...........WWWWWWWWWWWW...........
........WWLLLLLLLLLLLLLLWW........
......WWLLLLLLLLLLLLLLLLLLWW......
....WWLLLLLLLLLLLLLLLLLLLLLLWW....
...WLLLLGGGGLLLLLLLLGGGGLLLLLLW...
..WLLLLGBBBBGLLLLLLGBBBBGLLLLLLW..
.WLLLLGBBBBBBGLLLLGBBBBBBGLLLLLLW.
.WLLLLGBBBBBBGLLLLGBBBBBBGLLLLLLW.
.WLLRRRGBBBBGRRRRRRGBBBBGRRRLLLLW.
.WLLRRRGBBBBGRRRRRRGBBBBGRRRLLLLW.
.WLLLLGBBBBBBGLLLLGBBBBBBGLLLLLLW.
.WLLLLGBBBBBBGLLLLGBBBBBBGLLLLLLW.
.WLLLLLGBBBBGLLLLLLGBBBBGLLLLLLLW.
.WLLLLLLGGGGLLLLLLLLGGGGLLLLLLLLW.
.WLLLLLLLLLLLLGGGGLLLLLLLLLLLLLLW.
.WLLLLLLLLLLLGGBBGLLLLLLLLLLLLLLW.
.WLLLLLLLLLLLGGBBGLLLLLLLLLLLLLLW.
.WLLLLLLLLLLLGGBBGLLLLLLLLLLLLLLW.
.WLLLLLLLLLLLLGGGGLLLLLLLLLLLLLLW.
..MDDDDDDDDDDDDDDDDDDDDDDDDDDDDM..
...MDDDDDDDDDDDDDDDDDDDDDDDDDDM...
....KKKKKKKKKKKKKKKKKKKKKKKKKK....
.....KKKKKKKKKKKKKKKKKKKKKKKK.....
......KKKKKKKKKKKKKKKKKKKKKK......
"""

# ==============================================================================
# 5. 太魯閣國家公園牌樓 (Taroko Gorge Arch) - 36 x 21
# Blue-green glazed tiles, ornate Chinese ceremonial archway, red lacquered posts
# ==============================================================================
PAL_TAROKO = {
    'G': (45, 145, 105),    # Blue-green glazed tile
    'g': (30, 95, 68),      # Green shadow
    'Y': (245, 205, 50),    # Golden ridge ornamentation
    'R': (205, 50, 40),     # Red lacquer wood
    'r': (135, 30, 25),     # Red shadow
    'W': (240, 245, 250),   # White marble plaque
    'w': (170, 180, 190),   # Marble shadow
    'K': (30, 30, 35),      # Void / calligraphy
}

ART_TAROKO = """
............YYYY....YYYY............
...........GGGGGG..GGGGGG...........
..........gGGGGGGGGGGGGGGg..........
........gGGGGGGGGGGGGGGGGGGg........
......gGGGGGGGGGGGGGGGGGGGGGGg......
.....gGGGGGGGGGGGGGGGGGGGGGGGGg.....
...gGGGGGGGGGGGGGGGGGGGGGGGGGGGGg...
..gGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGg..
....wWWWWWWWWWWWWWWWWWWWWWWWWWWw....
....wWKK..KKKK..KKKK..KKKK..KKWw....
....wWWWWWWWWWWWWWWWWWWWWWWWWWWw....
...RRR....RRR..........RRR....RRR...
...RRR....RRR..........RRR....RRR...
...RRR....RRR..........RRR....RRR...
...RRR....RRR..........RRR....RRR...
...RRR....RRR..........RRR....RRR...
...rRR....rRR..........rRR....rRR...
..wWWw...wWWw..........wWWw...wWWw..
..wWWw...wWWw..........wWWw...wWWw..
..wWWw...wWWw..........wWWw...wWWw..
..wwww...wwww..........wwww...wwww..
"""

# ==============================================================================
# 6. 日月潭慈恩塔 (Sun Moon Lake Ci'en Pagoda) - 28 x 34
# Octagonal 9-tiered pagoda, gold pinnacle, flying red eaves, white balustrades
# ==============================================================================
PAL_PAGODA = {
    'Y': (250, 220, 60),    # Gold spire finial
    'O': (215, 155, 40),    # Gold shadow
    'R': (220, 60, 45),     # Pagoda red eave
    'D': (150, 35, 25),     # Deep red eave shadow
    'G': (75, 145, 90),     # Jade eave undersides
    'W': (245, 240, 230),   # White tower wall
    'w': (180, 175, 165),   # Wall shadow
    'K': (45, 40, 40),      # Window void
    'S': (165, 160, 150),   # Stone podium
    's': (110, 105, 100),   # Podium shadow
}

ART_PAGODA = """
.............YY.............
.............YY.............
............YYYY............
............YYYY............
...........RRRRRR...........
..........DGGGGGGGD.........
.........DGRRRRRRRRGD.......
..........DKWWWWWWKD........
..........DKWWWWWWKD........
.........RRRRRRRRRRRR.......
........DGGGGGGGGGGGGD......
.......DGRRRRRRRRRRRRGD.....
.........DKWWWWWWWWKD.......
.........DKWWWWWWWWKD.......
.......RRRRRRRRRRRRRRRR.....
......DGGGGGGGGGGGGGGGGD....
.....DGRRRRRRRRRRRRRRRRGD...
.......DKWWWWWWWWWWWWKD.....
.......DKWWWWWWWWWWWWKD.....
.....RRRRRRRRRRRRRRRRRRRR...
....DGGGGGGGGGGGGGGGGGGGGD..
...DGRRRRRRRRRRRRRRRRRRRRGD.
.....DKWWWWWWWWWWWWWWWWKD...
.....DKWWWWWWWWWWWWWWWWKD...
...RRRRRRRRRRRRRRRRRRRRRRRR.
..DGGGGGGGGGGGGGGGGGGGGGGGGD
.GRRRRRRRRRRRRRRRRRRRRRRRRRG
....DKWWWWWWWWWWWWWWWWWWKD..
....DKWWWWWWWWWWWWWWWWWWKD..
...SWWWWWWWWWWWWWWWWWWWWWWWS
...SWWWWWWWWWWWWWWWWWWWWWWWS
..sSSSSSSSSSSSSSSSSSSSSSSSSs
..sSSSSSSSSSSSSSSSSSSSSSSSSs
ssssssssssssssssssssssssssss
"""

# ==============================================================================
# 7. 阿里山森林神木與紅色小火車 (Alishan Forest & Train) - 32 x 23
# Giant ancient Formosan cypress + classic red Alishan diesel locomotive
# ==============================================================================
PAL_ALISHAN = {
    'L': (80, 180, 65),     # Forest foliage bright
    'G': (45, 125, 50),     # Foliage midtone
    'g': (28, 80, 32),      # Foliage dark shadow
    'B': (120, 80, 50),     # Cedar trunk bark
    'b': (75, 48, 30),      # Trunk bark shadow
    'R': (225, 45, 35),     # Alishan locomotive red
    'r': (155, 28, 22),     # Loco red shadow
    'W': (245, 250, 255),   # White stripe / cab window
    'Y': (255, 225, 60),    # Train headlight glow
    'K': (35, 38, 42),      # Bogie / steel track / exhaust
}

ART_ALISHAN = """
............LLLLGGGG............
.........LLLLGGGGGGgggg.........
.......LLLLGGGGGGGGGGgggg.......
......LLLLGGGGGGGGGGGGgggg......
.....LLLLGGGGGBBBBGGGGGgggg.....
.....LLLLGGGGGBBBBGGGGGgggg.....
......LLLGGGGGBBBBGGGGgggg......
........GGGGGGBBBBGGgggg........
..........GGGGBBBBGGgg..........
............BBBBBBBB............
............BBBBBBBB............
............BBBBBBBB..RRRRRRRR..
...........gBBBBBBBB.RRWWWWWWRK.
...........GBBBBBBBB.RRWWWWWWRK.
..........GGBBBBBBBBRRRRRRRRRRK.
.........gg.BBBBBBBBYRWRRWWRWRK.
............BBBBBBBBYRWRRWWRWRK.
............BBBBBBBBRRRRRRRRRRK.
..........KKBBBBBBBBKKKKKKKKKKK.
.........KKKBBBBBBBBKKKKKKKKKKK.
.......KKKKKKKKKKKKKKKKKKKKKKKKK
......KKKKKKKKKKKKKKKKKKKKKKKKKK
................................
"""

# ==============================================================================
# 8. 台南赤崁樓 (Tainan Chihkan Tower) - 28 x 19
# Minnan red brick pavilion, sweeping swallowtail eaves, stone base
# ==============================================================================
PAL_CHIKHAN = {
    'R': (200, 60, 45),     # Red brick / glazed roof
    'r': (135, 38, 28),     # Red brick shadow
    'Y': (245, 195, 55),    # Golden swallowtail finials
    'W': (235, 230, 220),   # White stone base
    'w': (165, 160, 150),   # Stone base shadow
    'K': (45, 35, 35),      # Window opening void
    'G': (75, 135, 80),     # Glazed green balustrade
}

ART_CHIKHAN = """
.YY......................YY.
..RRRRRRRRRRRRRRRRRRRRRRRR..
...rRRRRRRRRRRRRRRRRRRRRr...
..rRRRRRRRRRRRRRRRRRRRRRRr..
.rRRRRRRRRRRRRRRRRRRRRRRRRr.
....rRR..RR....RR..RR.r.....
....rRK..RK....RK..RK.r.....
...rRRRRRRRRRRRRRRRRRRRRr...
..rRRRRRRRRRRRRRRRRRRRRRRr..
.rRRRRRRRRRRRRRRRRRRRRRRRRr.
.rRR..RR..KKKKKK..RR..RR.rR.
.rRK..RK..KKKKKK..RK..RK.rK.
.WWWWWWWWWWWWWWWWWWWWWWWWWW.
.WWWWWWWWWWWWWWWWWWWWWWWWWW.
wWWWWWWWWWWWWWWWWWWWWWWWWWWw
wWWWWWWWWWWWWWWWWWWWWWWWWWWw
.wWWWW..wWWWW..wWWWW..wWWw..
.wWWWW..wWWWW..wWWWW..wWWw..
..wwww...wwww...wwww...ww...
"""

# ==============================================================================
# 9. 高雄 85 大樓 (Kaohsiung 85 Sky Tower) - 22 x 28
# Tall twin prong skyscraper, central hollow "高" gate, needle spire
# ==============================================================================
PAL_85 = {
    'S': (245, 250, 255),   # Spire bright
    's': (165, 185, 205),   # Spire shadow
    'L': (120, 165, 200),   # Blue-steel reflective glass bright
    'M': (75, 115, 150),    # Blue-steel midtone
    'D': (40, 70, 98),      # Blue-steel shadow
    'K': (22, 35, 50),      # Center void / shadow
}

ART_85 = """
..........Ss..........
..........Ss..........
..........Ss..........
.........LSsD.........
.........LMMD.........
........LMMMMD........
........LMMMMD........
.......LMD..SMD.......
.......LMD..SMD.......
......LMMD..SMMD......
......LMMD..SMMD......
.....LMMMD..SMMMD.....
.....LMMMD..SMMMD.....
....LMMMMD..SMMMMD....
....LMMMMD..SMMMMD....
...LMMMMMD..SMMMMMD...
...LMMMMMD..SMMMMMD...
...LMMMMMD..SMMMMMD...
..LMMMMMMD..SMMMMMMD..
..LMMMMMMD..SMMMMMMD..
..LMMMMMMD..SMMMMMMD..
.LMMMMMMMD..SMMMMMMMD.
.LMMMMMMMD..SMMMMMMMD.
.LMMMMMMMD..SMMMMMMMD.
.LMMMMMMMMMMMMMMMMMMD.
.LMMMMMMMMMMMMMMMMMMD.
..KMMMMMMMMMMMMMMMMK..
..KMMMMMMMMMMMMMMMMK..
"""

# ==============================================================================
# 10. 墾丁鵝鑾鼻燈塔 (Eluanbi Lighthouse) - 16 x 25
# Pure white cylindrical lighthouse tower, black dome gallery, beacon ray
# ==============================================================================
PAL_ELUANBI = {
    'K': (35, 40, 50),      # Lantern gallery black
    'k': (65, 70, 80),      # Lantern highlight
    'Y': (255, 245, 130),   # Lens beacon beam
    'W': (248, 252, 255),   # White masonry body
    'w': (180, 190, 205),   # White shadow
    'D': (115, 125, 140),   # Base fort wall
}

ART_ELUANBI = """
....kkKKKKkk....
...kkKKKKKKkk...
...KKYYYYYYKK...
...KKYYYYYYKK...
...DDDDDDDDDD...
....WWWWWWww....
....WWWWWWww....
....WWWWWWww....
....WWWWWWww....
...WWWWWWWWww...
...WWWWWWWWww...
...WWWWWWWWww...
...WWWWWWWWww...
..WWWWWWWWWWww..
..WWWWWWWWWWww..
..WWWWWWWWWWww..
..WWWWWWWWWWww..
.WWWWWWWWWWWWww.
.WWWWWWWWWWWWww.
.WWWWWWWWWWWWww.
WWWWWWWWWWWWWWww
WWWWWWWWWWWWWWww
DDDDDDDDDDDDDDDD
DDDDDDDDDDDDDDDD
.DDDDDDDDDDDDDD.
"""

# ==============================================================================
# 11. 台灣知名夜市 (Taiwan Famous Night Market) - 14 x 12
# Traditional night market entrance archway, glowing red lanterns, food carts
# ==============================================================================
PAL_MARKET = {
    'R': (235, 45, 35),     # Red torii / gate
    'r': (155, 25, 20),     # Red shadow
    'Y': (255, 220, 50),    # Gold roof ridge / bright lantern
    'O': (255, 125, 25),    # Warm lantern glow
    'W': (245, 245, 250),   # White banner / stall counter
    'w': (165, 165, 170),   # White shadow
    'B': (50, 120, 210),    # Blue striped awning
    'b': (30, 80, 150),     # Blue shadow
    'K': (35, 30, 35),      # Stall interior
    'S': (210, 220, 230),   # Steaming aroma / vapor
}

ART_MARKET = """
...YYYYYYYY...
..RRRRRRRRRR..
.rRRRRRRRRRRr.
.rRYOYYYYOYRr.
..RR...S....RR
..RR.WBBBW..RR
.rRR.WbBbW.rRR
.rRR.WYYYW.rRR
.rRR.WKKKW.rRR
.rRR.WWWWW.rRR
.wWW.wWWww.wWW
.wwwwwwwwwwwww
"""

# ==============================================================================
# 12. 台灣百岳頂峰 (Taiwan Mountain Peak) - 16 x 16
# Snow-capped rocky mountain summit, triangulation marker pillar & summit flag
# ==============================================================================
PAL_PEAK = {
    'W': (250, 250, 255),   # Alpine snow / frost
    'w': (190, 200, 215),   # Snow shadow
    'R': (235, 45, 35),     # Summit flag
    'Y': (255, 215, 50),    # Flag pole gold tip
    'S': (160, 165, 175),   # Granite triangulation pillar
    's': (110, 115, 125),   # Granite shadow
    'M': (95, 100, 110),    # Rocky mountain midtone
    'D': (60, 65, 75),      # Rocky mountain dark shadow
    'G': (50, 115, 60),     # Subalpine dwarf bamboo / pine
}

ART_PEAK = """
.......YR.......
.......SRR......
.......S........
......WWW.......
.....WWWWw......
....WWWWWWw.....
...WWMMMDDDw....
..WWMMMMMDDDw...
.WWMMMMMMMDDDw..
.WMMMDDDMMMDDDw.
WMMMDDDDDMMMDDDw
WMMDDDDDDDDMDDDw
.GMMDDDDDDDDDDG.
GGMMMDDDDDDDDDGG
GGGGMMMDDDDDGGGG
.GGGGGGDDDDGGGG.
"""

# ==============================================================================
# 13. 台灣高鐵車站 (THSR Station) - 20 x 13
# ==============================================================================
PAL_THSR = {
    'S': (240, 245, 250),   # Silver/White curved roof
    's': (175, 185, 195),   # Roof shadow
    'O': (245, 120, 20),    # THSR signature Orange stripe
    'o': (180, 80, 10),     # Orange shadow
    'B': (40, 45, 55),      # Black/Charcoal stripe
    'G': (100, 170, 210),   # Blue-tinted glass concourse
    'g': (50, 100, 140),    # Glass shadow
    'C': (210, 215, 220),   # Concrete platform plinth
    'c': (140, 145, 150),   # Concrete shadow
    'K': (25, 30, 40),      # Track bed void
}

ART_THSR = """
....SSSSSSSSSSSS....
...SSSSSSSSSSSSSS...
..ssssssssssssssss..
.OOOOOOOOOOOOOOOOOO.
.BBBBBBBBBBBBBBBBBB.
.GGGGGGGGGGGGGGGGGG.
.GggGggGggGggGggGgg.
.GggGggGggGggGggGgg.
.GGGGGGGGGGGGGGGGGG.
CCCCCCCCCCCCCCCCCCCC
C..K..K..K..K..K..Kc
C..K..K..K..K..K..Kc
cccccccccccccccccccc
"""
