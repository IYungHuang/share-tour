import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/core_loop/kyoto_night_catalog.dart';
import 'data/core_loop/local_persistence_repository.dart';
import 'data/core_loop/taiwan_attraction_materials.dart';
import 'domain/core_loop/run/curator_run_phase.dart';
import 'domain/location/camera/camera_follow.dart';
import 'domain/location/models/district_attraction.dart';
import 'domain/location/models/geo_fix.dart';
import 'domain/location/models/location_status.dart';
import 'game/map_module/manifests/taiwan_map_manifest.dart';
import 'game/universal_overworld_game.dart';
import 'state/core_loop/curator_run_providers.dart';
import 'state/core_loop/persistence_providers.dart';
import 'state/location/location_providers.dart';
import 'ui/core_loop/briefing/curator_briefing_modal.dart';
import 'ui/core_loop/curator_studio_modal.dart';
import 'ui/core_loop/field/attraction_detail_card.dart';
import 'ui/core_loop/field/curator_field_hud.dart';
import 'ui/core_loop/field/gathering_floating_feedback_overlay.dart';
import 'ui/core_loop/gear_shop/gear_shop_modal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = LocalPersistenceRepository();

  // 分類遮罩解碼與本機存檔非同步並行預載水合 (Task M7, 零 FOUC)
  final (manifest, initialSave) = await (
    TaiwanMapManifest.load(),
    repo.loadSave(),
  ).wait;

  runApp(
    ProviderScope(
      // 圖資與城市 DLC 在此注入。通用引擎與狀態層都不知道自己跑的是哪座城市。
      overrides: [
        mapManifestProvider.overrideWithValue(manifest),
        curatorMaterialPoolProvider.overrideWithValue(kyotoNightMaterials),
        poiMaterialResolverProvider.overrideWithValue(
          const TaiwanPoiMaterialResolver(),
        ),
        persistenceRepositoryProvider.overrideWithValue(repo),
        initialSaveDataProvider.overrideWithValue(initialSave),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: OverworldScaffold(),
      ),
    ),
  );
}

class OverworldScaffold extends ConsumerStatefulWidget {
  const OverworldScaffold({super.key});

  @override
  ConsumerState<OverworldScaffold> createState() => _OverworldScaffoldState();
}

class _OverworldScaffoldState extends ConsumerState<OverworldScaffold>
    with WidgetsBindingObserver {
  late final UniversalOverworldGame _game;
  final ValueNotifier<DistrictAttraction?> _selectedAttraction = ValueNotifier(
    null,
  );
  final ValueNotifier<(AdministrativeDistrict?, int)> _focusedDistrict =
      ValueNotifier((null, 0));
  final GatheringFloatingFeedbackController _gatheringFeedbackController =
      GatheringFloatingFeedbackController();

  // EnginePauseCoordinator: 引用計數暫停協調器 (防範多層彈窗競爭與洩漏, AC-M4-4.4)
  int _enginePauseRefCount = 0;
  bool _isStudioModalOpen = false;
  bool _isBriefingModalOpen = false;
  bool _isGearShopModalOpen = false;

  void _pauseEngine() {
    _enginePauseRefCount++;
    if (_enginePauseRefCount == 1 && _game.isAttached && _game.isLoaded) {
      _game.pauseEngine();
    }
  }

  void _resumeEngine() {
    _enginePauseRefCount = (_enginePauseRefCount - 1).clamp(0, 99999);
    if (_enginePauseRefCount == 0 && mounted && _game.isAttached && _game.isLoaded) {
      _game.resumeEngine();
    }
  }

  Future<T?> _showModalSafely<T>(WidgetBuilder builder) async {
    _pauseEngine();
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: builder,
      );
    } finally {
      _resumeEngine();
    }
  }

  Future<void> _openCuratorStudioSafely() async {
    if (_isStudioModalOpen || !mounted) return;
    _isStudioModalOpen = true;
    _selectedAttraction.value = null;
    if (_game.isLoaded) {
      _game.attractionLayer.selectAttraction(null);
    }
    try {
      await _showModalSafely((ctx) => const CuratorStudioModal());
    } finally {
      _isStudioModalOpen = false;
    }
  }

  Future<void> _openBriefingModalSafely() async {
    if (_isBriefingModalOpen || !mounted) return;
    _isBriefingModalOpen = true;
    _selectedAttraction.value = null;
    if (_game.isLoaded) {
      _game.attractionLayer.selectAttraction(null);
    }
    try {
      await _showModalSafely(
        (ctx) => CuratorBriefingModal(
          onOpenGearShop: () => _openGearShopSafely(),
        ),
      );
    } finally {
      _isBriefingModalOpen = false;
    }
  }

  Future<void> _openGearShopSafely() async {
    if (_isGearShopModalOpen || !mounted) return;
    _isGearShopModalOpen = true;
    try {
      await _showModalSafely((ctx) => const GearShopModal());
    } finally {
      _isGearShopModalOpen = false;
    }
  }

  /// 前後景事件只有 widget 樹拿得到，所以由這裡轉發給定位層。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(locationControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        notifier.onAppForeground();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        notifier.onAppBackground();
      case AppLifecycleState.inactive:
        break; // 通知欄下拉、來電中——還沒真的離開，不必動訂閱
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectedAttraction.dispose();
    _focusedDistrict.dispose();
    _gatheringFeedbackController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifier = ref.read(locationControllerProvider.notifier);
    _game = UniversalOverworldGame(
      manifest: ref.read(mapManifestProvider),
      onTick: notifier.controller.tick,
      renderedPixelOf: () => notifier.controller.state.renderedPixel,
      cameraFollow: CameraFollow(
        clock: ref.read(clockProvider),
        returnDelay: const Duration(seconds: 3),
      ),
      onAttractionSelected: (a) => _selectedAttraction.value = a,
      onDistrictRevealed: (d, count) => _focusedDistrict.value = (d, count),
    );

    // 啟動開場自動引導：若處於 philosophizing 階段則主動彈出行前委託底抽屜
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(curatorRunControllerProvider);
      if (state.phase == CuratorRunPhase.philosophizing) {
        _openBriefingModalSafely();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 狀態機事件監聽：行前準備與體力透支自動彈窗
    ref.listen(curatorRunControllerProvider, (previous, next) {
      if (next.phase == CuratorRunPhase.philosophizing &&
          previous?.phase != CuratorRunPhase.philosophizing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openBriefingModalSafely();
        });
      } else if (next.isExhausted && (previous == null || !previous.isExhausted)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCuratorStudioSafely();
        });
      }
    });

    return Scaffold(
      body: GameWidget<UniversalOverworldGame>.controlled(
        gameFactory: () => _game,
        overlayBuilderMap: {
          'CuratorHUD': (context, game) => const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: CuratorFieldHud(),
            ),
          ),
          'RetroHUD': (context, game) =>
              _RetroHudOverlay(focusedDistrict: _focusedDistrict),
          'DistrictDiscovery': (context, game) =>
              _DistrictDiscoveryBanner(focusedDistrict: _focusedDistrict),
          'AttractionDetail': (context, game) => AttractionDetailCard(
            selectedAttraction: _selectedAttraction,
            onFocusCamera: () {
              final attraction = _selectedAttraction.value;
              if (attraction != null) {
                game.cameraFollow.onPan(
                  (game.cameraComponent.viewfinder.position -
                          attraction.pixel) *
                      -1,
                );
              }
            },
            onGathered: (material, hpSpent) {
              _gatheringFeedbackController.showGatherFeedback(
                material: material,
                hpSpent: hpSpent,
              );
            },
          ),
          'FloatingFeedback': (context, game) =>
              GatheringFloatingFeedbackOverlay(
                controller: _gatheringFeedbackController,
              ),
          'DPad': (context, game) => _DPadOverlay(game: game),
          'ModeToggle': (context, game) => _ModeToggle(
            game: game,
            onOpenStudio: _openCuratorStudioSafely,
            onOpenGearShop: _openGearShopSafely,
          ),
        },
        initialActiveOverlays: const [
          'CuratorHUD',
          'RetroHUD',
          'DistrictDiscovery',
          'AttractionDetail',
          'FloatingFeedback',
          'DPad',
          'ModeToggle',
        ],
      ),
    );
  }
}

class _RetroHudOverlay extends ConsumerWidget {
  const _RetroHudOverlay({this.focusedDistrict});
  final ValueNotifier<(AdministrativeDistrict?, int)>? focusedDistrict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationControllerProvider);
    final priority = hudPriorityOf(s.status);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 46, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RetroPanel(
              color: const Color(0xFFC0834B),
              children: [
                const Text(
                  'TAIWAN: OVERWORLD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
                if (focusedDistrict != null)
                  ValueListenableBuilder<(AdministrativeDistrict?, int)>(
                    valueListenable: focusedDistrict!,
                    builder: (context, data, _) {
                      final (district, count) = data;
                      if (district == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 1, bottom: 1),
                        child: Text(
                          'DISTRICT: ${district.name} ($count)',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 2),
                Text(
                  'MODE: ${s.status.mode.name.toUpperCase()}',
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
                Text(
                  'STATUS: ${priority.name}',
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
                Text(
                  'MOTION: ${s.status.motion.name}',
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
                // 診斷（REQ-C-14 規則 5）。多條驗收條件依賴這些計數才能斷言，
                // 而「為什麼沒動」是它們最直接的用途。
                Text(
                  'FIX ok:${s.diagnostics.acceptedFixCount} '
                  'rej:${s.diagnostics.rejectedFixCount}',
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
                Text(
                  'ACC: ${s.diagnostics.currentAccuracyMeters.toStringAsFixed(0)} m',
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
                if (s.diagnostics.rejectionsByReason.isNotEmpty)
                  Text(
                    'REJ: ${s.diagnostics.rejectionsByReason.entries.map((e) => '${e.key.name}=${e.value}').join(' ')}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8B0000),
                    ),
                  ),
              ],
            ),
            _RetroPanel(
              color: Colors.white,
              children: [
                Text(
                  'REAL: ${s.realDistanceMeters.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'VIRT: ${s.virtualDistanceMeters.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFF39C12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RetroPanel extends StatelessWidget {
  const _RetroPanel({required this.color, required this.children});
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Colors.black, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}

/// 方向鍵。正式玩法的一部分，不是除錯工具。
class _DPadOverlay extends ConsumerWidget {
  const _DPadOverlay({required this.game});
  final UniversalOverworldGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(locationControllerProvider.notifier);
    final canExplore = ref.watch(canExploreProvider);

    Widget arrow(IconData icon, double dx, double dy) => Opacity(
      opacity: canExplore ? 1.0 : 0.4,
      child: Listener(
        onPointerDown: (_) {
          if (canExplore) {
            notifier.setDirection(dx, dy);
          }
        },
        onPointerUp: (_) => notifier.stopMoving(),
        onPointerCancel: (_) => notifier.stopMoving(),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFC0834B),
            border: Border.all(color: Colors.black, width: 3),
          ),
          child: Icon(icon, size: 22, color: Colors.black),
        ),
      ),
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrow(Icons.keyboard_arrow_up, 0, -1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arrow(Icons.keyboard_arrow_left, -1, 0),
                  GestureDetector(
                    onTap: game.recenterOnPlayer,
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  arrow(Icons.keyboard_arrow_right, 1, 0),
                ],
              ),
              arrow(Icons.keyboard_arrow_down, 0, 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// 模式切換。權限對話框在玩家按下 GPS 時才出現——開場就跳，玩家還不知道
/// 這是什麼遊戲就被要求定位。
class _ModeToggle extends ConsumerWidget {
  const _ModeToggle({
    required this.game,
    required this.onOpenStudio,
    this.onOpenGearShop,
  });
  final UniversalOverworldGame game;
  final VoidCallback onOpenStudio;
  final VoidCallback? onOpenGearShop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(locationControllerProvider).status.mode;
    final permission = ref.watch(locationControllerProvider).status.permission;
    final notifier = ref.read(locationControllerProvider.notifier);
    final isGps = mode == SourceMode.gps;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 黑市裝備入口按鈕
              if (onOpenGearShop != null)
                GestureDetector(
                  key: const Key('gear_shop_launcher_button'),
                  onTap: onOpenGearShop,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      border: Border.all(color: Colors.amber, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          '🛒 黑市裝備',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // 策展工作台入口按鈕 (開啟時掛起 Flame 引擎以防穿透與降溫省電)
              GestureDetector(
                key: const Key('curator_studio_launcher_button'),
                onTap: onOpenStudio,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment, size: 16, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        '📑 策展工作台',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isGps && permission != PermissionState.ready)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: Colors.black87,
                  child: Text(
                    _hintFor(permission),
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              GestureDetector(
                onTap: () => isGps
                    ? notifier.switchToVirtual()
                    : notifier.requestGpsMode(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isGps ? const Color(0xFF48BB78) : Colors.white,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Text(
                    isGps ? 'GPS ON' : 'USE GPS',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintFor(PermissionState p) => switch (p) {
    PermissionState.serviceDisabled => '系統定位已關閉',
    PermissionState.denied => '定位權限被拒',
    PermissionState.deniedForever => '請至系統設定開啟定位',
    PermissionState.approximate => '請開啟「精確位置」',
    PermissionState.unavailable => '此裝置無定位功能',
    PermissionState.ready => '',
  };
}

/// 雙手放大時，頂部跳出的行政區熱門景點發現提示條
class _DistrictDiscoveryBanner extends StatelessWidget {
  const _DistrictDiscoveryBanner({required this.focusedDistrict});
  final ValueNotifier<(AdministrativeDistrict?, int)> focusedDistrict;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(AdministrativeDistrict?, int)>(
      valueListenable: focusedDistrict,
      builder: (context, data, _) {
        final (district, count) = data;
        if (district == null || count == 0) return const SizedBox.shrink();

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 175),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: Colors.amber, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, offset: Offset(2, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${district.name} · 已解鎖 $count 處熱門景點（Google Maps 4.5★+）',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
