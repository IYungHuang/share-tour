import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/location/models/geo_fix.dart';
import 'location_permission_gateway.dart';
import 'location_source.dart';

/// 把平台的 Position 轉成 GeoFix。
///
/// 這是純轉換，不含任何判定——所有品質、顯著性、範圍判定都在 domain。
/// 轉接層一旦開始「順手過濾一下」，同一條規則就會有兩個實作而遲早漂移。
///
/// 已量測旗標必須原樣帶過。平台在無法量測時回傳 0.0 佔位值，而 0.0 同時也是
/// 合法的零誤差與靜止讀數；丟掉旗標，下游就會把「未量測」當成「完美」，
/// 同時關掉精度閘門與速度閘門。
GeoFix geoFixFromPosition(Position p) => GeoFix(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: p.accuracy,
      hasAccuracy: p.hasAccuracy,
      speedMetersPerSecond: p.speed,
      hasSpeed: p.hasSpeed,
      speedAccuracy: p.speedAccuracy,
      hasSpeedAccuracy: p.hasSpeedAccuracy,
      timestampUtc: p.timestamp.toUtc(),
      isMocked: p.isMocked,
      sourceMode: SourceMode.gps,
    );

PlatformPermission mapPlatformPermission(LocationPermission p) => switch (p) {
      LocationPermission.denied => PlatformPermission.denied,
      LocationPermission.deniedForever => PlatformPermission.deniedForever,
      LocationPermission.whileInUse => PlatformPermission.granted,
      LocationPermission.always => PlatformPermission.granted,
      LocationPermission.unableToDetermine => PlatformPermission.notDetermined,
    };

PlatformAccuracy mapPlatformAccuracy(LocationAccuracyStatus s) => switch (s) {
      LocationAccuracyStatus.precise => PlatformAccuracy.precise,
      LocationAccuracyStatus.reduced => PlatformAccuracy.reduced,
      LocationAccuracyStatus.unknown => PlatformAccuracy.unavailable,
    };

/// 真實 GPS 來源。
///
/// 平台層的距離門檻是主要省電手段：它的語意是「移動未達門檻就不推送」，
/// 這也是為什麼靜止判定與訊號健康度都不能靠「有沒有收到 Fix」來做。
class GeolocatorLocationSource implements LocationSource {
  GeolocatorLocationSource({this.distanceFilterMeters = 10});

  final int distanceFilterMeters;

  final _controller = StreamController<GeoFix>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<void> start() async {
    if (_sub != null) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).listen((p) {
      if (!_controller.isClosed) _controller.add(geoFixFromPosition(p));
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

/// geolocator 的權限查詢實作。
///
/// 這些能力在 geolocator 上全是靜態方法，包成介面才能在無真機的條件下
/// 驗證權限流程。
class GeolocatorPermissionGateway implements LocationPermissionGateway {
  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false; // 平台不支援：視同服務不可用，上層退回方向鍵
    }
  }

  @override
  Future<PlatformPermission> checkPermission() async {
    try {
      return mapPlatformPermission(await Geolocator.checkPermission());
    } catch (_) {
      return PlatformPermission.denied;
    }
  }

  @override
  Future<PlatformPermission> requestPermission() async =>
      mapPlatformPermission(await Geolocator.requestPermission());

  @override
  Future<PlatformAccuracy> getAccuracy() async {
    try {
      return mapPlatformAccuracy(await Geolocator.getLocationAccuracy());
    } catch (_) {
      // 桌面與部分平台不提供精度等級查詢。視為不可用，讓上層走方向鍵模式。
      return PlatformAccuracy.unavailable;
    }
  }

  @override
  Stream<bool> get serviceEnabledChanges {
    // 桌面等平台不提供服務狀態串流。訂閱失敗不該讓整個 app 掛掉——
    // 沒有這條訊息只代表偵測不到服務被關閉，其餘流程照常。
    try {
      return Geolocator.getServiceStatusStream()
          .map((s) => s == ServiceStatus.enabled)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
