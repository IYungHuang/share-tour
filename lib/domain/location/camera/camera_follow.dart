import 'package:vector_math/vector_math.dart';

import '../../../core/time/clock.dart';

enum CameraMode { following, free, returning }

/// 相機跟隨的純邏輯狀態機。
///
/// 由玩家位置、手勢事件與經過時間決定，完全不碰遊戲引擎的相機物件。寫成
/// 依賴 CameraComponent 的話，這些規則只能用 widget test 驗證，而規格要求
/// 所有邏輯需求都能在不啟動框架的條件下測試。
///
/// 邊界限制也在此：相機中心不得越出地圖，而地圖小於視口時取地圖中點——
/// 那是縮到很遠或小型地方層地圖的必然情形，不是邊緣案例。
class CameraFollow {
  CameraFollow({required Clock clock, required this.returnDelay})
      : _clock = clock;

  final Clock _clock;
  final Duration returnDelay;

  /// 回歸時每幀收斂的比例。純數值狀態機沒有 dt，用固定比例即可——
  /// 回歸是一次性的視覺過渡，不像位置平滑那樣需要幀率無關。
  static const double _returnLerp = 0.12;
  static const double _arrivedPixels = 0.5;

  CameraMode _mode = CameraMode.following;
  Duration? _lastInteraction;
  Vector2? _frozenCenter;

  CameraMode get mode => _mode;

  /// 手勢平移：交出控制權。
  void onPan() {
    _mode = CameraMode.free;
    _lastInteraction = _clock.elapsed;
  }

  /// 縮放刻意不算「操作」。捏合只是想看看四周，不該被當成接管相機，
  /// 也不該重置回歸計時器。
  void onZoom() {}

  /// 回到我的位置。
  void recenter() {
    _mode = CameraMode.following;
    _frozenCenter = null;
    _lastInteraction = null;
  }

  Vector2 targetCenter({
    required Vector2 player,
    required double zoom,
    required Vector2 viewportSize,
    required Vector2 mapSize,
  }) {
    final desired = _clamp(player, zoom, viewportSize, mapSize);

    switch (_mode) {
      case CameraMode.following:
        return desired;

      case CameraMode.free:
        final since = _lastInteraction;
        if (since != null && _clock.elapsed - since >= returnDelay) {
          _mode = CameraMode.returning;
        }
        return _frozenCenter ??= desired;

      case CameraMode.returning:
        final from = _frozenCenter ?? desired;
        final next = from + (desired - from) * _returnLerp;
        if ((desired - next).length <= _arrivedPixels) {
          _mode = CameraMode.following;
          _frozenCenter = null;
          return desired;
        }
        _frozenCenter = next;
        return next;
    }
  }

  Vector2 _clamp(
      Vector2 player, double zoom, Vector2 viewportSize, Vector2 mapSize) {
    final halfW = viewportSize.x / (2 * zoom);
    final halfH = viewportSize.y / (2 * zoom);
    final x = halfW * 2 >= mapSize.x
        ? mapSize.x / 2
        : player.x.clamp(halfW, mapSize.x - halfW);
    final y = halfH * 2 >= mapSize.y
        ? mapSize.y / 2
        : player.y.clamp(halfH, mapSize.y - halfH);
    return Vector2(x.toDouble(), y.toDouble());
  }
}
