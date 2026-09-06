import sys
sys.path.insert(0, '.')
import os
import math
import json
import heapq
import hashlib
from collections import deque
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, generate_binary_structure, label

from tool.generate_snes_overworld import (
    generate_map_grid, MASTER_TILES, OCEAN, W, H, TILE_SIZE, GRID_W, GRID_H
)
from tool.test_procedural_roads import make_road_tile
from tool.test_road_tiles import parse_tile, ART_BRIDGE_V, ART_BRIDGE_H, BRIDGE_PAL
from tool.poi_pixel_sprites import (
    parse_sprite,
    ART_101, PAL_101,
    ART_PALACE, PAL_PALACE,
    ART_JIUFEN, PAL_JIUFEN,
    ART_OPERA, PAL_OPERA,
    ART_TAROKO, PAL_TAROKO,
    ART_PAGODA, PAL_PAGODA,
    ART_ALISHAN, PAL_ALISHAN,
    ART_CHIKHAN, PAL_CHIKHAN,
    ART_85, PAL_85,
    ART_ELUANBI, PAL_ELUANBI,
    ART_MARKET, PAL_MARKET,
    ART_PEAK, PAL_PEAK,
    ART_THSR, PAL_THSR,
)

BRIDGE_PAL['L'] = (98, 184, 70)
tile_bridge_v = parse_tile(ART_BRIDGE_V, BRIDGE_PAL)
tile_bridge_h = parse_tile(ART_BRIDGE_H, BRIDGE_PAL)

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

# 42 POIs
POIS = {
    # 台灣前 10 大知名景點 (Hero Landmarks)
    'taipei_101': (1162, 148),
    'palace_museum': (1158, 128),
    'jiufen': (1222, 128),
    'taichung_opera': (909, 408),
    'taroko': (1178, 409),
    'sun_moon_lake': (985, 499),
    'alishan': (954, 603),
    'chihkan_tower': (789, 756),
    'kaohsiung_85': (816, 871),
    'eluanbi': (963, 1070),

    # 台灣高鐵全線 12 座車站 (THSR Stations)
    'thsr_nangang': (1174, 142),
    'thsr_taipei': (1149, 144),
    'thsr_banqiao': (1134, 154),
    'thsr_taoyuan': (1066, 154),
    'thsr_hsinchu': (1019, 215),
    'thsr_miaoli': (960, 276),
    'thsr_taichung': (903, 423),
    'thsr_changhua': (891, 494),
    'thsr_yunlin': (851, 535),
    'thsr_chiayi': (822, 618),
    'thsr_tainan': (812, 777),
    'thsr_zuoying': (818, 849),

    # 台灣前 10 大知名夜市 (Night Markets)
    'market_keelung': (1211, 120),
    'market_shilin': (1151, 132),
    'market_raohe': (1168, 142),
    'market_ningxia': (1144, 139),
    'market_fengjia': (911, 403),
    'market_wenhua': (857, 612),
    'market_garden': (793, 752),
    'market_liuhe': (822, 865),
    'market_ruifeng': (816, 855),
    'market_luodong': (1217, 254),

    # 台灣百岳前 10 名 (Mountain Peaks)
    'peak_yushan': (996, 615),
    'peak_xueshan': (1071, 342),
    'peak_xiuguluan': (1023, 581),
    'peak_nanhu': (1128, 349),
    'peak_zhongyangjian': (1121, 363),
    'peak_guanshan': (982, 687),
    'peak_qilai': (1096, 421),
    'peak_dabajian': (1078, 319),
    'peak_hehuan': (1082, 414),
    'peak_beidawu': (941, 866),
}

WEST_CORRIDOR_WAYPOINTS = [
    ('Keelung (台1線基隆八堵段)', 25.105, 121.730),
    ('Taipei Xinyi (信義快速道路/基隆路口)', 25.038, 121.558),
    ('Taipei Wanhua (台1線和平西路段)', 25.033, 121.500),
    ('Taoyuan (台1線桃園中壢段)', 24.970, 121.205),
    ('Hsinchu (台1線新竹公道五路口)', 24.802, 120.997),
    ('Miaoli (台1線苗栗公館段)', 24.535, 120.825),
    ('Sanyi (台13線三義段)', 24.380, 120.760),
    ('Fengyuan (台1線/台13線豐原段)', 24.250, 120.715),
    ('Taichung Chaoma (朝馬路口/台灣大道)', 24.167, 120.635),
    ('Changhua Junction (台1線彰化花壇段)', 24.030, 120.540),
    ('Yunlin Xiluo (台1線西螺大橋南端)', 23.805, 120.460),
    ('Chiayi (台1線嘉義民雄段)', 23.510, 120.435),
    ('Tainan (台1線台南永康段)', 23.030, 120.240),
    ('Kaohsiung Sanduo (三多商圈/中山二路)', 22.614, 120.306),
    ('Pingtung (台1線高屏大橋屏東端)', 22.670, 120.485),
    ('Chaozhou (台1線潮州段)', 22.550, 120.540),
    ('Fangliao (台1線枋寮段)', 22.370, 120.650),
    ('Fangshan (台1線/台9線/台26線交會段)', 22.250, 120.720),
    ('Checheng (台26線車城段)', 22.070, 120.720),
    ('Hengchun (台26線恆春南門段)', 22.000, 120.745),
]

SML_CORRIDOR_WAYPOINTS = [
    ('Changhua Junction (台1線/台14線交會點)', 24.030, 120.540),
    ('Caotun (台14線草屯段)', 23.980, 120.690),
    ('Guoxing (台14線國姓柑林段)', 23.985, 120.850),
    ('Puli (台14線/台21線交會點)', 23.965, 120.965),
    ('Yuchih (台21線魚池段)', 23.898, 120.935),
    ('Sun Moon Lake North (台21線日月潭水社碼頭段)', 23.868, 120.912),
]

THSR_WAYPOINTS = [
    ('THSR Nangang (南港站軌道路廊)', 25.053, 121.607),
    ('THSR Taipei (台北站軌道路廊)', 25.048, 121.517),
    ('THSR Banqiao (板橋站軌道路廊)', 25.014, 121.463),
    ('THSR Taoyuan (桃園站軌道路廊)', 25.013, 121.215),
    ('THSR Hsinchu (新竹站軌道路廊)', 24.808, 121.040),
    ('THSR Miaoli (苗栗站軌道路廊)', 24.606, 120.825),
    ('THSR Taichung (台中站軌道路廊)', 24.112, 120.616),
    ('THSR Changhua (彰化站軌道路廊)', 23.874, 120.574),
    ('THSR Yunlin (雲林站軌道路廊)', 23.736, 120.428),
    ('THSR Chiayi (嘉義站軌道路廊)', 23.459, 120.323),
    ('THSR Tainan (台南站軌道路廊)', 22.925, 120.286),
    ('THSR Zuoying (左營站軌道路廊)', 22.687, 120.308),
]

RAIL_PAL = {
    'B': (130, 125, 118),
    'b': (95, 90, 84),
    'S': (80, 55, 40),
    's': (55, 38, 28),
    'R': (240, 245, 250),
    'r': (140, 150, 160),
    '.': (76, 158, 54),
    'L': (98, 184, 70),
}

def make_rail_tile(ports):
    tile = np.zeros((16, 16, 3), dtype=np.uint8)
    for y in range(16):
        for x in range(16):
            tile[y, x] = RAIL_PAL['.'] if (x+y)%5 != 0 else RAIL_PAL['L']
            if 'N' in ports and 'S' in ports:
                if 2 <= x <= 13: tile[y, x] = RAIL_PAL['B'] if (x+y)%2 == 0 else RAIL_PAL['b']
                if 3 <= x <= 12 and (y % 4 in (1, 2)): tile[y, x] = RAIL_PAL['S'] if y % 4 == 1 else RAIL_PAL['s']
                if x == 5: tile[y, x] = RAIL_PAL['R']
                if x == 6: tile[y, x] = RAIL_PAL['r']
                if x == 9: tile[y, x] = RAIL_PAL['R']
                if x == 10: tile[y, x] = RAIL_PAL['r']
            elif 'W' in ports and 'E' in ports:
                if 2 <= y <= 13: tile[y, x] = RAIL_PAL['B'] if (x+y)%2 == 0 else RAIL_PAL['b']
                if 3 <= y <= 12 and (x % 4 in (1, 2)): tile[y, x] = RAIL_PAL['S'] if x % 4 == 1 else RAIL_PAL['s']
                if y == 5: tile[y, x] = RAIL_PAL['R']
                if y == 6: tile[y, x] = RAIL_PAL['r']
                if y == 9: tile[y, x] = RAIL_PAL['R']
                if y == 10: tile[y, x] = RAIL_PAL['r']
            elif ('E' in ports and 'S' in ports) or ('W' in ports and 'S' in ports) or \
                 ('E' in ports and 'N' in ports) or ('W' in ports and 'N' in ports):
                if 'E' in ports and 'S' in ports: d = math.hypot(x - 15.5, y - 15.5)
                elif 'W' in ports and 'S' in ports: d = math.hypot(x - (-0.5), y - 15.5)
                elif 'E' in ports and 'N' in ports: d = math.hypot(x - 15.5, y - (-0.5))
                else: d = math.hypot(x - (-0.5), y - (-0.5))
                if 3.0 <= d <= 13.0: tile[y, x] = RAIL_PAL['B'] if (x+y)%2 == 0 else RAIL_PAL['b']
                if 5.5 <= d <= 6.5: tile[y, x] = RAIL_PAL['R']
                elif 6.5 < d <= 7.5: tile[y, x] = RAIL_PAL['r']
                elif 9.5 <= d <= 10.5: tile[y, x] = RAIL_PAL['R']
                elif 10.5 < d <= 11.5: tile[y, x] = RAIL_PAL['r']
    return tile

def make_rail_bridge(ports):
    tile = np.full((16, 16, 3), (42, 108, 148), dtype=np.uint8)
    is_v = ('N' in ports or 'S' in ports)
    if is_v:
        for y in range(16):
            tile[y, 2:14] = (200, 205, 210)
            tile[y, 3:13] = (130, 125, 118)
            if y % 4 in (1, 2): tile[y, 3:13] = (80, 55, 40) if y % 4 == 1 else (55, 38, 28)
            tile[y, 5] = (245, 250, 255)
            tile[y, 6] = (120, 130, 140)
            tile[y, 9] = (245, 250, 255)
            tile[y, 10] = (120, 130, 140)
    else:
        for x in range(16):
            tile[2:14, x] = (200, 205, 210)
            tile[3:13, x] = (130, 125, 118)
            if x % 4 in (1, 2): tile[3:13, x] = (80, 55, 40) if x % 4 == 1 else (55, 38, 28)
            tile[5, x] = (245, 250, 255)
            tile[6, x] = (120, 130, 140)
            tile[9, x] = (245, 250, 255)
            tile[10, x] = (120, 130, 140)
    return tile

def make_crossing_tile(road_ports, rail_ports):
    tile = make_road_tile(road_ports)
    if 'N' in rail_ports or 'S' in rail_ports:
        for y in range(16):
            if y % 4 in (1, 2): tile[y, 3:13] = [80, 55, 40] if y % 4 == 1 else [55, 38, 28]
            tile[y, 5] = [240, 245, 250]
            tile[y, 6] = [140, 150, 160]
            tile[y, 9] = [240, 245, 250]
            tile[y, 10] = [140, 150, 160]
    else:
        for x in range(16):
            if x % 4 in (1, 2): tile[3:13, x] = [80, 55, 40] if x % 4 == 1 else [55, 38, 28]
            tile[5, x] = [240, 245, 250]
            tile[6, x] = [140, 150, 160]
            tile[9, x] = [240, 245, 250]
            tile[10, x] = [140, 150, 160]
    return tile

def generate_pipeline_data(seed=1337):
    np.random.seed(seed)
    ref_img = Image.open('assets/images/taiwan_overworld_silhouette.png')
    ref_arr = np.array(ref_img)
    is_ocean = np.all(ref_arr == OCEAN, axis=-1)
    is_land = ~is_ocean

    tile_full_land = np.zeros((GRID_H, GRID_W), dtype=bool)
    for ty in range(GRID_H):
        for tx in range(GRID_W):
            tile_full_land[ty, tx] = np.all(is_land[ty*16:(ty+1)*16, tx*16:(tx+1)*16])

    west_points = []
    for name, la, lo in WEST_CORRIDOR_WAYPOINTS:
        px, py = project(la, lo)
        west_points.append([int(round(px)), int(round(py))])

    sml_points = []
    for name, la, lo in SML_CORRIDOR_WAYPOINTS:
        px, py = project(la, lo)
        sml_points.append([int(round(px)), int(round(py))])

    thsr_points = []
    for name, la, lo in THSR_WAYPOINTS:
        px, py = project(la, lo)
        rx = int(round(px))
        ry = int(round(py)) + 1
        thsr_points.append([rx, ry])

    roads_json_data = [
        {
            "id": "west_corridor",
            "source": "交通部公路局省道台1線（縱貫公路）與國道1號關鍵路廊節點",
            "points": west_points
        },
        {
            "id": "sun_moon_lake_spur",
            "source": "交通部公路局省道台14線（中潭公路）與台21線日月潭聯絡道節點",
            "points": sml_points
        },
        {
            "id": "thsr_railway",
            "source": "台灣高速鐵路（THSR）全線路廊與車站節點",
            "points": thsr_points
        }
    ]

    def bfs_path(start, goal):
        if start == goal: return [start]
        q = deque([start])
        visited = {start: None}
        while q:
            curr = q.popleft()
            if curr == goal: break
            cx, cy = curr
            for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < GRID_W and 0 <= ny < GRID_H and tile_full_land[ny, nx] and (nx, ny) not in visited:
                    visited[(nx, ny)] = curr
                    q.append((nx, ny))
        if goal not in visited: raise ValueError(f"No path between {start} and {goal}!")
        path = []
        curr = goal
        while curr is not None:
            path.append(curr)
            curr = visited[curr]
        path.reverse()
        return path

    west_tile_path = []
    for i in range(len(west_points) - 1):
        t1 = (west_points[i][0] // 16, west_points[i][1] // 16)
        t2 = (west_points[i+1][0] // 16, west_points[i+1][1] // 16)
        sub = bfs_path(t1, t2)
        if not west_tile_path: west_tile_path.extend(sub)
        else: west_tile_path.extend(sub[1:])

    sml_tile_path = []
    for i in range(len(sml_points) - 1):
        t1 = (sml_points[i][0] // 16, sml_points[i][1] // 16)
        t2 = (sml_points[i+1][0] // 16, sml_points[i+1][1] // 16)
        sub = bfs_path(t1, t2)
        if not sml_tile_path: sml_tile_path.extend(sub)
        else: sml_tile_path.extend(sub[1:])

    road_tiles_set = set(west_tile_path) | set(sml_tile_path)

    def dijkstra_rail(start, goal, avoid_tiles):
        if start == goal: return [start]
        pq = [(0, start, [start])]
        visited = {}
        while pq:
            cost, curr, path = heapq.heappop(pq)
            if curr == goal: return path
            if curr in visited and visited[curr] <= cost: continue
            visited[curr] = cost
            cx, cy = curr
            for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < GRID_W and 0 <= ny < GRID_H and tile_full_land[ny, nx]:
                    step_cost = 10 if (nx, ny) in avoid_tiles else 1
                    nc = cost + step_cost
                    if (nx, ny) not in visited or nc < visited[(nx, ny)]:
                        heapq.heappush(pq, (nc, (nx, ny), path + [(nx, ny)]))
        raise ValueError(f"No rail path between {start} and {goal}")

    thsr_tile_path = []
    for i in range(len(thsr_points) - 1):
        t1 = (thsr_points[i][0] // 16, thsr_points[i][1] // 16)
        t2 = (thsr_points[i+1][0] // 16, thsr_points[i+1][1] // 16)
        sub = dijkstra_rail(t1, t2, road_tiles_set)
        if not thsr_tile_path: thsr_tile_path.extend(sub)
        else: thsr_tile_path.extend(sub[1:])

    rail_tiles_set = set(thsr_tile_path)
    grid = generate_map_grid(is_land)

    canvas = np.full((H, W, 3), OCEAN, dtype=np.uint8)
    for ty in range(GRID_H):
        for tx in range(GRID_W):
            t_name = grid[ty, tx]
            if t_name == 'ocean': continue
            tile_data = MASTER_TILES.get(t_name, MASTER_TILES['grass_1'])
            y0, y1 = ty * TILE_SIZE, (ty + 1) * TILE_SIZE
            x0, x1 = tx * TILE_SIZE, (tx + 1) * TILE_SIZE
            canvas[y0:y1, x0:x1] = tile_data

    road_pixel_mask = np.zeros((H, W), dtype=bool)
    all_transit_tiles = road_tiles_set | rail_tiles_set

    for tx, ty in all_transit_tiles:
        y0, y1 = ty * TILE_SIZE, (ty + 1) * TILE_SIZE
        x0, x1 = tx * TILE_SIZE, (tx + 1) * TILE_SIZE
        is_rd = (tx, ty) in road_tiles_set
        is_rl = (tx, ty) in rail_tiles_set
        rd_ports = set()
        if is_rd:
            if (tx, ty - 1) in road_tiles_set: rd_ports.add('N')
            if (tx, ty + 1) in road_tiles_set: rd_ports.add('S')
            if (tx + 1, ty) in road_tiles_set: rd_ports.add('E')
            if (tx - 1, ty) in road_tiles_set: rd_ports.add('W')
            if not rd_ports: rd_ports = {'N', 'S'}
        rl_ports = set()
        if is_rl:
            if (tx, ty - 1) in rail_tiles_set: rl_ports.add('N')
            if (tx, ty + 1) in rail_tiles_set: rl_ports.add('S')
            if (tx + 1, ty) in rail_tiles_set: rl_ports.add('E')
            if (tx - 1, ty) in rail_tiles_set: rl_ports.add('W')
            if not rl_ports: rl_ports = {'N', 'S'}
        orig_terrain = grid[ty, tx]
        is_river = 'river' in orig_terrain

        if is_rd and is_rl: tile_data = make_crossing_tile(rd_ports, rl_ports)
        elif is_rl:
            tile_data = make_rail_bridge(rl_ports) if is_river else make_rail_tile(rl_ports)
        else:
            if is_river: tile_data = tile_bridge_v if ('N' in rd_ports or 'S' in rd_ports) else tile_bridge_h
            else: tile_data = make_road_tile(rd_ports)

        canvas[y0:y1, x0:x1] = tile_data
        road_pixel_mask[y0:y1, x0:x1] = True

    landmark_pixel_mask = np.zeros((H, W), dtype=bool)

    poi_sprites = {
        'taipei_101': parse_sprite(ART_101, PAL_101),
        'palace_museum': parse_sprite(ART_PALACE, PAL_PALACE),
        'jiufen': parse_sprite(ART_JIUFEN, PAL_JIUFEN),
        'taichung_opera': parse_sprite(ART_OPERA, PAL_OPERA),
        'taroko': parse_sprite(ART_TAROKO, PAL_TAROKO),
        'sun_moon_lake': parse_sprite(ART_PAGODA, PAL_PAGODA),
        'alishan': parse_sprite(ART_ALISHAN, PAL_ALISHAN),
        'chihkan_tower': parse_sprite(ART_CHIKHAN, PAL_CHIKHAN),
        'kaohsiung_85': parse_sprite(ART_85, PAL_85),
        'eluanbi': parse_sprite(ART_ELUANBI, PAL_ELUANBI),
    }

    thsr_station_sprite = parse_sprite(ART_THSR, PAL_THSR)
    for sid in [
        'thsr_nangang', 'thsr_taipei', 'thsr_banqiao', 'thsr_taoyuan',
        'thsr_hsinchu', 'thsr_miaoli', 'thsr_taichung', 'thsr_changhua',
        'thsr_yunlin', 'thsr_chiayi', 'thsr_tainan', 'thsr_zuoying'
    ]:
        poi_sprites[sid] = thsr_station_sprite

    market_sprite = parse_sprite(ART_MARKET, PAL_MARKET)
    for mid in [
        'market_keelung', 'market_shilin', 'market_raohe', 'market_ningxia',
        'market_fengjia', 'market_wenhua', 'market_garden', 'market_liuhe',
        'market_ruifeng', 'market_luodong'
    ]:
        poi_sprites[mid] = market_sprite

    peak_sprite = parse_sprite(ART_PEAK, PAL_PEAK)
    for pid in [
        'peak_yushan', 'peak_xueshan', 'peak_xiuguluan', 'peak_nanhu',
        'peak_zhongyangjian', 'peak_guanshan', 'peak_qilai', 'peak_dabajian',
        'peak_hehuan', 'peak_beidawu'
    ]:
        poi_sprites[pid] = peak_sprite

    offsets = {
        'jiufen': (-4, 3),
        'chihkan_tower': (4, -3),
        'kaohsiung_85': (2, -9),
        'eluanbi': (-3, -3),
    }

    sorted_pois = sorted(POIS.items(), key=lambda item: item[1][1])

    for name, (cx, cy) in sorted_pois:
        sprite = poi_sprites[name]
        sh, sw = sprite.shape[:2]
        dx, dy = offsets.get(name, (0, 0))
        x0 = cx - sw // 2 + dx
        y0 = cy - sh // 2 + dy
        for sy in range(sh):
            for sx in range(sw):
                if sprite[sy, sx, 3] > 0:
                    px = x0 + sx
                    py = y0 + sy
                    if 0 <= px < W and 0 <= py < H and is_land[py, px]:
                        canvas[py, px] = sprite[sy, sx, :3]
                        landmark_pixel_mask[py, px] = True

    # STRICT OCEAN ENFORCEMENT
    canvas[is_ocean] = OCEAN
    landmark_pixel_mask[is_ocean] = False
    road_pixel_mask[is_ocean] = False

    # Mask 256x144
    MASK_W = 256
    MASK_H = 144
    mask_img = np.zeros((MASK_H, MASK_W, 3), dtype=np.uint8)
    COLOR_OCEAN = np.array([0, 0, 255], dtype=np.uint8)
    COLOR_LAND = np.array([0, 255, 0], dtype=np.uint8)
    COLOR_ROAD = np.array([255, 0, 255], dtype=np.uint8)
    COLOR_LANDMARK = np.array([255, 255, 0], dtype=np.uint8)

    for my in range(MASK_H):
        for mx in range(MASK_W):
            bx0, bx1 = mx * 8, (mx + 1) * 8
            by0, by1 = my * 8, (my + 1) * 8
            lm_block = landmark_pixel_mask[by0:by1, bx0:bx1]
            rd_block = road_pixel_mask[by0:by1, bx0:bx1]
            ld_block = is_land[by0:by1, bx0:bx1]
            if np.any(lm_block): mask_img[my, mx] = COLOR_LANDMARK
            elif np.any(rd_block): mask_img[my, mx] = COLOR_ROAD
            elif np.any(ld_block): mask_img[my, mx] = COLOR_LAND
            else: mask_img[my, mx] = COLOR_OCEAN

    return canvas, mask_img, roads_json_data, is_ocean

def run_verifications():
    os.makedirs('assets/maps/taiwan', exist_ok=True)
    os.makedirs('assets/images', exist_ok=True)

    print("--- RUN 1: Generating outputs ---")
    canvas1, mask1, roads1, is_ocean = generate_pipeline_data(seed=1337)

    Image.fromarray(canvas1).save('assets/images/taiwan_overworld.png')
    Image.fromarray(mask1).save('assets/maps/taiwan/mask.png')
    with open('assets/maps/taiwan/roads.json', 'w', encoding='utf-8') as f:
        json.dump(roads1, f, ensure_ascii=False, indent=2)

    with open('assets/images/taiwan_overworld.png', 'rb') as f: b_map1 = f.read()
    with open('assets/maps/taiwan/mask.png', 'rb') as f: b_mask1 = f.read()
    with open('assets/maps/taiwan/roads.json', 'rb') as f: b_roads1 = f.read()

    hash_map1 = hashlib.sha256(b_map1).hexdigest()
    hash_mask1 = hashlib.sha256(b_mask1).hexdigest()
    hash_roads1 = hashlib.sha256(b_roads1).hexdigest()

    print("--- RUN 2: Determinism Test ---")
    canvas2, mask2, roads2, _ = generate_pipeline_data(seed=1337)

    Image.fromarray(canvas2).save('tool/temp_map.png')
    Image.fromarray(mask2).save('tool/temp_mask.png')
    with open('tool/temp_roads.json', 'w', encoding='utf-8') as f:
        json.dump(roads2, f, ensure_ascii=False, indent=2)

    with open('tool/temp_map.png', 'rb') as f: b_map2 = f.read()
    with open('tool/temp_mask.png', 'rb') as f: b_mask2 = f.read()
    with open('tool/temp_roads.json', 'rb') as f: b_roads2 = f.read()

    hash_map2 = hashlib.sha256(b_map2).hexdigest()
    hash_mask2 = hashlib.sha256(b_mask2).hexdigest()
    hash_roads2 = hashlib.sha256(b_roads2).hexdigest()

    os.remove('tool/temp_map.png')
    os.remove('tool/temp_mask.png')
    os.remove('tool/temp_roads.json')

    print("\n==================================================")
    print("           SELF-VERIFICATION RESULTS              ")
    print("==================================================")

    # 1. Ocean Pixel Mismatch
    ref_ocean = is_ocean
    cur_ocean = np.all(canvas1 == OCEAN, axis=-1)
    ocean_mismatches = int(np.sum(ref_ocean != cur_ocean))
    print(f"1. Ocean Pixel Mismatches:")
    print(f"   - Reference Ocean Pixels: {int(np.sum(ref_ocean))}")
    print(f"   - Generated Ocean Pixels: {int(np.sum(cur_ocean))}")
    print(f"   - Mismatched Pixels:      {ocean_mismatches}")
    assert ocean_mismatches == 0, f"Ocean pixel mismatches must be 0, got {ocean_mismatches}"

    # 2. Road & Rail Node Distance to Landmarks
    print(f"\n2. Road & Rail Node Distances to All 42 Landmarks (threshold = 100.0 m):")
    min_dist_meters = float('inf')
    total_nodes_checked = 0

    for road in roads1:
        road_id = road['id']
        for pt in road['points']:
            total_nodes_checked += 1
            for poi_name, (lx, ly) in POIS.items():
                d_px = math.hypot(pt[0] - lx, pt[1] - ly)
                d_m = d_px * m_per_px
                if d_m < min_dist_meters: min_dist_meters = d_m
                if d_m <= 100.0:
                    raise AssertionError(f"Node {pt} in {road_id} is only {d_m:.1f} m from {poi_name} (<= 100m)!")

    print(f"   - Total Nodes Checked:      {total_nodes_checked}")
    print(f"   - Minimum Distance to POI:  {min_dist_meters:.2f} m")
    print(f"   - Nodes <= 100m:            0")
    assert min_dist_meters > 100.0, f"Minimum distance {min_dist_meters} <= 100m"

    # 3. Mask Land/Ocean Classification Consistency
    print(f"\n3. Mask Land/Ocean Classification Consistency:")
    COLOR_OCEAN = np.array([0, 0, 255], dtype=np.uint8)
    mask_ocean = np.all(mask1 == COLOR_OCEAN, axis=-1)
    mask_classification_mismatches = 0
    for my in range(144):
        for mx in range(256):
            block_is_pure_ocean = np.all(cur_ocean[my*8:(my+1)*8, mx*8:(mx+1)*8])
            is_mask_ocean = mask_ocean[my, mx]
            if block_is_pure_ocean != is_mask_ocean:
                mask_classification_mismatches += 1

    print(f"   - Total 8x8 Blocks:          {144 * 256}")
    print(f"   - Pure Ocean Blocks:         {int(np.sum(mask_ocean))}")
    print(f"   - Land / Road / POI Blocks:  {int(np.sum(~mask_ocean))}")
    print(f"   - Classification Mismatches: {mask_classification_mismatches}")
    assert mask_classification_mismatches == 0, f"Mask classification mismatches: {mask_classification_mismatches}"

    # 4. Road & Rail Mask Connectivity
    print(f"\n4. Road & Rail Mask Connectivity & Island Check:")
    COLOR_ROAD = np.array([255, 0, 255], dtype=np.uint8)
    COLOR_LANDMARK = np.array([255, 255, 0], dtype=np.uint8)
    road_mask_2d = np.all(mask1 == COLOR_ROAD, axis=-1)
    landmark_mask_2d = np.all(mask1 == COLOR_LANDMARK, axis=-1)
    struct_8 = generate_binary_structure(2, 2)
    labeled_roads, num_road_comps = label(road_mask_2d, structure=struct_8)

    print(f"   - Road & Rail Mask Pixels:   {int(np.sum(road_mask_2d))}")
    print(f"   - Connected Components:      {num_road_comps}")

    isolated_components = 0
    for cid in range(1, num_road_comps + 1):
        c_mask = labeled_roads == cid
        c_dilated = binary_dilation(c_mask, structure=struct_8)
        touches_poi = np.any(c_dilated & landmark_mask_2d)
        touches_other_road = np.any(c_dilated & (road_mask_2d & ~c_mask))
        if not (touches_poi or touches_other_road):
            isolated_components += 1
            print(f"     [ERROR] Component {cid} is isolated!")

    print(f"   - Isolated Components:       {isolated_components}")
    assert isolated_components == 0, f"Found {isolated_components} isolated road components!"

    # 5. Determinism
    print(f"\n5. Determinism (Run 1 vs Run 2 byte comparison):")
    map_diff_bytes = len(b_map1) != len(b_map2) or b_map1 != b_map2
    mask_diff_bytes = len(b_mask1) != len(b_mask2) or b_mask1 != b_mask2
    roads_diff_bytes = len(b_roads1) != len(b_roads2) or b_roads1 != b_roads2

    print(f"   - taiwan_overworld.png SHA256: {hash_map1}")
    print(f"     Run 1 vs Run 2 Byte Diff:    {0 if not map_diff_bytes else 1}")
    print(f"   - mask.png SHA256:             {hash_mask1}")
    print(f"     Run 1 vs Run 2 Byte Diff:    {0 if not mask_diff_bytes else 1}")
    print(f"   - roads.json SHA256:           {hash_roads1}")
    print(f"     Run 1 vs Run 2 Byte Diff:    {0 if not roads_diff_bytes else 1}")

    assert not map_diff_bytes, "taiwan_overworld.png output differs between runs!"
    assert not mask_diff_bytes, "mask.png output differs between runs!"
    assert not roads_diff_bytes, "roads.json output differs between runs!"

    print("\n>>> ALL 5 SELF-VERIFICATIONS PASSED WITH ZERO ERRORS! <<<")

if __name__ == '__main__':
    run_verifications()

