with open('tool/generate_snes_overworld.py') as f:
    code = f.read()

# Replace trace_river and paths
new_trace_river = '''
def get_ports_tile(in_dir, out_dir):
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
'''

# Find trace_river definition in code and replace it
import re
code = re.sub(r'def trace_river\(.*?\n(?=def generate_map_grid)', new_trace_river + '\n\n', code, flags=re.DOTALL)

# Update paths in code
new_paths = '''    # 4. Place Rivers with Strictly 4-Connected Directional Tracing
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
    trace_river(xiuguluan_path, grid, mouth_type='MOUTH_E')'''

code = re.sub(r'    # 4\. Place Rivers with Directional Tracing.*?(?=    return grid)', new_paths + '\n\n', code, flags=re.DOTALL)

with open('tool/generate_snes_overworld.py', 'w') as f:
    f.write(code)

print("Updated tool/generate_snes_overworld.py successfully!")
