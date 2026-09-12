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
  }) : _manifest = manifest;

  OverworldMapManifest _manifest;
  OverworldMapManifest get manifest => _manifest;
  final void Function(DistrictAttraction attraction)? onAttractionTapped;
  final void Function(AdministrativeDistrict? district, int visibleCount)?
      onDistrictChanged;

  List<DistrictAttraction> get allAttractions => _manifest.districtAttractions;
  List<AdministrativeDistrict> get allDistricts =>
      _manifest.administrativeDistricts;

  double _lastZoom = 1.0;
  AdministrativeDistrict? _currentDistrict;
  DistrictAttraction? _selectedAttraction;
  List<DistrictAttraction> _visibleAttractions = [];

  DistrictAttraction? get selectedAttraction => _selectedAttraction;
  AdministrativeDistrict? get currentDistrict => _currentDistrict;
  List<DistrictAttraction> get visibleAttractions => _visibleAttractions;

  void selectAttraction(DistrictAttraction? attraction) {
    _selectedAttraction = attraction;
  }

  /// 切換圖資模組（宏觀盆地 ⇄ 中觀街區）
  void switchManifest(OverworldMapManifest newManifest) {
    _manifest = newManifest;
    _selectedAttraction = null;
    _currentDistrict = null;
    _visibleAttractions = AttractionFilter.visibleAttractions(
      attractions: allAttractions,
      currentZoom: _lastZoom,
    );
  }

  /// 根據相機位置與縮放更新可見景點
  void updateVisibility({
    required double zoom,
    required vm.Vector2 cameraCenter,
  }) {
    _lastZoom = zoom;

    // 1. 根據縮放過濾達標景點
    final filtered = AttractionFilter.visibleAttractions(
      attractions: allAttractions,
      currentZoom: zoom,
    );

    // 2. 判斷相機目前對焦的行政區
    final focused = AttractionFilter.findFocusedDistrict(
      districts: allDistricts,
      cameraCenter: cameraCenter,
    );

    _visibleAttractions = filtered;

    if (focused?.code != _currentDistrict?.code) {
      _currentDistrict = focused;
      final districtSpotsCount = focused == null
          ? 0
          : AttractionFilter.byDistrict(
              attractions: filtered,
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
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(1.5 * scaleFactor, 2.5 * scaleFactor), markerRadius * scaleFactor, shadowPaint);

    // 2. 標記外黑邊框 (JRPG 8-Bit Pixel Art 粗黑框)
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scaleFactor;

    // 3. 類別主題色底盤填色
    final categoryColor = _colorForCategory(attraction.category);
    final fillPaint = Paint()
      ..color = categoryColor
      ..style = PaintingStyle.fill;

    // 繪製圓形地標徽章與內邊框
    final centerOffset = Offset.zero;
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, fillPaint);
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, borderPaint);

    // 繪製金黃/亮白內襯邊框
    final innerBorderPaint = Paint()
      ..color = isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scaleFactor;
    canvas.drawCircle(centerOffset, (markerRadius - 1.5) * scaleFactor, innerBorderPaint);

    // 4. 繪製專屬地標微縮圖標 (Landmark Miniature Icon: 🚂 🎋 ⛩️ 🍜 🐱 🏮 ⛰️)
    final landmarkIcon = _iconForAttraction(attraction);
    final iconPainter = TextPainter(
      text: TextSpan(
        text: landmarkIcon,
        style: TextStyle(
          fontSize: (markerRadius * 1.15) * scaleFactor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -iconPainter.height / 2),
    );

    // 若被選中，繪製外圍脈衝金黃光環
    if (isSelected) {
      final ringPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * scaleFactor;
      canvas.drawCircle(centerOffset, (markerRadius + 4.5) * scaleFactor, ringPaint);
    }

    // 5. 當 zoom >= 0.8、或景點被選中、或位於聚焦街區時，繪製景點名與 Google Maps 評分標籤
    if (zoom >= 0.8 || isSelected || isFocusedDistrict) {
      _renderTitleTag(canvas, attraction, scaleFactor, isSelected);
    }

    canvas.restore();
  }

  void _renderTitleTag(
    Canvas canvas,
    DistrictAttraction attraction,
    double scaleFactor,
    bool isSelected,
  ) {
    final icon = _iconForAttraction(attraction);
    final titleText = '$icon ${attraction.title}';
    final ratingText = '★${attraction.rating.toStringAsFixed(1)}';

    // 繪製標籤文字
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

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final paddingH = 6.0 * scaleFactor;
    final paddingV = 3.0 * scaleFactor;
    final tagW = (textPainter.width + 12.0) * scaleFactor;
    final tagH = (textPainter.height + 6.0) * scaleFactor;
    final tagLeft = -tagW / 2;
    final tagTop = -(14.0 * scaleFactor) - tagH;

    final tagRect = Rect.fromLTWH(tagLeft, tagTop, tagW, tagH);

    // 標籤陰影
    canvas.drawRect(
      tagRect.translate(1.5 * scaleFactor, 1.5 * scaleFactor),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // 標籤背景底色
    final bgPaint = Paint()
      ..color = isSelected ? const Color(0xFFFFF9C4) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(tagRect, bgPaint);

    // 標籤外黑框
    final boxBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scaleFactor;
    canvas.drawRect(tagRect, boxBorder);

    // 文字渲染
    canvas.save();
    canvas.translate(tagLeft + paddingH, tagTop + paddingV);
    canvas.scale(scaleFactor, scaleFactor);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
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
