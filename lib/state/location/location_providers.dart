import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';

import '../../core/build_flags.dart';
import '../../core/time/clock.dart';
import '../../core/time/system_clock.dart';
import '../../data/location/geolocator_location_source.dart';
import '../../data/location/location_permission_gateway.dart';
import '../../data/location/location_source.dart';
import '../../data/location/virtual_location_source.dart';
import '../../domain/location/pipeline/permission_resolver.dart';
import '../../domain/location/models/geo_fix.dart';
import '../../domain/location/models/location_status.dart';
import '../../domain/location/projection/map_manifest.dart';
import 'location_controller.dart';

/// 可覆寫的注入點。測試以 overrides 換掉整組相依，正式路徑用預設值。
final clockProvider = Provider<Clock>((_) => SystemClock());

final buildFlagsProvider =
    Provider<BuildFlags>((_) => const BuildFlags.debug());

/// 圖資由外部注入。通用引擎不得自己建立特定城市的模組。
final mapManifestProvider = Provider<OverworldMapManifest>(
  (_) => throw UnimplementedError('必須在 ProviderScope 覆寫此 provider 注入圖資'),
);

/// 除錯建置下忽略 isMocked 標記。
///
/// 模擬器注入的座標與 GPX 除錯路徑都會被平台標記為模擬定位，而正式規則會把
/// 它們歸到 virtual 桶——於是開發機上永遠測不出 gps 模式的行為。
/// 正式建置一律不忽略：那個標記是誠實歸屬的一部分。
final ignoreMockedFlagProvider = Provider<bool>(
  (ref) => !ref.watch(buildFlagsProvider).isRelease,
);

final permissionGatewayProvider = Provider<LocationPermissionGateway>(
  (_) => GeolocatorPermissionGateway(),
);

final permissionResolverProvider = Provider<PermissionResolver>((ref) {
  final resolver =
      PermissionResolver(gateway: ref.watch(permissionGatewayProvider));
  ref.onDispose(resolver.dispose);
  return resolver;
});

final realSourceProvider = Provider<LocationSource>((ref) {
  final source = GeolocatorLocationSource(distanceFilterMeters: 10);
  ref.onDispose(source.dispose);
  return source;
});

final virtualSourceProvider = Provider<VirtualLocationSource>((ref) {
  final source = VirtualLocationSource(
    manifest: ref.watch(mapManifestProvider),
    clock: ref.watch(clockProvider),
    hertz: 15,
  );
  ref.onDispose(source.stop);
  return source;
});

final locationControllerProvider =
    NotifierProvider<LocationNotifier, LocationControllerState>(
        LocationNotifier.new);

/// 定位狀態的唯一寫入點在 Riverpod 側的門面。
///
/// 只轉發意圖，不含判定邏輯——邏輯全在 LocationController 組裝的純函式裡。
class LocationNotifier extends Notifier<LocationControllerState> {
  late final LocationController _controller;
  late final VirtualLocationSource _virtual;
  late final LocationSource _real;
  StreamSubscription<GeoFix>? _sub;

  LocationController get controller => _controller;

  @override
  LocationControllerState build() {
    _controller = LocationController.forTest(
      manifest: ref.watch(mapManifestProvider),
      clock: ref.watch(clockProvider),
      flags: ref.watch(buildFlagsProvider),
      ignoreMockedFlag: ref.watch(ignoreMockedFlagProvider),
    );
    _virtual = ref.watch(virtualSourceProvider);
    _real = ref.watch(realSourceProvider);
    ref.onDispose(() => _sub?.cancel());

    // 開場走方向鍵：桌面與模擬器沒有定位硬體（NFR-6），而且不主動跳系統
    // 權限對話框——那應該是玩家按下 GPS 按鈕時才發生的事。
    _controller.onPermissionChanged(PermissionState.unavailable);
    _bindSource(SourceMode.virtual);
    return _controller.state;
  }

  void _bindSource(SourceMode mode) {
    _sub?.cancel();
    final source = mode == SourceMode.gps ? _real : _virtual;
    _sub = source.fixes.listen((fix) {
      _controller.ingest(fix);
      state = _controller.state;
    });
    source.start();
    if (mode == SourceMode.gps) {
      _virtual.stopMoving();
      _virtual.stop();
    } else {
      _real.stop();
    }
  }

  void setDirection(double x, double y) {
    _virtual.setDirection(Vector2(x, y));
    state = _controller.state;
  }

  void stopMoving() {
    _virtual.stopMoving();
    state = _controller.state;
  }

  /// 玩家主動要求切到 GPS。
  ///
  /// 權限對話框在此才出現——開場就跳，玩家還不知道這是什麼遊戲就被要求定位。
  /// 若權限或精度不可用，會依 REQ-C-13 自動退回方向鍵。
  Future<void> requestGpsMode() async {
    final permission = await ref.read(permissionResolverProvider).resolve();
    _controller.onPermissionChanged(permission);
    if (permission == PermissionState.ready) {
      _controller.switchMode(SourceMode.gps, automatic: false);
    }
    _bindSource(_controller.state.status.mode);
    state = _controller.state;
  }

  void switchToVirtual() {
    _controller.switchMode(SourceMode.virtual, automatic: false);
    _bindSource(SourceMode.virtual);
    state = _controller.state;
  }
}
