import sys
sys.path.insert(0, '.')
import os
import math
import json
import hashlib
from collections import deque
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, generate_binary_structure, label

from tool.generate_snes_overworld import (
    generate_map_grid, MASTER_TILES, OCEAN, W, H, TILE_SIZE, GRID_W, GRID_H
)
from tool.test_poi_sprites import (
    parse_sprite, ART_101, PAL_101, ART_OPERA, PAL_OPERA, ART_PAGODA, PAL_PAGODA, ART_85, PAL_85
)
from tool.test_procedural_roads import make_road_tile
from tool.test_road_tiles import parse_tile, ART_BRIDGE_V, ART_BRIDGE_H, BRIDGE_PAL

# Add L to BRIDGE_PAL
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

POIS = {
    'taipei_101': (1162, 148),
    'taichung_opera': (909, 408),
    'sun_moon_lake': (985, 499),
    'kaohsiung_85': (816, 871),
}

# 1. Real GPS Waypoints with citations
# Source: 交通部公路局（MOTC Highway Bureau）省道台1線（縱貫公路）與國道1號關鍵交流道節點
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

# Source: 交通部公路局（MOTC Highway Bureau）省道台14線（中潭公路）與台21線節點
SML_CORRIDOR_WAYPOINTS = [
    ('Changhua Junction (台1線/台14線交會點)', 24.030, 120.540),
    ('Caotun (台14線草屯段)', 23.980, 120.690),
    ('Guoxing (台14線國姓柑林段)', 23.985, 120.850),
    ('Puli (台14線/台21線交會點)', 23.965, 120.965),
    ('Yuchih (台21線魚池段)', 23.898, 120.935),
    ('Sun Moon Lake North (台21線日月潭水社碼頭段)', 23.868, 120.912),
]

print("Setup completed successfully!")

def generate_pipeline_data(seed=1337):
    # Deterministic random seed
    np.random.seed(seed)

    # 1. Load exact reference silhouette
    ref_img = Image.open('assets/images/taiwan_overworld_silhouette.png')
    ref_arr = np.array(ref_img)
    is_ocean = np.all(ref_arr == OCEAN, axis=-1)
    is_land = ~is_ocean

    # Full land 16x16 tiles
    tile_full_land = np.zeros((GRID_H, GRID_W), dtype=bool)
    for ty in range(GRID_H):
        for tx in range(GRID_W):
            tile_full_land[ty, tx] = np.all(is_land[ty*16:(ty+1)*16, tx*16:(tx+1)*16])

    # 2. Roads polyline data (roads.json)
    # Projected from real GPS waypoints
    west_points = []
    for name, la, lo in WEST_CORRIDOR_WAYPOINTS:
        px, py = project(la, lo)
        west_points.append([int(round(px)), int(round(py))])

    sml_points = []
    for name, la, lo in SML_CORRIDOR_WAYPOINTS:
        px, py = project(la, lo)
        sml_points.append([int(round(px)), int(round(py))])

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
        }
    ]

    # 3. 4-connected routing on 16x16 tile grid
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
            for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < GRID_W and 0 <= ny < GRID_H:
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

    west_tile_path = []
    for i in range(len(west_points) - 1):
        t1 = (west_points[i][0] // 16, west_points[i][1] // 16)
        t2 = (west_points[i+1][0] // 16, west_points[i+1][1] // 16)
        sub = bfs_path(t1, t2)
        if not west_tile_path:
            west_tile_path.extend(sub)
        else:
            west_tile_path.extend(sub[1:])

    sml_tile_path = []
    for i in range(len(sml_points) - 1):
        t1 = (sml_points[i][0] // 16, sml_points[i][1] // 16)
        t2 = (sml_points[i+1][0] // 16, sml_points[i+1][1] // 16)
        sub = bfs_path(t1, t2)
        if not sml_tile_path:
            sml_tile_path.extend(sub)
        else:
            sml_tile_path.extend(sub[1:])

    # 4. Generate base terrain grid
    grid = generate_map_grid(is_land)

    # 5. Determine road tiles and bridge tiles
    # Identify adjacent road neighbors for each road tile to choose the correct road/bridge tile
    all_road_tiles = set(west_tile_path) | set(sml_tile_path)
    
    # Render base map canvas
    canvas = np.full((H, W, 3), OCEAN, dtype=np.uint8)

    # First pass: render natural terrain
    for ty in range(GRID_H):
        for tx in range(GRID_W):
            t_name = grid[ty, tx]
            if t_name == 'ocean':
                continue
            tile_data = MASTER_TILES.get(t_name, MASTER_TILES['grass_1'])
            y0, y1 = ty * TILE_SIZE, (ty + 1) * TILE_SIZE
            x0, x1 = tx * TILE_SIZE, (tx + 1) * TILE_SIZE
            canvas[y0:y1, x0:x1] = tile_data

    # Second pass: overlay roads and bridges
    road_pixel_mask = np.zeros((H, W), dtype=bool)

    for tx, ty in all_road_tiles:
        y0, y1 = ty * TILE_SIZE, (ty + 1) * TILE_SIZE
        x0, x1 = tx * TILE_SIZE, (tx + 1) * TILE_SIZE

        # Find connected road ports
        ports = set()
        if (tx, ty - 1) in all_road_tiles: ports.add('N')
        if (tx, ty + 1) in all_road_tiles: ports.add('S')
        if (tx + 1, ty) in all_road_tiles: ports.add('E')
        if (tx - 1, ty) in all_road_tiles: ports.add('W')
        if not ports:
            ports = {'N', 'S'}

        orig_terrain = grid[ty, tx]
        if 'river' in orig_terrain:
            # Cross river -> BRIDGE!
            if 'N' in ports or 'S' in ports:
                tile_data = tile_bridge_v
            else:
                tile_data = tile_bridge_h
        else:
            tile_data = make_road_tile(ports)

        canvas[y0:y1, x0:x1] = tile_data
        road_pixel_mask[y0:y1, x0:x1] = True

    # Third pass: overlay Landmark building sprites centered at POI coordinates
    landmark_pixel_mask = np.zeros((H, W), dtype=bool)

    poi_sprites = {
        'taipei_101': parse_sprite(ART_101, PAL_101),
        'taichung_opera': parse_sprite(ART_OPERA, PAL_OPERA),
        'sun_moon_lake': parse_sprite(ART_PAGODA, PAL_PAGODA),
        'kaohsiung_85': parse_sprite(ART_85.replace('H', 'L'), PAL_85),
    }

    for name, (cx, cy) in POIS.items():
        sprite = poi_sprites[name]
        sh, sw = sprite.shape[:2]
        x0 = cx - sw // 2
        y0 = cy - sh // 2
        for sy in range(sh):
            for sx in range(sw):
                if sprite[sy, sx, 3] > 0:  # Non-transparent
                    px, py = x0 + sx, y0 + sy
                    if is_land[py, px]:
                        canvas[py, px] = sprite[sy, sx, :3]
                        landmark_pixel_mask[py, px] = True

    # STRICT OCEAN ENFORCEMENT:
    # All ocean pixels from reference MUST remain flat OCEAN #1E6F9F
    canvas[is_ocean] = OCEAN
    landmark_pixel_mask[is_ocean] = False
    road_pixel_mask[is_ocean] = False

    # 6. Generate 256 x 144 mask.png
    MASK_W = 256
    MASK_H = 144
    mask_img = np.zeros((MASK_H, MASK_W, 3), dtype=np.uint8)

    COLOR_OCEAN = np.array([0, 0, 255], dtype=np.uint8)       # #0000FF
    COLOR_LAND = np.array([0, 255, 0], dtype=np.uint8)         # #00FF00
    COLOR_ROAD = np.array([255, 0, 255], dtype=np.uint8)       # #FF00FF
    COLOR_LANDMARK = np.array([255, 255, 0], dtype=np.uint8)   # #FFFF00

    for my in range(MASK_H):
        for mx in range(MASK_W):
            bx0, bx1 = mx * 8, (mx + 1) * 8
            by0, by1 = my * 8, (my + 1) * 8

            lm_block = landmark_pixel_mask[by0:by1, bx0:bx1]
            rd_block = road_pixel_mask[by0:by1, bx0:bx1]
            ld_block = is_land[by0:by1, bx0:bx1]

            if np.any(lm_block):
                mask_img[my, mx] = COLOR_LANDMARK
            elif np.any(rd_block):
                mask_img[my, mx] = COLOR_ROAD
            elif np.any(ld_block):
                mask_img[my, mx] = COLOR_LAND
            else:
                mask_img[my, mx] = COLOR_OCEAN

    return canvas, mask_img, roads_json_data, is_ocean


print("Pipeline function defined!")

def run_verifications():
    os.makedirs('assets/maps/taiwan', exist_ok=True)
    os.makedirs('assets/images', exist_ok=True)

    print("--- RUN 1: Generating outputs ---")
    canvas1, mask1, roads1, is_ocean = generate_pipeline_data(seed=1337)

    # Save Run 1
    Image.fromarray(canvas1).save('assets/images/taiwan_overworld.png')
    Image.fromarray(mask1).save('assets/maps/taiwan/mask.png')
    with open('assets/maps/taiwan/roads.json', 'w', encoding='utf-8') as f:
        json.dump(roads1, f, ensure_ascii=False, indent=2)

    # Read bytes from Run 1
    with open('assets/images/taiwan_overworld.png', 'rb') as f:
        b_map1 = f.read()
    with open('assets/maps/taiwan/mask.png', 'rb') as f:
        b_mask1 = f.read()
    with open('assets/maps/taiwan/roads.json', 'rb') as f:
        b_roads1 = f.read()

    hash_map1 = hashlib.sha256(b_map1).hexdigest()
    hash_mask1 = hashlib.sha256(b_mask1).hexdigest()
    hash_roads1 = hashlib.sha256(b_roads1).hexdigest()

    print("--- RUN 2: Determinism Test ---")
    canvas2, mask2, roads2, _ = generate_pipeline_data(seed=1337)

    Image.fromarray(canvas2).save('tool/temp_map.png')
    Image.fromarray(mask2).save('tool/temp_mask.png')
    with open('tool/temp_roads.json', 'w', encoding='utf-8') as f:
        json.dump(roads2, f, ensure_ascii=False, indent=2)

    with open('tool/temp_map.png', 'rb') as f:
        b_map2 = f.read()
    with open('tool/temp_mask.png', 'rb') as f:
        b_mask2 = f.read()
    with open('tool/temp_roads.json', 'rb') as f:
        b_roads2 = f.read()

    hash_map2 = hashlib.sha256(b_map2).hexdigest()
    hash_mask2 = hashlib.sha256(b_mask2).hexdigest()
    hash_roads2 = hashlib.sha256(b_roads2).hexdigest()

    # Clean up temp files
    os.remove('tool/temp_map.png')
    os.remove('tool/temp_mask.png')
    os.remove('tool/temp_roads.json')

    print("\n==================================================")
    print("           SELF-VERIFICATION RESULTS              ")
    print("==================================================")

    # 1. Ocean Pixel Mismatch
    ocean_mismatches = 0
    ref_ocean = is_ocean
    cur_ocean = np.all(canvas1 == OCEAN, axis=-1)
    ocean_mismatches = int(np.sum(ref_ocean != cur_ocean))
    print(f"1. Ocean Pixel Mismatches:")
    print(f"   - Reference Ocean Pixels: {int(np.sum(ref_ocean))}")
    print(f"   - Generated Ocean Pixels: {int(np.sum(cur_ocean))}")
    print(f"   - Mismatched Pixels:      {ocean_mismatches}")
    assert ocean_mismatches == 0, f"Ocean pixel mismatches must be 0, got {ocean_mismatches}"

    # 2. Road Node Distance to Landmarks
    print(f"\n2. Road Node Distances to Landmarks (threshold = 100.0 m):")
    min_dist_meters = float('inf')
    total_nodes_checked = 0
    all_distances = []

    for road in roads1:
        road_id = road['id']
        for pt in road['points']:
            total_nodes_checked += 1
            for poi_name, (lx, ly) in POIS.items():
                d_px = math.hypot(pt[0] - lx, pt[1] - ly)
                d_m = d_px * m_per_px
                all_distances.append(d_m)
                if d_m < min_dist_meters:
                    min_dist_meters = d_m
                if d_m <= 100.0:
                    raise AssertionError(f"Road node {pt} in {road_id} is only {d_m:.1f} m from {poi_name} (<= 100m)!")

    print(f"   - Total Road Nodes Checked: {total_nodes_checked}")
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

    # 4. Road Mask Connected Components & Island Check
    print(f"\n4. Road Mask Connectivity & Island Check:")
    COLOR_ROAD = np.array([255, 0, 255], dtype=np.uint8)
    COLOR_LANDMARK = np.array([255, 255, 0], dtype=np.uint8)

    road_mask_2d = np.all(mask1 == COLOR_ROAD, axis=-1)
    landmark_mask_2d = np.all(mask1 == COLOR_LANDMARK, axis=-1)

    struct_8 = generate_binary_structure(2, 2)  # 8-connectivity
    labeled_roads, num_road_comps = label(road_mask_2d, structure=struct_8)

    print(f"   - Road Mask Pixels:          {int(np.sum(road_mask_2d))}")
    print(f"   - Road Connected Components: {num_road_comps}")

    isolated_components = 0
    for cid in range(1, num_road_comps + 1):
        c_mask = labeled_roads == cid
        c_dilated = binary_dilation(c_mask, structure=struct_8)
        touches_poi = np.any(c_dilated & landmark_mask_2d)
        touches_other_road = np.any(c_dilated & (road_mask_2d & ~c_mask))
        if not (touches_poi or touches_other_road):
            isolated_components += 1
            print(f"     [ERROR] Component {cid} is isolated!")

    print(f"   - Isolated Road Components:  {isolated_components}")
    assert isolated_components == 0, f"Found {isolated_components} isolated road components!"

    # 5. Determinism (Byte-for-byte identical across runs)
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
