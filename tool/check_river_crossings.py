import sys
sys.path.insert(0, '.')
from PIL import Image
import numpy as np

# Import map grid generator from generate_snes_overworld
from tool.generate_snes_overworld import generate_map_grid, OCEAN
from tool.test_road_routing import west_tiles, sml_tiles

ref_img = Image.open('assets/images/taiwan_overworld_silhouette.png')
ref_arr = np.array(ref_img)
is_ocean = np.all(ref_arr == OCEAN, axis=-1)
is_land = ~is_ocean

grid = generate_map_grid(is_land)

print("Checking river crossings on West Corridor:")
for tx, ty in west_tiles:
    tile = grid[ty, tx]
    if 'river' in tile:
        print(f"  West Corridor crosses river at ({tx}, {ty}): current tile = {tile}")

print("Checking river crossings on SML Corridor:")
for tx, ty in sml_tiles:
    tile = grid[ty, tx]
    if 'river' in tile:
        print(f"  SML Corridor crosses river at ({tx}, {ty}): current tile = {tile}")
