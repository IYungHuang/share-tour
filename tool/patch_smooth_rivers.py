with open('tool/generate_snes_overworld.py') as f:
    code = f.read()

# Add make_river_straight and make_river_corner to generate_snes_overworld.py
river_funcs = '''
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
'''

import re
code = code.replace('import math\n', '')
code = 'import math\n' + code

# Replace MASTER_TILES update for rivers
river_tile_update = '''MASTER_TILES.update({
    'river_h': make_river_straight(horizontal=True),
    'river_v': make_river_straight(horizontal=False),
    'river_es': make_river_corner(15.5, 15.5),
    'river_ws': make_river_corner(-0.5, 15.5),
    'river_en': make_river_corner(15.5, -0.5),
    'river_wn': make_river_corner(-0.5, -0.5),
    'river_mouth_w': make_river_straight(horizontal=True),
    'river_mouth_e': make_river_straight(horizontal=True),
})'''

code = re.sub(r'    \'river_h\': RIVER_TILES\[\'H\'\].*?\'river_mouth_e\': RIVER_TILES\[\'MOUTH_E\'\],', '', code, flags=re.DOTALL)
code = code + '\n' + river_funcs + '\n' + river_tile_update + '\n'

with open('tool/generate_snes_overworld.py', 'w') as f:
    f.write(code)

print("Patched smooth rivers into master generator!")
