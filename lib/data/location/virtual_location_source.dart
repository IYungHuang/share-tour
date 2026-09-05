import 'dart:async';

import 'package:vector_math/vector_math.dart';

import '../../core/build_flags.dart';
import '../../core/time/clock.dart';
import '../../domain/location/models/geo_fix.dart';
import '../../domain/location/projection/map_manifest.dart';
import 'location_source.dart';

/// 虛擬定位來源。
///
/// 同時服務兩件事：正式建置的方向鍵玩法，以及除錯用的點擊尋路與跳點。
/// 兩者共用同一個抽象，所以同一組下游測試能驗證兩種來源。
///
/// 它繞過平台的距離門檻與應用層節流，以固定頻率產生 Fix。步行 5 km/h 通過
/// 10 公尺距離門檻要 7.2 秒才產生一筆，方向鍵會完全不能玩——而方向鍵是正式
/// 功能，不是除錯用的權宜。
///
/// 速度以【像素/秒】由圖層宣告，不用真實世界速度：在 370 公尺/像素的大地圖上
/// 步行 5 km/h 要 4.4 分鐘才移動一個像素。
class VirtualLocationSource implements LocationSource {
  VirtualLocationSource({
    required OverworldMapManifest manifest,
    required Clock clock,
    required this.hertz,
  })  : _manifest = manifest,
        _clock = clock,
        _pixel = manifest.defaultSpawnPixel.clone();

  final OverworldMapManifest _manifest;
  final Clock _clock;
  final int hertz;

  final _controller = StreamController<GeoFix>.broadcast();
  final Vector2 _pixel;
  Vector2 _direction = Vector2.zero();
  bool _running = false;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  /// 產生 Fix 的間隔。對外公開，呼叫端（含測試）不必自行推導——
  /// 差一微秒就會與內部的到期時間錯開每一拍。
  Duration get interval => Duration(microseconds: 1000000 ~/ hertz);

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  /// 方向鍵。傳入單位向量；零向量等同停止。
  void setDirection(Vector2 unitDirection) {
    _direction = unitDirection.length2 == 0
        ? Vector2.zero()
        : (unitDirection.normalized());
  }

  void stopMoving() => _direction = Vector2.zero();

  /// 除錯：點擊地圖尋路。反投影成經緯度後注入，與正式路徑共用其後所有步驟。
  void tapNavigateTo(Vector2 pixel) {
    _pixel.setFrom(pixel);
    _direction = Vector2.zero();
  }

  /// 除錯：直接跳到指定經緯度。
  void teleportTo(double lat, double lng) {
    _pixel.setFrom(_manifest.projectToPixel(lat, lng));
    _direction = Vector2.zero();
  }

  Future<void> _loop() async {
    final dt = 1.0 / hertz;
    while (_running) {
      await _clock.delay(interval);
      if (!_running) break;
      if (_direction.length2 > 0) {
        _pixel.add(_direction * (_manifest.dpadSpeedPixelsPerSecond * dt));
      }
      _controller.add(_emit());
    }
  }

  GeoFix _emit() {
    final geo = _manifest.unprojectToGeo(_pixel);
    return GeoFix(
      latitude: geo.latitude,
      longitude: geo.longitude,
      // 合成資料沒有量測誤差，但旗標仍為真：下游的顯著性閘門用精度算門檻，
      // 給一個確實量測過的小值才能讓每一步都算顯著。
      accuracyMeters: 1.0,
      hasAccuracy: true,
      speedMetersPerSecond: 0,
      hasSpeed: false,
      speedAccuracy: 0,
      hasSpeedAccuracy: false,
      timestampUtc: _clock.nowUtc(),
      isMocked: false,
      sourceMode: SourceMode.virtual,
    );
  }
}

/// 除錯專用來源的工廠。
///
/// release 時回傳 null，所以「正式建置不含除錯入口」是一條可斷言的事實，
/// 而不是一個靠自律維持的慣例。
VirtualLocationSource? debugSourceFactory({
  required BuildFlags flags,
  required OverworldMapManifest manifest,
  required Clock clock,
}) {
  if (flags.isRelease) return null;
  return VirtualLocationSource(manifest: manifest, clock: clock, hertz: 15);
}
