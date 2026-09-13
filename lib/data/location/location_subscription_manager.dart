import 'dart:async';

import 'package:vector_math/vector_math.dart';

import '../../core/time/clock.dart';
import '../../domain/location/models/geo_fix.dart';
import '../../domain/location/models/location_status.dart';
import '../../domain/location/projection/map_manifest.dart';
import 'location_source.dart';

/// 管理定位訂閱的生命週期與省電。
///
/// 短暫進入背景——來電、下拉通知欄、切到相機打卡——不取消訂閱，恢復時再加上
/// debounce。每次前後景切換都重建串流會強迫 GPS 反覆冷啟，在通知繁忙的裝置上
/// 幾乎不能玩。
///
/// 冷啟動一律由圖資模組的預設降落點起步，不查詢平台的最後已知位置：那省下的
/// 一秒空白，代價是整條管線都要傳遞一條「不得成為基準」的特例規則。
class LocationSubscriptionManager {
  LocationSubscriptionManager({
    required LocationSource source,
    required Clock clock,
    required OverworldMapManifest manifest,
    this.backgroundGrace = const Duration(seconds: 20),
    this.resumeDebounce = const Duration(seconds: 2),
  }) : _source = source,
       _clock = clock,
       _manifest = manifest;

  final LocationSource _source;
  final Clock _clock;
  OverworldMapManifest _manifest;
  final Duration backgroundGrace;
  final Duration resumeDebounce;

  final _controller = StreamController<GeoFix>.broadcast();
  StreamSubscription<GeoFix>? _sub;
  Duration? _backgroundedAt;
  PowerMode _powerMode = PowerMode.active;
  SourceMode _mode = SourceMode.gps;

  Stream<GeoFix> get fixes => _controller.stream;
  int get activeSubscriptionCount => _sub == null ? 0 : 1;
  PowerMode get powerMode => _powerMode;

  /// 冷啟動的起始顯示點。
  Vector2 get initialRenderedPixel => _manifest.defaultSpawnPixel;

  Future<void> start() => _subscribe();

  /// 進入背景。寬限期由本類別自行排程——呼叫端只知道「進背景了」，
  /// 不該負責計時，否則每個接線點都要重複同一段邏輯。
  void onBackground() {
    final at = _clock.elapsed;
    _backgroundedAt = at;
    unawaited(_scheduleGrace(at));
  }

  Future<void> _scheduleGrace(Duration at) async {
    await _clock.delay(backgroundGrace);
    if (_backgroundedAt != at) return;
    // 背景超過寬限期即為 suspended（REQ-C-11 規則 3）。取消訂閱卻讓
    // powerMode 停在 active，診斷就會說「訂閱數 0、電源模式 active」——
    // 兩個欄位互相矛盾，讀的人無從判斷是哪裡壞了。
    _powerMode = PowerMode.suspended;
    await _unsubscribe();
  }

  /// 回到前景。回傳是否**重新建立過訂閱**——呼叫端據此決定要不要標記不連續：
  /// 訂閱斷過的期間沒有任何 Fix，那段位移不該被當成玩家走出來的里程。
  Future<bool> onForeground() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    _powerMode = PowerMode.active;
    if (_sub != null) return false; // 短暫背景，訂閱從未取消
    if (since == null) return false;
    await _clock.delay(resumeDebounce);
    await _subscribe();
    return _sub != null;
  }

  Future<void> setPowerMode(PowerMode mode) async {
    _powerMode = mode;
    await _applyDesiredState();
  }

  Future<void> onModeChanged(SourceMode mode) async {
    _mode = mode;
    await _applyDesiredState();
  }

  void switchManifest(OverworldMapManifest next) => _manifest = next;

  void dispose() {
    _sub?.cancel();
    _sub = null;
    // 來源也要停：NFR-5 要求遊戲實例重建時所有訂閱完全釋放，而平台層的
    // 定位請求不會因為 Dart 端不再監聽就自己關掉。
    unawaited(_source.stop());
    _controller.close();
  }

  bool get _shouldSubscribe =>
      _powerMode == PowerMode.active && _mode == SourceMode.gps;

  Future<void> _applyDesiredState() =>
      _shouldSubscribe ? _subscribe() : _unsubscribe();

  Future<void> _subscribe() async {
    if (_sub != null || !_shouldSubscribe) return;
    await _source.start();
    _sub = _source.fixes.listen((f) {
      if (_powerMode == PowerMode.active && !_controller.isClosed) {
        _controller.add(f);
      }
    });
  }

  Future<void> _unsubscribe() async {
    final sub = _sub;
    if (sub == null) return;
    _sub = null;
    await sub.cancel();
    await _source.stop();
  }
}
