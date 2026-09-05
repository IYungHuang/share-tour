import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';

import '../../core/build_flags.dart';
import '../../core/time/clock.dart';
import '../../core/time/system_clock.dart';
import '../../data/location/virtual_location_source.dart';
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
  late final VirtualLocationSource _source;

  LocationController get controller => _controller;

  @override
  LocationControllerState build() {
    _controller = LocationController.forTest(
      manifest: ref.watch(mapManifestProvider),
      clock: ref.watch(clockProvider),
      flags: ref.watch(buildFlagsProvider),
    );
    _source = ref.watch(virtualSourceProvider);

    final sub = _source.fixes.listen((fix) {
      _controller.ingest(fix);
      state = _controller.state;
    });
    ref.onDispose(sub.cancel);
    _source.start();

    // 桌面與模擬器沒有定位硬體，開場即以方向鍵模式起步（NFR-6）。
    _controller.onPermissionChanged(PermissionState.unavailable);
    return _controller.state;
  }

  void setDirection(double x, double y) {
    _source.setDirection(Vector2(x, y));
    state = _controller.state;
  }

  void stopMoving() {
    _source.stopMoving();
    state = _controller.state;
  }

  void switchMode(SourceMode mode) {
    _controller.switchMode(mode, automatic: false);
    state = _controller.state;
  }
}
