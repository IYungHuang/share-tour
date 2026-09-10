import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../../domain/location/models/district_attraction.dart';
import '../../domain/location/projection/map_manifest.dart';

/// 地圖行政區熱門旅遊景點圖層
/// 根據相機縮放倍率（雙手放大）動態揭露該行政區的各級熱門景點
class AttractionLayerComponent extends Component {
  AttractionLayerComponent({
    required this.manifest,
    this.onAttractionTapped,
    this.onDistrictChanged,
  });

  final OverworldMapManifest manifest;
  final void Function(DistrictAttraction attraction)? onAttractionTapped;
  final void Function(AdministrativeDistrict? district, int visibleCount)?
      onDistrictChanged;

  List<DistrictAttraction> get allAttractions => manifest.districtAttractions;
  List<AdministrativeDistrict> get allDistricts =>
      manifest.administrativeDistricts;

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
    double thresholdPixels = 24.0,
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
    final markerRadius = isSelected ? 8.0 : (isFocusedDistrict ? 6.5 : 5.5);

    // 1. 標記底部陰影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(1.5, 2.0), markerRadius * scaleFactor, shadowPaint);

    // 2. 標記外黑邊框 (JRPG 8-Bit Pixel Art 風格)
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scaleFactor;

    // 3. 類別主題色填色
    final categoryColor = _colorForCategory(attraction.category);
    final fillPaint = Paint()
      ..color = categoryColor
      ..style = PaintingStyle.fill;

    // 繪製八角菱形或圓形地標徽章
    final centerOffset = Offset.zero;
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, fillPaint);
    canvas.drawCircle(centerOffset, markerRadius * scaleFactor, borderPaint);

    // 內嵌高光點
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-1.5 * scaleFactor, -1.5 * scaleFactor),
      2.0 * scaleFactor,
      highlightPaint,
    );

    // 若被選中，繪製外圍脈衝光環
    if (isSelected) {
      final ringPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * scaleFactor;
      canvas.drawCircle(centerOffset, (markerRadius + 4.0) * scaleFactor, ringPaint);
    }

    // 4. 縮放足夠 (zoom >= 1.3) 時，繪製景點名與 Google Maps 評分標籤
    if (zoom >= 1.3 || isSelected) {
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
    final titleText = attraction.title;
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
}
