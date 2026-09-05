#!/usr/bin/env python3
"""
產生過渡用的台灣像素地圖，並推導對應的校準錨點像素座標。

這不是最終美術資產。目的是提供一張「近等距」的底圖，
使錨點可用單一線性公式推導、可被回歸測試驗證，
讓任務 C 的真機驗收得以提早進行。

投影：等距長方投影 (equirectangular)，經度乘以參考緯度的 cos 值做長度修正。
      故圖上 1 px 在東西向與南北向代表大致相同的實際距離。

用法：python3 tool/generate_taiwan_map.py
"""
import math
from PIL import Image, ImageDraw

# --- 畫布 ---
W, H = 2048, 1152
MARGIN_Y = 0.06          # 上下留白比例
OCEAN = (30, 111, 159)   # 沿用既有 oceanColor 0xFF1E6F9F
LAND = (72, 187, 120)
COAST = (38, 128, 84)

# --- 簡化台灣本島海岸線，順時針，自北端起 (lat, lng) ---
COASTLINE = [
    (25.298, 121.535),  # 富貴角（北端）
    (25.163, 121.745),  # 基隆
    (25.007, 122.002),  # 三貂角（東北角）
    (24.855, 121.845),  # 頭城
    (24.596, 121.868),  # 蘇澳
    (24.300, 121.780),  # 南澳
    (23.986, 121.618),  # 花蓮
    (23.480, 121.500),  # 豐濱
    (23.100, 121.372),  # 成功
    (22.755, 121.152),  # 台東
    (22.610, 121.005),  # 太麻里
    (22.320, 120.905),  # 大武
    (22.005, 120.878),  # 旭海
    (21.902, 120.852),  # 鵝鑾鼻（南端）
    (21.925, 120.720),  # 貓鼻頭
    (22.160, 120.700),  # 楓港
    (22.368, 120.592),  # 枋寮
    (22.468, 120.450),  # 東港
    (22.610, 120.268),  # 高雄
    (23.000, 120.160),  # 台南
    (23.270, 120.118),  # 北門
    (23.462, 120.132),  # 東石
    (23.752, 120.248),  # 麥寮
    (24.198, 120.498),  # 大肚溪口
    (24.288, 120.528),  # 台中港
    (24.492, 120.668),  # 通霄
    (24.848, 120.928),  # 新竹
    (25.032, 121.082),  # 觀音
    (25.183, 121.418),  # 淡水
]

# --- 需要推導像素座標的校準地標 ---
LANDMARKS = [
    ('基隆北端',     25.150, 121.750),
    ('台北101',      25.034, 121.564),
    ('台中歌劇院',   24.163, 120.640),
    ('日月潭',       23.858, 120.916),
    ('阿里山',       23.510, 120.803),
    ('台南赤崁樓',   22.997, 120.202),
    ('高雄85大樓',   22.611, 120.300),
    ('鵝鑾鼻南端',   21.902, 120.852),
]

lats = [p[0] for p in COASTLINE]
lngs = [p[1] for p in COASTLINE]
LAT_MIN, LAT_MAX = min(lats), max(lats)
LNG_MIN, LNG_MAX = min(lngs), max(lngs)
LAT_REF = (LAT_MIN + LAT_MAX) / 2
KX = math.cos(math.radians(LAT_REF))     # 經度長度修正係數

# 以高度為準決定比例尺，水平置中
span_y = LAT_MAX - LAT_MIN
span_x = (LNG_MAX - LNG_MIN) * KX
scale = (H * (1 - 2 * MARGIN_Y)) / span_y
off_x = (W - span_x * scale) / 2
off_y = H * MARGIN_Y


def project(lat, lng):
    """經緯度 → 像素。與 manifest 的錨點推導使用同一公式。"""
    x = off_x + (lng - LNG_MIN) * KX * scale
    y = off_y + (LAT_MAX - lat) * scale
    return x, y


def main():
    poly = [project(la, lo) for la, lo in COASTLINE]

    im = Image.new('RGB', (W, H), OCEAN)
    d = ImageDraw.Draw(im)
    d.polygon(poly, fill=LAND, outline=COAST)
    # 8-Bit 觀感：降取樣再放大，產生硬邊像素塊，且不做抗鋸齒
    block = 4
    im = im.resize((W // block, H // block), Image.NEAREST)
    im = im.resize((W, H), Image.NEAREST)
    im.save('assets/images/taiwan_overworld.png')

    print(f'已寫出 assets/images/taiwan_overworld.png  ({W}x{H})')
    print(f'比例尺 {scale:.2f} px/度緯度 = {110.574 * 1000 / scale:.1f} 公尺/像素（全圖一致）\n')
    print('推導出的錨點像素座標：')
    for name, la, lo in LANDMARKS:
        x, y = project(la, lo)
        print(f"    GeoAnchor(name: '{name}', lat: {la}, lng: {lo}, "
              f"pixelPos: Vector2({x:.0f}, {y:.0f})),")


if __name__ == '__main__':
    main()
