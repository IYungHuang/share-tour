import math
import numpy as np
from PIL import Image

ROAD_PAL = {
    'C': (210, 190, 155),
    'c': (180, 160, 125),
    'D': (145, 125, 95),
    'S': (105, 85, 60),
    'e': (125, 105, 75),
    '.': (76, 158, 54),
    'L': (98, 184, 70),
    'g': (56, 122, 38),
}

def get_cobble_color(x, y):
    # Staggered stone pattern
    row = y // 2
    col = (x + (row % 2)) // 3
    bx = (x + (row % 2)) % 3
    by = y % 2
    if bx == 0 or by == 0:
        return ROAD_PAL['S']
    elif bx == 1 and by == 1:
        return ROAD_PAL['C']
    else:
        return ROAD_PAL['c']

def make_road_tile(ports):
    # ports is set of 'N', 'S', 'E', 'W'
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    for y in range(16):
        for x in range(16):
            is_road = False
            is_edge = False
            
            # Straight sections
            if 'W' in ports and 'E' in ports:
                d = abs(y - 7.5)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
            if 'N' in ports and 'S' in ports:
                d = abs(x - 7.5)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
                
            # Corners
            if 'E' in ports and 'S' in ports:
                d = abs(math.hypot(x - 15.5, y - 15.5) - 8.0)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
            if 'W' in ports and 'S' in ports:
                d = abs(math.hypot(x - (-0.5), y - 15.5) - 8.0)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
            if 'E' in ports and 'N' in ports:
                d = abs(math.hypot(x - 15.5, y - (-0.5)) - 8.0)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
            if 'W' in ports and 'N' in ports:
                d = abs(math.hypot(x - (-0.5), y - (-0.5)) - 8.0)
                if d <= 3.5: is_road = True
                elif d <= 4.5: is_edge = True
                
            # T-junction stubs
            if 'N' in ports and not ('S' in ports):
                if 4 <= x <= 11 and y <= 8: is_road = True
            if 'S' in ports and not ('N' in ports):
                if 4 <= x <= 11 and y >= 7: is_road = True
            if 'W' in ports and not ('E' in ports):
                if 4 <= y <= 11 and x <= 8: is_road = True
            if 'E' in ports and not ('W' in ports):
                if 4 <= y <= 11 and x >= 7: is_road = True

            if is_road:
                tile[y, x] = get_cobble_color(x, y)
            elif is_edge:
                tile[y, x] = ROAD_PAL['e']
            else:
                tile[y, x] = ROAD_PAL['.'] if (x+y)%5 != 0 else ROAD_PAL['L']
    return tile

# Test all road tile variants
t_h = make_road_tile({'W', 'E'})
t_v = make_road_tile({'N', 'S'})
t_es = make_road_tile({'E', 'S'})
t_ws = make_road_tile({'W', 'S'})
t_en = make_road_tile({'E', 'N'})
t_wn = make_road_tile({'W', 'N'})
t_wes = make_road_tile({'W', 'E', 'S'})

demo2 = np.zeros((16, 16*7, 3), dtype=np.uint8)
for i, t in enumerate([t_h, t_v, t_es, t_ws, t_en, t_wn, t_wes]):
    demo2[:, i*16:(i+1)*16] = t

Image.fromarray(demo2).save('tool/test_procedural_roads.png')
print("Saved tool/test_procedural_roads.png successfully!")
