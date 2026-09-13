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

  /// 尚未套用到凍結中心的手勢位移，累積於幀與幀之間。
  ///
  /// 手勢事件與相機求值不同步：一幀內可能來好幾筆 delta，也可能一筆都沒有。
  /// 累積起來、在下一次求值時一次套用並歸零，才能讓「同一次平移只生效一次」。
  final Vector2 _pendingPan = Vector2.zero();

  /// QTE 期間累積的暫停位移（REQ-M5-10.7）。從 [_lastInteraction] 起算的
  /// 經過時間會扣掉這段累積量，讓暫停期間「不計時」，且不需要碰共用的
  /// 注入時鐘——`suspend`/`resume` 只操作這個局域欄位。
  Duration _suspendedShift = Duration.zero;
  Duration? _suspendStartedAt;

  CameraMode get mode => _mode;

  /// 供測試讀取的 side-effect-free 狀態（AC-M5-4.3a）。
  /// 命名刻意帶 `ForTest` 後綴，避免生產程式碼誤用作正常讀取路徑——
  /// 正常路徑一律透過 [targetCenter] 求值。
  Vector2? get frozenCenterForTest => _frozenCenter?.clone();
  Vector2 get pendingPanForTest => _pendingPan.clone();
  Duration? get lastInteractionForTest => _lastInteraction;

  /// 暫停回歸計時（REQ-M5-10.7，QTE 開始時呼叫）。重複呼叫是 no-op。
  void suspend() {
    _suspendStartedAt ??= _clock.elapsed;
  }

  /// 恢復回歸計時（QTE 結束時呼叫）。把暫停期間的經過時間計入累積位移，
  /// 之後 [targetCenter] 比較 `returnDelay` 時會扣掉這段時間。
  void resume() {
    final startedAt = _suspendStartedAt;
    if (startedAt == null) return;
    _suspendedShift += _clock.elapsed - startedAt;
    _suspendStartedAt = null;
  }

  /// 手勢平移：交出控制權，並記下位移量。
  ///
  /// [deltaWorld] 是手指在**世界座標**的位移（呼叫端需先除以 zoom）。相機中心
  /// 與手指反向移動——手指往右拖，看到的是地圖左邊的內容。
  ///
  /// 位移量必須由狀態機持有。引擎端自己去寫相機位置的話，會與每幀的
  /// targetCenter 形成雙頭寫入，而後者每幀都會把前者蓋掉。
  void onPan(Vector2 deltaWorld) {
    _mode = CameraMode.free;
    _lastInteraction = _clock.elapsed;
    _pendingPan.add(deltaWorld);
  }

  /// 縮放刻意不算「操作」。捏合只是想看看四周，不該被當成接管相機，
  /// 也不該重置回歸計時器。
  void onZoom() {}

  /// 回到我的位置。
  void recenter() {
    _mode = CameraMode.following;
    _frozenCenter = null;
    _lastInteraction = null;
    _pendingPan.setZero();
    _suspendedShift = Duration.zero;
    _suspendStartedAt = null;
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
        final base = _frozenCenter ?? desired;
        final panned = _clamp(base - _pendingPan, zoom, viewportSize, mapSize);
        _pendingPan.setZero();
        _frozenCenter = panned;

        final since = _lastInteraction;
        if (since != null &&
            _clock.elapsed - since - _suspendedShift >= returnDelay) {
          _mode = CameraMode.returning;
        }
        // 回傳副本：交出內部狀態的參考，呼叫端一改就靜默改到凍結中心。
        return panned.clone();

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

  /// 把任一候選中心夾進地圖邊界。玩家位置與平移後的自由中心共用同一條規則。
  Vector2 _clamp(
      Vector2 point, double zoom, Vector2 viewportSize, Vector2 mapSize) {
    final halfW = viewportSize.x / (2 * zoom);
    final halfH = viewportSize.y / (2 * zoom);
    final x = halfW * 2 >= mapSize.x
        ? mapSize.x / 2
        : point.x.clamp(halfW, mapSize.x - halfW);
    final y = halfH * 2 >= mapSize.y
        ? mapSize.y / 2
        : point.y.clamp(halfH, mapSize.y - halfH);
    return Vector2(x.toDouble(), y.toDouble());
  }
}
