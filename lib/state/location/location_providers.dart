import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';

import '../../core/build_flags.dart';
import '../../core/time/clock.dart';
import '../../core/time/system_clock.dart';
import '../../data/location/geolocator_location_source.dart';
import '../../domain/location/models/location_permission_gateway.dart';
import '../../data/location/location_source.dart';
import '../../data/location/virtual_location_source.dart';
import '../../data/location/location_subscription_manager.dart';
import '../../data/location/wakelock_control.dart';
import '../../domain/location/pipeline/fix_throttle.dart';
import '../../domain/location/pipeline/permission_resolver.dart';
import '../../domain/location/pipeline/relocation_detector.dart';
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

/// GPS 訂閱的生命週期與省電。虛擬來源不經過它——它沒有平台訂閱要管，
/// 也不該因為進背景就停下方向鍵。
final subscriptionManagerProvider = Provider<LocationSubscriptionManager>((ref) {
  final manager = LocationSubscriptionManager(
    source: ref.watch(realSourceProvider),
    clock: ref.watch(clockProvider),
    manifest: ref.watch(mapManifestProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// 應用層節流（REQ-C-02 規則 6）。虛擬 Fix 由它自己放行，不合併。
final fixThrottleProvider = Provider<FixThrottle>((ref) {
  final throttle = FixThrottle(
    clock: ref.watch(clockProvider),
    window: const Duration(seconds: 1),
  );
  ref.onDispose(throttle.dispose);
  return throttle;
});

/// 螢幕喚醒鎖（REQ-C-16）。不是抽象——見 WakelockControl 的文件註解。
final wakelockControlProvider =
    Provider<WakelockControl>((_) => WakelockControl());

final locationControllerProvider =
    NotifierProvider<LocationNotifier, LocationControllerState>(
        LocationNotifier.new);

/// 定位狀態的唯一寫入點在 Riverpod 側的門面。
///
/// 只轉發意圖，不含判定邏輯——邏輯全在 LocationController 組裝的純函式裡。
class LocationNotifier extends Notifier<LocationControllerState> {
  late final LocationController _controller;
  late final VirtualLocationSource _virtual;
  late final LocationSubscriptionManager _subscriptions;
  late final FixThrottle _throttle;
  late final PermissionResolver _resolver;

  /// 目前作用中來源 → 節流的訂閱。切換模式時換掉的是這一條。
  StreamSubscription<GeoFix>? _sourceSub;

  /// 節流 → 控制器的訂閱。它與模式無關，建立一次即可。
  StreamSubscription<GeoFix>? _ingestSub;
  StreamSubscription<PermissionState>? _permissionSub;

  LocationController get controller => _controller;

  @override
  LocationControllerState build() {
    _controller = LocationController.forTest(
      manifest: ref.watch(mapManifestProvider),
      clock: ref.watch(clockProvider),
      flags: ref.watch(buildFlagsProvider),
      ignoreMockedFlag: ref.watch(ignoreMockedFlagProvider),
    )..traceIngestion = !ref.watch(buildFlagsProvider).isRelease;
    _virtual = ref.watch(virtualSourceProvider);
    _subscriptions = ref.watch(subscriptionManagerProvider);
    _throttle = ref.watch(fixThrottleProvider);
    _resolver = ref.watch(permissionResolverProvider);
    final wakelock = ref.watch(wakelockControlProvider);

    // REQ-C-16 規則 6：keepAwakeActive 的值變化驅動喚醒鎖的開關。用
    // listenSelf 而非在每個寫 state 的地方各自呼叫一次，才不會有遺漏。
    listenSelf((previous, next) {
      final was = previous?.diagnostics.keepAwakeActive ?? false;
      final now = next.diagnostics.keepAwakeActive;
      if (now == was) return;
      unawaited(now ? wakelock.enable() : wakelock.disable());
    });

    ref.onDispose(() {
      _sourceSub?.cancel();
      _ingestSub?.cancel();
      _permissionSub?.cancel();
      // NFR-5：外部副作用（含喚醒抑制）必須隨 dispose 完全釋放，否則玩家
      // 手機不再自動熄屏，且無從得知原因。
      unawaited(wakelock.disable());
    });

    // 服務開關與精度劣化都會從這條串流推過來（REQ-C-01 規則 4、規則 7）。
    // 不訂閱的話，玩家在遊戲中關掉定位服務，app 只會安靜地收不到 Fix——
    // 而「壞了」與「沒訊號」在畫面上長得一模一樣。
    _permissionSub = _resolver.states.listen(_applyPermission);

    // 兩段串接：來源 → 節流 → 控制器。先前是來源直接進控制器，
    // 節流與訂閱管理兩層都被跳過——寫好、測過、沒接線。
    _ingestSub = _throttle.output.listen((fix) {
      _controller.ingest(fix);
      _syncDiagnostics();
      state = _controller.state;
    });

    // 開場走方向鍵：桌面與模擬器沒有定位硬體（NFR-6），而且不主動跳系統
    // 權限對話框——那應該是玩家按下 GPS 按鈕時才發生的事。
    _controller.onPermissionChanged(PermissionState.unavailable);
    unawaited(_bindSource(SourceMode.virtual));
    return _controller.state;
  }

  Future<void> _bindSource(SourceMode mode) async {
    await _sourceSub?.cancel();
    if (mode == SourceMode.gps) {
      _sourceSub = _subscriptions.fixes.listen((fix) {
        // 精度等級的啟發式必須在品質過濾【之前】評估（§3.0 第 2 步）：
        // 排在之後的話這些 Fix 早被丟光，精度劣化就無從判定。
        _resolver.observeRawFix(accuracyMeters: fix.accuracyMeters);
        _throttle.add(fix);
      });
      _virtual.stopMoving();
      _virtual.stop();
    } else {
      _sourceSub = _virtual.fixes.listen(_throttle.add);
      _virtual.start();
    }
    // 訂閱管理器依模式自行決定要不要持有平台訂閱（REQ-C-11 規則 3）。
    // 必須等它完成：平台訂閱的建立是非同步的，不等就會在訂閱還沒建立時
    // 讀到「訂閱數 0」，而那與「訂閱失敗」無法區分。
    await _subscriptions.onModeChanged(mode);
    _syncDiagnostics();
  }

  /// 把 data 層的訂閱與省電實況送進控制器的診斷快照。
  void _syncDiagnostics() {
    _controller
      ..subscriptionCount = _subscriptions.activeSubscriptionCount
      ..powerMode = _subscriptions.powerMode;
  }

  /// app 進入背景。取消訂閱與否由訂閱管理器的寬限期決定，不在這裡判斷。
  void onAppBackground() {
    _controller.isForeground = false;
    _subscriptions.onBackground();
    // 寬限期到期是非同步的，屆時沒有人會再讀 state；改由下一次狀態同步帶出。
    _refreshLater();
  }

  Future<void> onAppForeground() async {
    _controller.isForeground = true;
    final resubscribed = await _subscriptions.onForeground();
    if (resubscribed) {
      // 訂閱斷過的期間沒有任何 Fix。那段位移無從得知是走的還是搭車的，
      // 不能計入里程——首筆改走不連續路徑。
      _controller.markDiscontinuity(RelocationNote.backgroundResume);
    }
    _syncDiagnostics();
    state = _controller.state;
  }

  /// 權限狀態變化的統一入口：串流推來的與主動查詢的走同一段邏輯。
  Future<void> _applyPermission(PermissionState permission) async {
    final previousMode = _controller.state.status.mode;
    _controller.onPermissionChanged(permission);

    const unusable = {
      PermissionState.denied,
      PermissionState.deniedForever,
      PermissionState.serviceDisabled,
      PermissionState.approximate,
      PermissionState.unavailable,
    };
    // 定位不可用時連 powerMode 一起降下來（REQ-C-11 規則 3），恢復時升回。
    await _subscriptions
        .setPowerMode(unusable.contains(permission) ? PowerMode.suspended : PowerMode.active);

    final mode = _controller.state.status.mode;
    if (mode != previousMode) await _bindSource(mode);
    _syncDiagnostics();
    state = _controller.state;
  }

  /// 寬限期或 debounce 到期後才會改變的診斷欄位，需要一次延後的同步。
  void _refreshLater() {
    Future<void>(() {
      _syncDiagnostics();
      state = _controller.state;
    });
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
    final permission = await _resolver.resolve();
    await _applyPermission(permission);
    if (permission == PermissionState.ready) {
      _controller.switchMode(SourceMode.gps, automatic: false);
    }
    await _bindSource(_controller.state.status.mode);
    state = _controller.state;
  }

  Future<void> switchToVirtual() async {
    _controller.switchMode(SourceMode.virtual, automatic: false);
    await _bindSource(SourceMode.virtual);
    state = _controller.state;
  }

  /// 切換當前圖資模組（宏觀盆地 ⇄ 中觀街區）
  void switchManifest(OverworldMapManifest newManifest, {Vector2? newSpawnPixel}) {
    _controller.switchManifest(newManifest, newSpawnPixel: newSpawnPixel);
    _syncDiagnostics();
    state = _controller.state;
  }
}
