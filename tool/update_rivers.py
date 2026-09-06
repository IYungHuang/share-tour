import sys
sys.path.insert(0, '.')

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

# Test all 4-connected turns
assert get_ports_tile((-1, 0), (-1, 0)) == 'river_h'
assert get_ports_tile((0, 1), (0, 1)) == 'river_v'
assert get_ports_tile((-1, 0), (0, 1)) == 'river_es'
assert get_ports_tile((0, 1), (-1, 0)) == 'river_wn'
print("Ports tile test passed successfully!")
