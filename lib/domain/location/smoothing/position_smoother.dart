import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../projection/map_manifest.dart';

/// 平滑位移。
///
/// GPS 只寫目標點，顯示點逐幀趨近它。收斂用 1 - exp(-k·dt) 而非固定係數的 lerp：
/// 後者在 120Hz 與 30Hz 裝置上速度不同，同樣的一秒走過不同的距離。
///
/// 門檻以公尺定義再換算成像素。用像素定義會隨地圖尺度失真——在大地圖上 1 像素
/// 等於 370 公尺，玩家在一個街區內移動會被判定為「已抵達」而完全不動。
///
/// 換算的求值契約：以【當前顯示點】查詢比例，每次目標點更新時重算一次並沿用。
/// 非線性地圖上這個比例逐點變化，不釘死求值點與時機，兩個人會寫出行為不同而
/// 各自「正確」的實作。也因此 update() 內不得查詢比例——那會讓每幀成本取決於
/// 投影演算法。
class PositionSmoother {
  PositionSmoother({
    required OverworldMapManifest manifest,
    required Duration halfLife,
    required this.arrivalMeters,
    required this.headingMeters,
  })  : _manifest = manifest,
        _decay = math.ln2 / (halfLife.inMicroseconds / 1e6) {
    _recomputeThresholds();
  }

  final OverworldMapManifest _manifest;
  final double _decay;
  final double arrivalMeters;
  final double headingMeters;

  final Vector2 _rendered = Vector2.zero();
  final Vector2 _target = Vector2.zero();

  double _arrivalPixels = 0;
  double _headingPixels = 0;
  double _heading = 0;

  Vector2 get rendered => _rendered.clone();
  double get headingRadians => _heading;
  double get arrivalThresholdPixels => _arrivalPixels;
  double get headingThresholdPixels => _headingPixels;

  /// 設定目標點。此時以當前顯示點查詢比例並重算門檻。
  void setTarget(Vector2 target) {
    // setFrom 而非指派：Vector2 可變，參考指派會讓之後對呼叫端向量的寫入
    // 同時改掉目標點，平滑靜默失效，而「顯示點趨近目標點」照樣通過測試。
    _target.setFrom(target);
    _recomputeThresholds();
  }

  /// 換層或首次定位：不平滑，直接指定顯示點。
  void jumpTo(Vector2 position) {
    _rendered.setFrom(position);
    _target.setFrom(position);
    _recomputeThresholds();
  }

  void update(double dt) {
    final delta = _target - _rendered;
    final distance = delta.length;
    if (distance <= _arrivalPixels) return;

    // 幀率無關的指數收斂。
    final t = 1 - math.exp(-_decay * dt);
    final step = delta * t;
    _rendered.add(step);

    // 朝向只在單幀位移夠大時更新，避免原地抖動亂轉。
    if (step.length > _headingPixels) {
      _heading = math.atan2(step.y, step.x);
    }
  }

  void _recomputeThresholds() {
    final mpp = _manifest.metersPerPixelAt(_rendered);
    _arrivalPixels = arrivalMeters / mpp;
    _headingPixels = headingMeters / mpp;
  }
}
