import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../../domain/location/models/district_attraction.dart';
import '../../domain/location/projection/map_manifest.dart';

/// 地圖行政區熱門旅遊景點圖層
/// 根據相機縮放倍率（雙手放大）動態揭露該行政區的各級熱門景點
class AttractionLayerComponent extends Component {
  AttractionLayerComponent({
    required OverworldMapManifest manifest,
    this.onAttractionTapped,
    this.onDistrictChanged,
    this.maxVisibleTags = 1,
    this.showOnlySelectedTag = true,
  }) : _manifest = manifest;

  OverworldMapManifest _manifest;
  OverworldMapManifest get manifest => _manifest;
  final void Function(DistrictAttraction attraction)? onAttractionTapped;
  final void Function(AdministrativeDistrict? district, int visibleCount)?
      onDistrictChanged;

  /// 標籤同時顯示的最大數量上限閾值（預設為 1）
  int maxVisibleTags = 1;

  /// 是否僅在點擊選中時才顯示標籤（預設 true：平時不顯示文字標籤，點擊圖標後才彈出）
  bool showOnlySelectedTag = true;

  List<DistrictAttraction> get allAttractions => _manifest.districtAttractions;
  List<AdministrativeDistrict> get allDistricts =>
      _manifest.administrativeDistricts;

  double _lastZoom = 1.0;
  AdministrativeDistrict? _currentDistrict;
  DistrictAttraction? _selectedAttraction;
  List<DistrictAttraction> _visibleAttractions = [];
  final Set<String> _activeTagSpotIds = {};

  // 快取渲染用 Paint 與 TextPainter，保證 60fps 零記憶體配置 (0 bytes GC)
  final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.5)
    ..style = PaintingStyle.fill;
  final Paint _borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _innerBorderPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _ringPaint = Paint()
    ..color = Colors.amberAccent
    ..style = PaintingStyle.stroke;
  final Paint _tagShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.4)
    ..style = PaintingStyle.fill;
  final Paint _tagBgPaint = Paint()..style = PaintingStyle.fill;
  final Paint _tagBorderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke;

  final Map<String, TextPainter> _titlePainters = {};
  final Map<String, TextPainter> _iconPainters = {};

  DistrictAttraction? get selectedAttraction => _selectedAttraction;
  AdministrativeDistrict? get currentDistrict => _currentDistrict;
  List<DistrictAttraction> get visibleAttractions => _visibleAttractions;

  void selectAttraction(DistrictAttraction? attraction) {
    _selectedAttraction = attraction;
    _activeTagSpotIds.clear();
    if (attraction != null) {
      _activeTagSpotIds.add(attraction.id);
    }
  }

  /// 切換圖資模組（宏觀盆地 ⇄ 中觀街區）
  void switchManifest(OverworldMapManifest newManifest) {
    _manifest = newManifest;
    _selectedAttraction = null;
    _currentDistrict = null;
    _activeTagSpotIds.clear();
    _titlePainters.clear();
    _iconPainters.clear();
    _visibleAttractions = AttractionFilter.visibleAttractions(
      attractions: allAttractions,
      currentZoom: _lastZoom,
    );
  }

  /// 根據相機位置、縮放以及玩家角色位置更新可見景點與所在行政區
  void updateVisibility({
    required double zoom,
    required vm.Vector2 cameraCenter,
    vm.Vector2? playerPosition,
  }) {
    _lastZoom = zoom;

    // 1. 根據縮放過濾達標景點
    final filtered = AttractionFilter.visibleAttractions(
      attractions: allAttractions,
      currentZoom: zoom,
    );

    // 2. 方案 A：以玩家角色實際位置判定所在行政區（未傳入時 fallback 至 cameraCenter）
    final checkPosition = playerPosition ?? cameraCenter;
    final focused = AttractionFilter.findDistrictAtPosition(
      districts: allDistricts,
      playerPosition: checkPosition,
    );

    _visibleAttractions = filtered;

    // 計算允許顯示標籤的景點集合（嚴格遵守上限閾值 maxVisibleTags）
    _activeTagSpotIds.clear();
    if (_selectedAttraction != null) {
      _activeTagSpotIds.add(_selectedAttraction!.id);
    }

    if (!showOnlySelectedTag && _activeTagSpotIds.length < maxVisibleTags) {
      final candidates = List<DistrictAttraction>.from(filtered)
        ..sort((a, b) => a
            .distancePixelsTo(cameraCenter)
            .compareTo(b.distancePixelsTo(cameraCenter)));

      for (final spot in candidates) {
        if (_activeTagSpotIds.length >= maxVisibleTags) break;
        _activeTagSpotIds.add(spot.id);
      }
    }

    if (focused?.code != _currentDistrict?.code) {
      _currentDistrict = focused;
      final districtSpotsCount = focused == null
          ? 0
          : AttractionFilter.byDistrict(
              attractions: allAttractions,
              districtCode: focused.code,
            ).length;
      onDistrictChanged?.call(focused, districtSpotsCount);
    }
  }

  /// 搜尋世界座標點擊處附近的景點
  DistrictAttraction? findAttractionAt(
    vm.Vector2 worldPoint, {
    double thresholdPixels = 44.0,
  }) {
    DistrictAttraction? closest;
    double minDistance = double.infinity;

    for (final attraction in _visibleAttractions) {
      final d = attraction.distancePixelsTo(worldPoint);
      if (d <= thresholdPixels && d < minDistance) {
        minDistance = d;
        closest = attraction;
      }
    }
    return closest;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_visibleAttractions.isEmpty) return;

    for (final attraction in _visibleAttractions) {
      _renderAttractionMarker(canvas, attraction, _lastZoom);
    }
  }

  void _renderAttractionMarker(
    Canvas canvas,
    DistrictAttraction attraction,
    double zoom,
  ) {
    final pos = attraction.pixel;
    final isSelected = _selectedAttraction?.id == attraction.id;
    final isFocusedDistrict =
        _currentDistrict != null && attraction.districtCode == _currentDistrict!.code;

    canvas.save();
    canvas.translate(pos.x, pos.y);

    // 逆縮放尺寸，確保標籤與圖標在不同縮放層級下維持清晰可讀
    final scaleFactor = 1.0 / zoom.clamp(0.6, 3.5);
    final markerRadius = isSelected ? 13.0 : (isFocusedDistrict ? 11.0 : 9.5);

    // 1. 標記底部深色陰影
    canvas.drawCircle(
      Offset(1.5 * scaleFactor, 2.5 * scaleFactor),
      markerRadius * scaleFactor,
      _shadowPaint,
    );

    // 2. 標記外黑邊框 (JRPG 8-Bit Pixel Art 粗黑框)
    _borderPaint.strokeWidth = 2.5 * scaleFactor;

    // 3. 類別主題色底盤填色
    _fillPaint.color = _colorForCategory(attraction.category);

    // 繪製圓形地標徽章與內邊框
    final centerOffset = Offset.zero;
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, _fillPaint);
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, _borderPaint);

    // 繪製金黃/亮白內襯邊框
    _innerBorderPaint
      ..color = isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.0 * scaleFactor;
    canvas.drawCircle(centerOffset, (markerRadius - 1.5) * scaleFactor, _innerBorderPaint);

    // 4. 繪製專屬地標微縮圖標 (Landmark Miniature Icon: 🚂 🎋 ⛩️ 🍜 🐱 🏮 ⛰️)
    final iconPainter = _getIconPainter(attraction);
    final iconScale = (markerRadius * 1.15 * scaleFactor) / 14.0;
    canvas.save();
    canvas.scale(iconScale, iconScale);
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -iconPainter.height / 2),
    );
    canvas.restore();

    // 若被選中，繪製外圍脈衝金黃光環
    if (isSelected) {
      _ringPaint.strokeWidth = 3.0 * scaleFactor;
      canvas.drawCircle(centerOffset, (markerRadius + 4.5) * scaleFactor, _ringPaint);
    }

    // 5. 標籤顯示邏輯（數量上限閾值與點擊觸發）：
    // 預設 (showOnlySelectedTag == true)：平常畫面不顯示文字標籤，保持純淨 8-Bit 微縮圖標；
    // 只有點擊選中景點 (isSelected) 時才顯示詳細名稱與 Google Maps 評分。
    // 若設定 showOnlySelectedTag == false，則嚴格限制畫面最多同時顯示 maxVisibleTags 個標籤。
    final bool shouldShowTag = isSelected ||
        (!showOnlySelectedTag && _activeTagSpotIds.contains(attraction.id));

    if (shouldShowTag) {
      _renderTitleTag(canvas, attraction, scaleFactor, isSelected, markerRadius);
    }

    canvas.restore();
  }

  void _renderTitleTag(
    Canvas canvas,
    DistrictAttraction attraction,
    double scaleFactor,
    bool isSelected,
    double markerRadius,
  ) {
    final pos = attraction.pixel;
    final textPainter = _getTitlePainter(attraction);

    final paddingH = 6.0 * scaleFactor;
    final paddingV = 3.0 * scaleFactor;
    final tagW = (textPainter.width + 12.0) * scaleFactor;
    final tagH = (textPainter.height + 6.0) * scaleFactor;
    double tagLeft = -tagW / 2;
    double tagTop = -(markerRadius + 4.0) * scaleFactor - tagH;

    // 邊界防溢出與自動翻轉保護 (Boundary anti-overflow & auto-repositioning)
    final mapW = _manifest.mapDimensions.x;
    final mapH = _manifest.mapDimensions.y;
    const margin = 8.0;

    // 頂部防溢出：若標籤頂端超出畫布上界，自動翻轉至地標標記下方
    if (pos.y + tagTop < margin) {
      tagTop = (markerRadius + 4.0) * scaleFactor;
    }

    // 左右防溢出：若標籤超出左右邊界，自動平移保證留在畫布安全邊距內
    if (pos.x + tagLeft < margin) {
      tagLeft = margin - pos.x;
    } else if (pos.x + tagLeft + tagW > mapW - margin) {
      tagLeft = (mapW - margin - tagW) - pos.x;
    }

    // 底部防溢出：若翻轉至下方後仍可能超出底界，強制截斷貼底
    if (pos.y + tagTop + tagH > mapH - margin) {
      tagTop = (mapH - margin - tagH) - pos.y;
    }

    final tagRect = Rect.fromLTWH(tagLeft, tagTop, tagW, tagH);

    // 標籤陰影
    _tagShadowPaint.color = Colors.black.withValues(alpha: 0.4);
    canvas.drawRect(
      tagRect.translate(1.5 * scaleFactor, 1.5 * scaleFactor),
      _tagShadowPaint,
    );

    // 標籤背景底色
    _tagBgPaint.color = isSelected ? const Color(0xFFFFF9C4) : Colors.white;
    canvas.drawRect(tagRect, _tagBgPaint);

    // 標籤外黑框
    _tagBorderPaint.strokeWidth = 1.5 * scaleFactor;
    canvas.drawRect(tagRect, _tagBorderPaint);

    // 文字渲染
    canvas.save();
    canvas.translate(tagLeft + paddingH, tagTop + paddingV);
    canvas.scale(scaleFactor, scaleFactor);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  TextPainter _getTitlePainter(DistrictAttraction attraction) {
    return _titlePainters.putIfAbsent(attraction.id, () {
      final icon = _iconForAttraction(attraction);
      final titleText = '$icon ${attraction.title}';
      final ratingText = '★${attraction.rating.toStringAsFixed(1)}';

      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '$titleText ',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          TextSpan(
            text: ratingText,
            style: TextStyle(
              color: Colors.amber.shade900,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );

      return TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  TextPainter _getIconPainter(DistrictAttraction attraction) {
    final icon = _iconForAttraction(attraction);
    return _iconPainters.putIfAbsent(icon, () {
      return TextPainter(
        text: TextSpan(
          text: icon,
          style: const TextStyle(fontSize: 14.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  Color _colorForCategory(AttractionCategory category) => switch (category) {
        AttractionCategory.landmark => const Color(0xFFF59E0B),   // 金黃色
        AttractionCategory.culture => const Color(0xFFDC2626),    // 緋紅色
        AttractionCategory.nature => const Color(0xFF10B981),     // 翠綠色
        AttractionCategory.recreation => const Color(0xFF06B6D4), // 水藍色
        AttractionCategory.food => const Color(0xFFEA580C),       // 亮橘色
        AttractionCategory.sightseeing => const Color(0xFF6366F1),// 靛紫色
      };

  String _iconForAttraction(DistrictAttraction attraction) {
    final title = attraction.title;
    if (title.contains('車') || title.contains('鐵') || title.contains('電車')) return '🚂';
    if (title.contains('竹林') || title.contains('螢火') || title.contains('高野川')) return '🎋';
    if (title.contains('鳥居') || title.contains('寺') || title.contains('宮') || title.contains('門') || title.contains('塔') || title.contains('堂')) return '⛩️';
    if (title.contains('山')) return '⛰️';
    if (title.contains('貓')) return '🐱';
    if (title.contains('拉麵') || title.contains('麵') || title.contains('市場') || title.contains('食堂')) return '🍜';
    if (title.contains('酒') || title.contains('立飲') || title.contains('立吞') || title.contains('割烹')) return '🏮';
    if (title.contains('咖啡') || title.contains('黑膠') || title.contains('手沖') || title.contains('星巴克') || title.contains('喫茶')) return '☕';
    if (title.contains('自販機')) return '🥤';

    return switch (attraction.category) {
      AttractionCategory.landmark => '⛩️',
      AttractionCategory.culture => '📜',
      AttractionCategory.nature => '🌲',
      AttractionCategory.food => '🍜',
      AttractionCategory.recreation => '🎡',
      AttractionCategory.sightseeing => '📷',
    };
  }
}
