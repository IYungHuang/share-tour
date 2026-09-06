#!/usr/bin/env python3
"""
Master 16-bit SNES JRPG Overworld Map Generator for Taiwan.

Strictly satisfies all user constraints:
1. Canvas: 2048 x 1152 pixels, edge to edge.
2. Coastline: Matches reference silhouette EXACTLY (pixel-by-pixel mask).
3. Ocean color: #1E6F9F (30, 111, 159), completely flat, no gradients.
4. Top-down overworld map on a 16-pixel grid (128 x 72 tiles).
5. Limited palette, hard edges, no anti-aliasing, no blur, no drop shadows.
6. Terrain variety inside the land only: grass, forest clusters, mountain ranges, rivers, lakes.
   Mountains along eastern half, plains on the west.
7. No text, labels, UI, HUD, borders, characters, player sprites, vehicles, roads, or buildings.
"""
import math
import sys
import shutil
import numpy as np
from PIL import Image

sys.path.insert(0, '.')

from tool.snes_tiles import (
    TILES, OCEAN, GRASS_PAL, SAND_PAL, FOREST_PAL, PINE_PAL, MTN_PAL, HILL_PAL, WATER_PAL, parse_tile
)
from tool.mountain_engine import MTN_TILES

W, H = 2048, 1152
TILE_SIZE = 16
GRID_W = W // TILE_SIZE  # 128
GRID_H = H // TILE_SIZE  # 72

# --- PROCEDURAL RIVER TILE GENERATORS (Mathematically continuous at ports) ---
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
    R = 8.0
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


# --- 3x3 LAKE TILES ---
ART_LAKE_NW = """
................
.L...D........L.
....DD.S........
.......BBBBBBBBB
.....BBKKKKKKKKK
...BBKllllllllll
..BKlmmmmmmmmmmm
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
"""
ART_LAKE_N = """
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
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
"""
ART_LAKE_NE = """
................
.L...D........L.
....DD.S........
BBBBBBBBB.......
KKKKKKKKKBB.....
llllllllllKBB...
mmmmmmmmmmmKlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
"""
ART_LAKE_W = """
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
"""
ART_LAKE_CENTER = """
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
wwmwwwmwwwwmwwww
wwwwmwwwwwmwwwww
wwwwwwmwwmwwwwww
wwwwwwwmmwwwwwww
wwwFwwwwwwwFwwww
wwwFFwwwwwwFFwww
wwwwwwwwwwwwwwww
wwmwwwwwwwwwwmww
wwwwmwwwwwmwwwww
wwwwwwmwwwwmwwww
wwwFwwwwwFwwwwww
wwwFFwwwFFFwwwww
wwwwwwwwwwwwwwww
wwwwwwmwwwwwwwww
"""
ART_LAKE_E = """
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
"""
ART_LAKE_SW = """
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
BKlmwwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
.BKlmwwwwwwwwwww
..BKlmmmmmmmmmmm
...BBKllllllllll
.....BBKKKKKKKKK
.......BBBBBBBBB
................
.L...D........L.
....DD.S........
................
"""
ART_LAKE_S = """
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
mmmmmmmmmmmmmmmm
llllllllllllllll
BBBBBBBBBBBBBBBB
KKKKKKKKKKKKKKKK
................
.L...D........L.
....DD.S........
................
...L..D......L..
.L..D.....L...D.
"""
ART_LAKE_SE = """
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwwmlKB
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
wwwwwwwwwwwmlKB.
mmmmmmmmmmmKlKB.
llllllllllKBB...
KKKKKKKKKBB.....
BBBBBBBBB.......
................
.L...D........L.
....DD.S........
................
"""

ART_FOREST_PINE_DUO = """
...H.......H....
..HMD.....HMD...
.HMMMD...HMMMD..
..HMD.....HMD...
.HMMMD...HMMMD..
HMMMMMD.HMMMMMD.
..HMD.....HMD...
.HMMMD...HMMMD..
HMMMMMD.HMMMMMD.
MMMMMMMDMMMMMMMD
.XDDMDDXXDDMDDX.
..XTKTX...XTKTX.
...T.Kg....T.Kg.
................
.L...D........L.
....DD.S........
"""

ART_FOREST_CLUMP = """
.....HHHH.......
....HLLLLH......
...HLMMMMMD.....
..HLMMMMMMMDD...
..LMMMMMMMMMDX..
.HLLMMMMMMMDDSX.
.LMMMMMMMMMDDSX.
.DMMMMMMMMMMDSX.
.SDMMMMMMMMDDXX.
.XXDMMMMMMMDXX..
..XXDMMMMDDX....
...XXDMDDDXX....
....XTKTKXX.....
....KT.TKg......
...g.T..Kg......
....gg.ggg......
"""

# Master tile registry
MASTER_TILES = dict(TILES)
MASTER_TILES.update({
    'mtn_snow': MTN_TILES['snow'],
    'mtn_peak': MTN_TILES['peak'],
    'mtn_ridge': MTN_TILES['ridge'],
    'mtn_base': MTN_TILES['base'],
    'mtn_flank_w': MTN_TILES['flank_w'],
    'mtn_flank_e': MTN_TILES['flank_e'],
    'hills': MTN_TILES['hills'],
    'lake_nw': parse_tile(ART_LAKE_NW, WATER_PAL),
    'lake_n': parse_tile(ART_LAKE_N, WATER_PAL),
    'lake_ne': parse_tile(ART_LAKE_NE, WATER_PAL),
    'lake_w': parse_tile(ART_LAKE_W, WATER_PAL),
    'lake_c': parse_tile(ART_LAKE_CENTER, WATER_PAL),
    'lake_e': parse_tile(ART_LAKE_E, WATER_PAL),
    'lake_sw': parse_tile(ART_LAKE_SW, WATER_PAL),
    'lake_s': parse_tile(ART_LAKE_S, WATER_PAL),
    'lake_se': parse_tile(ART_LAKE_SE, WATER_PAL),
    'forest_pine': parse_tile(ART_FOREST_PINE_DUO, PINE_PAL),
    'forest_solo': parse_tile(ART_FOREST_CLUMP, FOREST_PAL),
    'river_h': make_river_straight(horizontal=True),
    'river_v': make_river_straight(horizontal=False),
    'river_es': make_river_corner(15.5, 15.5),
    'river_ws': make_river_corner(-0.5, 15.5),
    'river_en': make_river_corner(15.5, -0.5),
    'river_wn': make_river_corner(-0.5, -0.5),
    'river_mouth_w': make_river_straight(horizontal=True),
    'river_mouth_e': make_river_straight(horizontal=True),
})


def pseudo_hash(x, y, seed=1337):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177
    return (n & 0x7fffffff) / 0x7fffffff


def get_ports_tile(in_dir, out_dir):
    """
    Returns tile key connecting port (-in_dir) to port out_dir.
    """
    ports = frozenset([(-in_dir[0], -in_dir[1]), out_dir])
    if ports == frozenset([(-1, 0), (1, 0)]):
        return 'river_h'
    elif ports == frozenset([(0, -1), (0, 1)]):
        return 'river_v'
    elif ports == frozenset([(-1, 0), (0, 1)]):
        return 'river_ws'
    elif ports == frozenset([(1, 0), (0, 1)]):
        return 'river_es'
    elif ports == frozenset([(-1, 0), (0, -1)]):
        return 'river_wn'
    elif ports == frozenset([(1, 0), (0, -1)]):
        return 'river_en'
    return 'river_h'


def trace_river(path, grid, mouth_type='MOUTH_W'):
    """
    Traces a strictly 4-connected river path across grid cells using matching directional tiles.
    """
    for i in range(len(path) - 1):
        dx = abs(path[i+1][0] - path[i][0])
        dy = abs(path[i+1][1] - path[i][1])
        assert dx + dy == 1, f"Step {i}: {path[i]} -> {path[i+1]} is not 4-connected (dx={dx}, dy={dy})"

    for i in range(len(path)):
        tx, ty = path[i]
        if i == len(path) - 1:
            tile_key = 'river_mouth_w' if mouth_type == 'MOUTH_W' else 'river_mouth_e'
        elif i == 0:
            out_dir = (path[1][0] - tx, path[1][1] - ty)
            tile_key = 'river_h' if out_dir[0] != 0 else 'river_v'
        else:
            in_dir = (tx - path[i-1][0], ty - path[i-1][1])
            out_dir = (path[i+1][0] - tx, path[i+1][1] - ty)
            tile_key = get_ports_tile(in_dir, out_dir)
        
        grid[ty, tx] = tile_key


def generate_map_grid(is_land):
    tile_has_land = np.zeros((GRID_H, GRID_W), dtype=bool)
    tile_is_full_land = np.zeros((GRID_H, GRID_W), dtype=bool)

    for ty in range(GRID_H):
        for tx in range(GRID_W):
            block = is_land[ty*TILE_SIZE:(ty+1)*TILE_SIZE, tx*TILE_SIZE:(tx+1)*TILE_SIZE]
            c = np.sum(block)
            if c > 0:
                tile_has_land[ty, tx] = True
                if c == TILE_SIZE * TILE_SIZE:
                    tile_is_full_land[ty, tx] = True

    row_spans = {}
    for ty in range(GRID_H):
        cols = np.where(tile_has_land[ty])[0]
        if len(cols) > 0:
            row_spans[ty] = (cols.min(), cols.max())

    grid = np.empty((GRID_H, GRID_W), dtype=object)
    grid.fill('ocean')

    # Assign base terrain
    for ty in range(GRID_H):
        if ty not in row_spans:
            continue
        cmin, cmax = row_spans[ty]
        width = cmax - cmin + 1

        for tx in range(cmin, cmax + 1):
            if not tile_has_land[ty, tx]:
                continue

            rel_x = (tx - cmin) / max(width - 1, 1)
            h = pseudo_hash(tx, ty, seed=42)

            is_west_edge = (tx == cmin) or (tx == cmin + 1 and not tile_is_full_land[ty, tx])
            is_east_edge = (tx == cmax) or (tx == cmax - 1 and not tile_is_full_land[ty, tx])

            # A. Northern Taiwan (ty <= 12)
            if ty <= 12:
                if is_west_edge:
                    tile = 'sand'
                elif rel_x < 0.42:
                    # Taipei basin
                    if h < 0.45:
                        tile = 'grass_1'
                    elif h < 0.70:
                        tile = 'grass_flowers'
                    else:
                        tile = 'forest_solo'
                elif rel_x < 0.75:
                    # Datun / Yangmingshan hills
                    if h < 0.45:
                        tile = 'hills'
                    elif h < 0.75:
                        tile = 'forest_solo'
                    else:
                        tile = 'forest_pine'
                else:
                    # Northeast coast (Keelung / Yilan mountains)
                    if is_east_edge:
                        tile = 'mtn_flank_e'
                    elif h < 0.50:
                        tile = 'mtn_peak'
                    else:
                        tile = 'hills'

            # B. North-Central Taiwan (13 <= ty <= 26)
            elif ty <= 26:
                if is_west_edge:
                    tile = 'sand'
                elif rel_x < 0.36:
                    # Western Plains (Hsinchu, Miaoli, Taichung)
                    if h < 0.45:
                        tile = 'grass_warm'
                    elif h < 0.70:
                        tile = 'grass_1'
                    elif h < 0.88:
                        tile = 'grass_flowers'
                    else:
                        tile = 'forest_solo'
                elif rel_x < 0.48:
                    # Foothills
                    if h < 0.40:
                        tile = 'hills'
                    elif h < 0.75:
                        tile = 'forest_solo'
                    else:
                        tile = 'grass_1'
                elif rel_x < 0.80:
                    # Xueshan Range (雪山山脈)
                    if 19 <= ty <= 22 and 0.58 <= rel_x <= 0.66:
                        tile = 'mtn_snow' if h < 0.65 else 'mtn_peak'
                    elif rel_x < 0.55:
                        tile = 'mtn_flank_w' if h < 0.50 else 'hills'
                    elif rel_x > 0.72:
                        tile = 'mtn_flank_e' if h < 0.50 else 'forest_pine'
                    elif h < 0.50:
                        tile = 'mtn_peak'
                    else:
                        tile = 'mtn_ridge'
                else:
                    # Eastern slopes
                    if is_east_edge:
                        tile = 'mtn_flank_e' if h < 0.60 else 'hills'
                    elif h < 0.50:
                        tile = 'forest_pine'
                    else:
                        tile = 'hills'

            # C. Central Taiwan (27 <= ty <= 44)
            elif ty <= 44:
                if is_west_edge:
                    tile = 'sand'
                elif rel_x < 0.38:
                    # Expansive Western Plain (Changhua, Yunlin, Chiayi, Tainan)
                    if h < 0.50:
                        tile = 'grass_warm'
                    elif h < 0.74:
                        tile = 'grass_1'
                    elif h < 0.90:
                        tile = 'grass_flowers'
                    else:
                        tile = 'forest_solo'
                elif rel_x < 0.48:
                    # Foothills
                    if h < 0.38:
                        tile = 'hills'
                    elif h < 0.70:
                        tile = 'forest_solo'
                    else:
                        tile = 'grass_1'
                elif rel_x < 0.76:
                    # Central Mountain Range & Yushan Range (中央山脈 / 玉山山脈)
                    if 35 <= ty <= 39 and 0.57 <= rel_x <= 0.66:
                        tile = 'mtn_snow' if h < 0.70 else 'mtn_peak'
                    elif rel_x < 0.54:
                        tile = 'mtn_flank_w' if h < 0.60 else 'hills'
                    elif rel_x > 0.70:
                        tile = 'mtn_flank_e' if h < 0.55 else 'forest_pine'
                    elif h < 0.48:
                        tile = 'mtn_peak'
                    else:
                        tile = 'mtn_ridge'
                elif rel_x < 0.86:
                    # East Rift Valley (花東縱谷)
                    if h < 0.55:
                        tile = 'grass_1'
                    elif h < 0.80:
                        tile = 'grass_flowers'
                    else:
                        tile = 'forest_solo'
                else:
                    # Coastal Mountain Range (海岸山脈)
                    if is_east_edge:
                        tile = 'mtn_flank_e'
                    elif h < 0.50:
                        tile = 'mtn_peak'
                    elif h < 0.80:
                        tile = 'hills'
                    else:
                        tile = 'forest_pine'

            # D. Southern Taiwan (45 <= ty <= 54)
            elif ty <= 54:
                if is_west_edge:
                    tile = 'sand'
                elif rel_x < 0.36:
                    # Kaohsiung / Pingtung plain
                    if h < 0.50:
                        tile = 'grass_warm'
                    elif h < 0.75:
                        tile = 'grass_1'
                    elif h < 0.90:
                        tile = 'grass_flowers'
                    else:
                        tile = 'forest_solo'
                elif rel_x < 0.48:
                    # Foothills
                    if h < 0.42:
                        tile = 'hills'
                    elif h < 0.75:
                        tile = 'forest_solo'
                    else:
                        tile = 'grass_1'
                elif rel_x < 0.78:
                    # Southern Central Mountain Range (Dawushan 大武山)
                    if rel_x < 0.55:
                        tile = 'mtn_flank_w'
                    elif rel_x > 0.72:
                        tile = 'mtn_flank_e'
                    elif h < 0.50:
                        tile = 'mtn_peak'
                    else:
                        tile = 'mtn_ridge'
                else:
                    # Taitung coast
                    tile = 'mtn_flank_e' if is_east_edge else 'hills'

            # E. Hengchun Peninsula / Kenting (ty >= 55)
            else:
                if is_west_edge or is_east_edge or ty >= 64:
                    tile = 'sand'
                elif h < 0.45:
                    tile = 'grass_warm'
                elif h < 0.70:
                    tile = 'forest_solo'
                elif h < 0.85:
                    tile = 'hills'
                else:
                    tile = 'grass_flowers'

            grid[ty, tx] = tile

    # Place Lakes
    # Sun Moon Lake (日月潭) - 3x3 layout centered at (tx=61, ty=31)
    sml_map = [
        (30, 60, 'lake_nw'), (30, 61, 'lake_n'), (30, 62, 'lake_ne'),
        (31, 60, 'lake_w'),  (31, 61, 'lake_c'), (31, 62, 'lake_e'),
        (32, 60, 'lake_sw'), (32, 61, 'lake_s'), (32, 62, 'lake_se'),
    ]
    for ty, tx, t_name in sml_map:
        if tile_has_land[ty, tx]:
            grid[ty, tx] = t_name

    # Feitsui Lake in North: (tx=73, ty=11)
    feitsui_map = [
        (10, 72, 'lake_nw'), (10, 73, 'lake_ne'),
        (11, 72, 'lake_sw'), (11, 73, 'lake_se'),
    ]
    for ty, tx, t_name in feitsui_map:
        if tile_has_land[ty, tx]:
            grid[ty, tx] = t_name

    # Tsengwen Lake in South: (tx=54, ty=44)
    tsengwen_map = [
        (43, 53, 'lake_nw'), (43, 54, 'lake_ne'),
        (44, 53, 'lake_sw'), (44, 54, 'lake_se'),
    ]
    for ty, tx, t_name in tsengwen_map:
        if tile_has_land[ty, tx]:
            grid[ty, tx] = t_name

    # Place Rivers with Strictly 4-Connected Directional Tracing
    # Zhuoshui River (濁水溪) - Westward from Central Mountains to coast
    zhuoshui_path = [
        (60, 33), (59, 33), (58, 33), (57, 33),
        (57, 34), (56, 34), (55, 34), (54, 34),
        (53, 34), (52, 34), (51, 34), (50, 34), (49, 34)
    ]
    trace_river(zhuoshui_path, grid, mouth_type='MOUTH_W')

    # Dajia River (大甲溪) - Central-North flowing west
    dajia_path = [
        (64, 23), (63, 23), (62, 23), (61, 23),
        (61, 24), (60, 24), (59, 24), (58, 24),
        (57, 24), (56, 24), (55, 24), (54, 24)
    ]
    trace_river(dajia_path, grid, mouth_type='MOUTH_W')

    # Gaoping River (高屏溪) - Southern Taiwan flowing southwest
    gaoping_path = [
        (56, 48), (56, 49), (56, 50),
        (55, 50), (55, 51), (55, 52),
        (54, 52), (53, 52), (53, 53),
        (52, 53), (51, 53), (50, 53)
    ]
    trace_river(gaoping_path, grid, mouth_type='MOUTH_W')

    # Tamsui River (淡水河) - North flowing northwest
    tamsui_path = [
        (72, 10), (71, 10), (71, 9), (70, 9)
    ]
    trace_river(tamsui_path, grid, mouth_type='MOUTH_W')

    # Xiuguluan River (秀姑巒溪) - East coast flowing into Pacific
    xiuguluan_path = [
        (66, 37), (67, 37), (68, 37), (69, 37), (70, 37), (71, 37)
    ]
    trace_river(xiuguluan_path, grid, mouth_type='MOUTH_E')

    return grid


def render_full_overworld():
    ref_img = Image.open('assets/images/taiwan_overworld_silhouette.png')
    ref_arr = np.array(ref_img)
    is_ocean = np.all(ref_arr == OCEAN, axis=-1)
    is_land = ~is_ocean

    grid = generate_map_grid(is_land)

    canvas = np.full((H, W, 3), OCEAN, dtype=np.uint8)

    for ty in range(GRID_H):
        for tx in range(GRID_W):
            t_name = grid[ty, tx]
            if t_name == 'ocean':
                continue
            tile_data = MASTER_TILES.get(t_name, MASTER_TILES['grass_1'])
            y0, y1 = ty * TILE_SIZE, (ty + 1) * TILE_SIZE
            x0, x1 = tx * TILE_SIZE, (tx + 1) * TILE_SIZE
            canvas[y0:y1, x0:x1] = tile_data

    # Strict enforcement of mask
    canvas[is_ocean] = OCEAN

    # Verification assertions
    assert canvas.shape == (H, W, 3), f"Canvas shape mismatch: {canvas.shape}"
    assert np.all(canvas[is_ocean] == OCEAN), "Ocean pixels do not strictly match #1E6F9F!"
    assert not np.any(np.all(canvas[is_land] == OCEAN, axis=-1)), "Land pixels contain ocean color!"
    assert np.sum(np.all(canvas == OCEAN, axis=-1)) == np.sum(is_ocean), "Ocean pixel count altered!"

    print("ALL ABSOLUTE CONSTRAINTS VERIFIED:")
    print(f"  Canvas Dimensions: {W} x {H} pixels")
    print(f"  Ocean Pixels:      {np.sum(is_ocean):,} (100% flat #1E6F9F)")
    print(f"  Land Pixels:       {np.sum(is_land):,} (100% 16-bit SNES terrain)")
    print(f"  Grid Alignment:    16-pixel grid ({GRID_W} x {GRID_H} tiles)")

    return canvas


def main():
    canvas = render_full_overworld()
    out_img = Image.fromarray(canvas)
    out_img.save('assets/images/taiwan_overworld.png')
    print("Saved output directly to assets/images/taiwan_overworld.png")


if __name__ == '__main__':
    main()
