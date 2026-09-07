import 'dart:async';
import 'dart:io' show Platform;

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
      hasAccuracy: _measured(p.hasAccuracy, p.accuracy),
      speedMetersPerSecond: p.speed,
      hasSpeed: _measured(p.hasSpeed, p.speed),
      speedAccuracy: p.speedAccuracy,
      hasSpeedAccuracy: _measured(p.hasSpeedAccuracy, p.speedAccuracy),
      timestampUtc: p.timestamp.toUtc(),
      isMocked: p.isMocked,
      sourceMode: SourceMode.gps,
    );

/// 已量測旗標的平台缺陷修復。
///
/// geolocator_android 5.0.3 的 `AndroidPosition.fromMap` 先用 `Position.fromMap`
/// 算出正確的 `has*` 旗標，再把數值逐一搬進 `AndroidPosition` 的建構子——而
/// 那個建構子沒有 `has*` 參數，旗標於是全部掉回父類預設 `false`。Android 上
/// 因此每一筆 Fix 都宣稱「精度未量測」，實測 100% 被 REQ-C-03 規則 1 丟棄，
/// 里程恆為 0。iOS 直接用 `Position.fromMap`，不受影響。
///
/// 資訊沒有真的遺失：`LocationMapper.java` 對每個選用欄位都是
/// `if (location.hasAccuracy()) position.put("accuracy", ...)`——平台沒量到就
/// 整個省略 key，Dart 端的 `_toDouble(null)` 補上 `0.0`。所以在 Android 上
/// 「值非零」與「量測過」等價，這是把被丟掉的那一位元從另一個管道讀回來，
/// 不是拿佔位值當測量值。
///
/// 旗標為真時一律尊重旗標，不因值為 0 而推翻它。
///
/// 速度恰為 0 的靜止讀數會被判為未量測——無法與真正的未量測區分，而這個
/// 方向是安全的：後果僅是裝置速度不參與 REQ-C-03 規則 5 的交叉檢查，兩點
/// 差分照常，正是規格對未量測速度規定的行為。
///
/// 上游修好後這段仍然無害（旗標為真即短路）。**在確認 `AndroidPosition`
/// 的建構子已接受 `has*` 參數之前，不要刪除它。**
bool _measured(bool platformFlag, double value) => platformFlag || value > 0;

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

/// 建構平台特定的定位設定（REQ-C-02 規則 5）。
///
/// 獨立成函式而非直接寫在 `start()` 內，是為了在無真機的條件下驗證
/// Android 分支確實帶上了更新間隔——`isAndroid` 由呼叫端傳入而非在此
/// 讀 `Platform.isAndroid`，讓這條分支邏輯本身可測。
///
/// iOS 的 `CLLocationManager` 沒有對應的更新間隔參數，維持原樣使用
/// 基底的 `LocationSettings`。
LocationSettings buildLocationSettings({
  required int distanceFilterMeters,
  required bool isAndroid,
}) {
  if (isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
      intervalDuration: const Duration(seconds: 1),
    );
  }
  return LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: distanceFilterMeters,
  );
}

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
      locationSettings: buildLocationSettings(
        distanceFilterMeters: distanceFilterMeters,
        isAndroid: Platform.isAndroid,
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
    //
    // 例外是在【被訂閱的當下】從平台頻道拋出來的，所以 try 必須罩住 listen
    // 本身。先前那種「try 住 getServiceStatusStream() 再回傳串流」的寫法
    // 沒罩到真正會拋的那一行；改成 async* 也不行，錯誤會繞過 yield* 的 try
    // 直接傳給訂閱端。
    final controller = StreamController<bool>();
    controller.onListen = () {
      try {
        final sub = Geolocator.getServiceStatusStream()
            .map((s) => s == ServiceStatus.enabled)
            .listen(controller.add, onError: (Object _) {});
        controller.onCancel = sub.cancel;
      } catch (_) {
        // 無平台繫結或平台不支援：這條訊息就是沒有，不是錯誤。
      }
    };
    return controller.stream;
  }


  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
