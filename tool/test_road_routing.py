import math
from collections import deque
import numpy as np
from PIL import Image

COASTLINE = [
    (25.298, 121.535), (25.163, 121.745), (25.007, 122.002), (24.855, 121.845),
    (24.596, 121.868), (24.300, 121.780), (23.986, 121.618), (23.480, 121.500),
    (23.100, 121.372), (22.755, 121.152), (22.610, 121.005), (22.320, 120.905),
    (22.005, 120.878), (21.902, 120.852), (21.925, 120.720), (22.160, 120.700),
    (22.368, 120.592), (22.468, 120.450), (22.610, 120.268), (23.000, 120.160),
    (23.270, 120.118), (23.462, 120.132), (23.752, 120.248), (24.198, 120.498),
    (24.288, 120.528), (24.492, 120.668), (24.848, 120.928), (25.032, 121.082),
    (25.183, 121.418),
]

W, H = 2048, 1152
MARGIN_Y = 0.06
lats = [p[0] for p in COASTLINE]
lngs = [p[1] for p in COASTLINE]
LAT_MIN, LAT_MAX = min(lats), max(lats)
LNG_MIN, LNG_MAX = min(lngs), max(lngs)
LAT_REF = (LAT_MIN + LAT_MAX) / 2
KX = math.cos(math.radians(LAT_REF))
span_y = LAT_MAX - LAT_MIN
span_x = (LNG_MAX - LNG_MIN) * KX
scale = (H * (1 - 2 * MARGIN_Y)) / span_y
off_x = (W - span_x * scale) / 2
off_y = H * MARGIN_Y
m_per_px = 110574.0 / scale

def project(lat, lng):
    return off_x + (lng - LNG_MIN) * KX * scale, off_y + (LAT_MAX - lat) * scale

img = Image.open('assets/images/taiwan_overworld.png')
arr = np.array(img)
is_land = ~np.all(arr == [30, 111, 159], axis=-1)

tile_full_land = np.zeros((72, 128), dtype=bool)
for ty in range(72):
    for tx in range(128):
        tile_full_land[ty, tx] = np.all(is_land[ty*16:(ty+1)*16, tx*16:(tx+1)*16])

WEST_CORRIDOR_GPS = [
    ('Keelung (台1線基隆八堵段)', 25.105, 121.730),
    ('Taipei Xinyi (信義快速道路/基隆路口)', 25.038, 121.558),
    ('Taipei Wanhua (台1線台北和平西路段)', 25.033, 121.500),
    ('Taoyuan (台1線桃園中壢段)', 24.970, 121.205),
    ('Hsinchu (台1線新竹公道五路口)', 24.802, 120.997),
    ('Miaoli (台1線苗栗公館段)', 24.535, 120.825),
    ('Taichung Dajia River (台1線大甲溪橋)', 24.310, 120.575),
    ('Taichung Chaoma (朝馬路口/台灣大道)', 24.167, 120.635),
    ('Changhua Junction (台1線彰化花壇段)', 24.030, 120.540),
    ('Yunlin Xiluo (西螺大橋南端)', 23.805, 120.460),
    ('Chiayi (台1線嘉義民雄段)', 23.510, 120.435),
    ('Tainan (台1線台南永康段)', 23.030, 120.240),
    ('Kaohsiung Sanduo (三多商圈/中山二路)', 22.614, 120.306),
    ('Pingtung (台1線高屏大橋屏東端)', 22.670, 120.485),
    ('Fangliao (台1線佳冬枋寮段)', 22.368, 120.640),
    ('Hengchun (台26線恆春段)', 22.000, 120.745),
]

SML_CORRIDOR_GPS = [
    ('Changhua Junction (台1線/台14線交會點)', 24.030, 120.540),
    ('Caotun (台14線草屯段)', 23.980, 120.690),
    ('Guoxing (台14線國姓柑林段)', 23.985, 120.850),
    ('Puli (台14線/台21線交會點)', 23.965, 120.965),
    ('Yuchih (台21線魚池段)', 23.898, 120.935),
    ('Sun Moon Lake North (台21線日月潭水社碼頭段)', 23.868, 120.912),
]

def bfs_path(start, goal):
    if start == goal:
        return [start]
    q = deque([start])
    visited = {start: None}
    while q:
        curr = q.popleft()
        if curr == goal:
            break
        cx, cy = curr
        # 4-connected neighbors
        for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < 128 and 0 <= ny < 72:
                if tile_full_land[ny, nx] and (nx, ny) not in visited:
                    visited[(nx, ny)] = curr
                    q.append((nx, ny))
    
    if goal not in visited:
        raise ValueError(f"No path between {start} and {goal}!")
    
    path = []
    curr = goal
    while curr is not None:
        path.append(curr)
        curr = visited[curr]
    path.reverse()
    return path

# Route West Corridor
west_tiles = []
for i in range(len(WEST_CORRIDOR_GPS) - 1):
    p1 = project(WEST_CORRIDOR_GPS[i][1], WEST_CORRIDOR_GPS[i][2])
    p2 = project(WEST_CORRIDOR_GPS[i+1][1], WEST_CORRIDOR_GPS[i+1][2])
    t1 = (int(round(p1[0] / 16)), int(round(p1[1] / 16)))
    t2 = (int(round(p2[0] / 16)), int(round(p2[1] / 16)))
    sub_path = bfs_path(t1, t2)
    if not west_tiles:
        west_tiles.extend(sub_path)
    else:
        west_tiles.extend(sub_path[1:])

# Route SML Corridor
sml_tiles = []
for i in range(len(SML_CORRIDOR_GPS) - 1):
    p1 = project(SML_CORRIDOR_GPS[i][1], SML_CORRIDOR_GPS[i][2])
    p2 = project(SML_CORRIDOR_GPS[i+1][1], SML_CORRIDOR_GPS[i+1][2])
    t1 = (int(round(p1[0] / 16)), int(round(p1[1] / 16)))
    t2 = (int(round(p2[0] / 16)), int(round(p2[1] / 16)))
    sub_path = bfs_path(t1, t2)
    if not sml_tiles:
        sml_tiles.extend(sub_path)
    else:
        sml_tiles.extend(sub_path[1:])

print(f"West Corridor route: {len(west_tiles)} 4-connected tiles")
print(f"SML Corridor route:  {len(sml_tiles)} 4-connected tiles")

# Check 4-connected property
for p in [west_tiles, sml_tiles]:
    for j in range(len(p) - 1):
        d = abs(p[j+1][0] - p[j][0]) + abs(p[j+1][1] - p[j][1])
        assert d == 1, f"Disconnected step: {p[j]} -> {p[j+1]}"

print("All road segments are strictly 4-connected (no diagonal disconnects)!")
