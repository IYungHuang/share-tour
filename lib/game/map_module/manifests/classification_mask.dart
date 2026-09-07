import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math.dart';

/// 從 PNG 解碼出的地理範圍分類遮罩（SPEC C v6 §2.2 規則 4）。
///
/// 取代已刪除的道路吸附：吸附是把玩家拉到某個點，錯誤不可回復；遮罩只
/// 判斷位置合不合法，不改動座標，只標記 coverage。
///
/// 解碼一次後量化成查表用的 [Uint8List]，之後每次查詢都是常數時間的陣列
/// 存取（NFR-4），不重新解碼圖檔。
class ClassificationMask {
  ClassificationMask._(this._inside, this.width, this.height, this.scale);

  /// 海洋色（ARGB）。此顏色視為範圍外，其餘顏色一律視為範圍內——
  /// 本模組只需要二元的陸/海判定，不需要更細的地形分類。
  static const int _oceanArgb = 0xFF0000FF;

  static Future<ClassificationMask> loadFromAsset(
    String assetPath, {
    required int scale,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('無法解碼分類遮罩：$assetPath');
    }
    final width = image.width;
    final height = image.height;
    final bytes = byteData.buffer.asUint8List();
    final inside = Uint8List(width * height);
    for (var i = 0; i < width * height; i++) {
      final r = bytes[i * 4];
      final g = bytes[i * 4 + 1];
      final b = bytes[i * 4 + 2];
      final argb = 0xFF000000 | (r << 16) | (g << 8) | b;
      inside[i] = argb == _oceanArgb ? 0 : 1;
    }
    return ClassificationMask._(inside, width, height, scale);
  }

  final Uint8List _inside;
  final int width;
  final int height;
  final int scale;

  /// [mapPixel] 為主圖層像素座標；內部除以 [scale] 換算為遮罩座標。
  /// 換算後落在遮罩畫布外一律視為範圍外，不拋例外——投影對凸包外的輸入
  /// 做線性外插，換算後的座標可能遠在畫布之外。
  bool isInside(Vector2 mapPixel) {
    final mx = (mapPixel.x / scale).floor();
    final my = (mapPixel.y / scale).floor();
    if (mx < 0 || mx >= width || my < 0 || my >= height) return false;
    return _inside[my * width + mx] != 0;
  }
}
