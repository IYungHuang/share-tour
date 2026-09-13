import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/engine_pause_coordinator.dart';
import 'data/core_loop/kyoto_night_catalog.dart';
import 'data/core_loop/kyoto_poi_material_resolver.dart';
import 'data/core_loop/local_persistence_repository.dart';
import 'domain/core_loop/models/curator_save_data.dart';
import 'domain/core_loop/models/persistence_repository.dart';
import 'domain/core_loop/models/tour_time_of_day.dart';
import 'domain/core_loop/run/curator_run_phase.dart';
import 'domain/location/camera/camera_follow.dart';
import 'domain/location/models/district_attraction.dart';
import 'domain/location/models/geo_fix.dart';
import 'domain/location/models/location_status.dart';
import 'domain/location/projection/map_manifest.dart';
import 'game/map_module/manifests/kyoto_district_street_manifest.dart';
import 'game/map_module/manifests/kyoto_night_map_manifest.dart';
import 'game/map_module/manifests/kyoto_street_block_manifest.dart';
import 'game/universal_overworld_game.dart';
import 'state/core_loop/curator_run_providers.dart';
import 'state/core_loop/game_time_controller.dart';
import 'state/core_loop/persistence_providers.dart';
import 'state/location/location_providers.dart';
import 'ui/core_loop/briefing/curator_briefing_modal.dart';
import 'ui/core_loop/curator_modal_route.dart';
import 'ui/core_loop/curator_studio_modal.dart';
import 'ui/core_loop/field/attraction_detail_card.dart';
import 'ui/core_loop/field/curator_field_hud.dart';
import 'ui/core_loop/field/gathering_floating_feedback_overlay.dart';
import 'ui/core_loop/field/kyoto_district_selector_modal.dart';
import 'ui/core_loop/field/mosaic_transition_overlay.dart';
import 'ui/core_loop/gear_shop/gear_shop_modal.dart';

/// 作用中的圖資模組狀態（支援宏觀盆地 ⇄ 中觀街區動態切換）
final activeMapManifestStateProvider = StateProvider<OverworldMapManifest>(
  (ref) => const KyotoNightMapManifest(),
);

/// 建立正式環境根 Widget，集中注入圖資、素材庫、解析器與儲存庫 (Commit 12, T10)
ProviderScope buildProductionApp({
  required PersistenceRepository repository,
  required CuratorSaveData initialSave,
  OverworldMapManifest? manifest,
}) {
  final activeManifest = manifest ?? const KyotoNightMapManifest();
  return ProviderScope(
    // 圖資與城市 DLC 在此注入。通用引擎與狀態層都不知道自己跑的是哪座城市。
    overrides: [
      activeMapManifestStateProvider.overrideWith((ref) => activeManifest),
      mapManifestProvider
          .overrideWith((ref) => ref.watch(activeMapManifestStateProvider)),
      curatorMaterialPoolProvider.overrideWithValue(kyotoNightMaterials),
      poiMaterialResolverProvider.overrideWithValue(
        const KyotoPoiMaterialResolver(),
      ),
      persistenceRepositoryProvider.overrideWithValue(repository),
      initialSaveDataProvider.overrideWithValue(initialSave),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverworldScaffold(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = LocalPersistenceRepository();

  // 圖資與本機存檔非同步並行預載水合 (Task M7, 零 FOUC)
  final (manifest, initialSave) = await (
    KyotoNightMapManifest.load(),
    repo.loadSave(),
  ).wait;

  runApp(
    buildProductionApp(
      repository: repo,
      initialSave: initialSave,
      manifest: manifest,
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
  final MosaicTransitionController _mosaicController =
      MosaicTransitionController();

  void _switchMapHierarchy({
    required OverworldMapManifest targetManifest,
    required String targetTitle,
    Vector2? spawnPixel,
  }) {
    _mosaicController.triggerTransition(
      targetTitle: targetTitle,
      onMidpoint: () async {
        ref.read(activeMapManifestStateProvider.notifier).state =
            targetManifest;
        ref.read(locationControllerProvider.notifier).switchManifest(
              targetManifest,
              newSpawnPixel: spawnPixel,
            );
        await _game.switchMap(targetManifest, newSpawnPixel: spawnPixel);
        _selectedAttraction.value = null;
      },
    );
  }

  // 引用計數暫停協調器 (防範多層彈窗競爭與洩漏, AC-M4-4.4)。
  // 計數邏輯本身住在 core/，有獨立測試；此處只負責附著與載入的檢查。
  late final EnginePauseCoordinator _enginePause = EnginePauseCoordinator(
    onPause: () {
      if (_game.isAttached && _game.isLoaded) {
        _game.pauseEngine();
      }
    },
    onResume: () {
      if (mounted && _game.isAttached && _game.isLoaded) {
        _game.resumeEngine();
      }
    },
  );
  bool _isStudioModalOpen = false;
  bool _isBriefingModalOpen = false;
  bool _isGearShopModalOpen = false;

  void _pauseEngine() => _enginePause.acquire();

  void _resumeEngine() => _enginePause.release();

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

  Vector2 _getSpawnPixelForBasinReturn(OverworldMapManifest currentManifest) {
    if (currentManifest is KyotoDistrictStreetManifest) {
      return switch (currentManifest.districtType) {
        KyotoDistrictType.nakagyo => Vector2(665.0, 395.0),
        KyotoDistrictType.higashiyama => Vector2(725.0, 415.0),
        KyotoDistrictType.sakyo => Vector2(780.0, 275.0),
        KyotoDistrictType.arashiyama => Vector2(145.0, 340.0),
        KyotoDistrictType.fushimiUji => Vector2(700.0, 680.0),
      };
    }
    return Vector2(665.0, 395.0);
  }

  Future<void> _openDistrictSelectorSafely() async {
    if (!mounted) return;
    final currentManifest = ref.read(activeMapManifestStateProvider);
    String? currentCode;
    if (currentManifest is KyotoDistrictStreetManifest) {
      currentCode = currentManifest.districtType.code;
    }
    await _showModalSafely<void>(
      (ctx) => KyotoDistrictSelectorModal(
        activeDistrictCode: currentCode,
        onSelectDistrict: (district) {
          _switchMapHierarchy(
            targetManifest: KyotoDistrictStreetManifest(district),
            targetTitle: '${district.name}散步道',
            spawnPixel: district.defaultSpawnPixel,
          );
        },
      ),
    );
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
        returnDelay: null, // 自由漫遊探索模式：取消 3 秒強制回彈，由方向鍵中央 🎯 按鈕手動歸位
      ),
      onAttractionSelected: (a) => _selectedAttraction.value = a,
      onDistrictRevealed: (d, count) => _focusedDistrict.value = (d, count),
      timeSnapshotGetter: () => ref.read(gameTimeProvider),
      timeOfDayGetter: () {
        final runState = ref.read(curatorRunControllerProvider);
        return TourTimeOfDay.fromHpAndPhase(
          currentHp: runState.resources.hp,
          maxHp: runState.resources.maxHp,
          isNightEditing: runState.phase == CuratorRunPhase.nightEditing ||
              runState.phase == CuratorRunPhase.clientReview ||
              runState.phase == CuratorRunPhase.settled,
        );
      },
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
      final route = resolveCuratorModalRoute(previous, next);
      if (route == CuratorModalRoute.none) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (route) {
          case CuratorModalRoute.briefing:
            _openBriefingModalSafely();
          case CuratorModalRoute.studio:
            _openCuratorStudioSafely();
          case CuratorModalRoute.none:
            break;
        }
      });
    });

    final currentManifest = ref.watch(mapManifestProvider);
    final isStreetBlock = currentManifest is KyotoDistrictStreetManifest ||
        currentManifest.mapId == 'kyoto_street_block' ||
        currentManifest.mapId.startsWith('kyoto_street_');

    return Scaffold(
      body: GameWidget<UniversalOverworldGame>.controlled(
        gameFactory: () => _game,
        overlayBuilderMap: {
          'MosaicTransition': (context, game) =>
              MosaicTransitionOverlay(controller: _mosaicController),
          'CuratorHUD': (context, game) => const SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: CuratorFieldHud(),
            ),
          ),
          'RetroHUD': (context, game) =>
              _RetroHudOverlay(focusedDistrict: _focusedDistrict),
          'DistrictDiscovery': (context, game) =>
              DistrictDiscoveryBanner(
                focusedDistrict: _focusedDistrict,
                isStreetBlock: isStreetBlock,
                onEnterDistrict: (districtType) => _switchMapHierarchy(
                  targetManifest: KyotoDistrictStreetManifest(districtType),
                  targetTitle: '${districtType.name}散步道',
                  spawnPixel: districtType.defaultSpawnPixel,
                ),
                onEnterStreet: () => _switchMapHierarchy(
                  targetManifest: const KyotoStreetBlockManifest(),
                  targetTitle: '洛中・河原町街區散步道（町家街區）',
                  spawnPixel: Vector2(512.0, 512.0),
                ),
              ),
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
          'DPad': (context, game) => DPadOverlay(game: game),
          'ModeToggle': (context, game) => ModeToggle(
            game: game,
            onOpenStudio: _openCuratorStudioSafely,
            onOpenGearShop: _openGearShopSafely,
            onOpenDistrictSelector: _openDistrictSelectorSafely,
            onReturnToBasin: () => _switchMapHierarchy(
              targetManifest: const KyotoNightMapManifest(),
              targetTitle: '京都盆地全覽（宏觀大地圖）',
              spawnPixel: _getSpawnPixelForBasinReturn(currentManifest),
            ),
            onSwitchHierarchy: ({
              required OverworldMapManifest targetManifest,
              required String targetTitle,
              Vector2? spawnPixel,
            }) => _switchMapHierarchy(
              targetManifest: targetManifest,
              targetTitle: targetTitle,
              spawnPixel: spawnPixel,
            ),
          ),
        },
        initialActiveOverlays: const [
          'MosaicTransition',
          'CuratorHUD',
          'DistrictDiscovery',
          'DPad',
          'ModeToggle',
          'AttractionDetail',
          'FloatingFeedback',
        ],
      ),
    );
  }
}

class _RetroHudOverlay extends ConsumerWidget {
  const _RetroHudOverlay({this.focusedDistrict});
  final ValueNotifier<(AdministrativeDistrict?, int)>? focusedDistrict;

  String _hudTitle(OverworldMapManifest manifest) {
    if (manifest is KyotoDistrictStreetManifest) {
      return manifest.districtType.hudLabel;
    }
    if (manifest.mapId == 'kyoto_street_block') {
      return 'KYOTO: NAKAGYO MACHIYA';
    }
    if (manifest.mapId.startsWith('kyoto_street_')) {
      final code = manifest.mapId.replaceFirst('kyoto_street_', '');
      final type = KyotoDistrictType.fromCode(code);
      if (type != null) return type.hudLabel;
    }
    if (manifest.mapId == 'kyoto_night_block') {
      return 'KYOTO: BASIN OVERWORLD';
    }
    return 'TAIWAN: OVERWORLD';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationControllerProvider);
    final manifest = ref.watch(mapManifestProvider);
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
                Text(
                  _hudTitle(manifest),
                  style: const TextStyle(
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

/// 手機版模擬搖桿 (Virtual Analog Joystick) 與定位鍵。
///
/// 支援 360° 連續滑動方向控制、彈簧回彈、死區防誤觸，
/// 並在右上肩部整合一鍵回到主角的定位鍵 (Recenter Button)。
class DPadOverlay extends ConsumerStatefulWidget {
  const DPadOverlay({super.key, required this.game});
  final UniversalOverworldGame game;

  @override
  ConsumerState<DPadOverlay> createState() => _DPadOverlayState();
}

class _DPadOverlayState extends ConsumerState<DPadOverlay>
    with SingleTickerProviderStateMixin {
  Offset _knobOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  static const double _baseRadius = 58.0;
  static const double _knobRadius = 24.0;
  static const double _maxDistance = 35.0;
  static const double _deadZone = 4.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(() {
        setState(() {
          _knobOffset = _springAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details, bool canExplore) {
    if (!canExplore) return;
    _springController.stop();
    _updateOffset(details.localPosition, canExplore);
  }

  void _handlePanUpdate(DragUpdateDetails details, bool canExplore) {
    if (!canExplore) return;
    _updateOffset(details.localPosition, canExplore);
  }

  void _updateOffset(Offset localPos, bool canExplore) {
    if (!canExplore) return;
    final delta = localPos - const Offset(_baseRadius, _baseRadius);
    final distance = delta.distance;

    final notifier = ref.read(locationControllerProvider.notifier);

    if (distance < _deadZone) {
      notifier.stopMoving();
      setState(() {
        _isDragging = true;
        _knobOffset = delta;
      });
      return;
    }

    final clampedDistance = math.min(distance, _maxDistance);
    final unitVector = delta / distance;
    final clampedOffset = unitVector * clampedDistance;

    setState(() {
      _isDragging = true;
      _knobOffset = clampedOffset;
    });

    notifier.setDirection(unitVector.dx, unitVector.dy);
  }

  void _handlePanEnd(bool canExplore) {
    if (!canExplore) return;
    final notifier = ref.read(locationControllerProvider.notifier);
    notifier.stopMoving();

    _springAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutQuad,
    ));
    _springController.forward(from: 0);

    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canExplore = ref.watch(canExploreProvider);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 14),
          child: Opacity(
            opacity: canExplore ? 1.0 : 0.4,
            child: SizedBox(
              width: _baseRadius * 2 + 16,
              height: _baseRadius * 2 + 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. 模擬搖桿底座與觸控感應區
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: _baseRadius * 2,
                    height: _baseRadius * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _handlePanStart(d, canExplore),
                      onPanUpdate: (d) => _handlePanUpdate(d, canExplore),
                      onPanEnd: (_) => _handlePanEnd(canExplore),
                      onPanCancel: () => _handlePanEnd(canExplore),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xD91E2430),
                          border: Border.all(
                            color: const Color(0xFFC0834B),
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(2, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 刻度箭頭標記
                            Positioned(
                              top: 5,
                              child: Text(
                                '▲',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              child: Text(
                                '▼',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 5,
                              child: Text(
                                '◀',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 5,
                              child: Text(
                                '▶',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            // 搖桿頭 (Knob)
                            Transform.translate(
                              offset: _knobOffset,
                              child: Container(
                                width: _knobRadius * 2,
                                height: _knobRadius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: _isDragging
                                        ? [
                                            const Color(0xFFF59E0B),
                                            const Color(0xFFB45309),
                                          ]
                                        : [
                                            const Color(0xFFD97706),
                                            const Color(0xFF78350F),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isDragging
                                          ? const Color(0x99F59E0B)
                                          : Colors.black54,
                                      blurRadius: _isDragging ? 8 : 4,
                                      offset: const Offset(1, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.amberAccent
                                            .withValues(alpha: 0.8),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. 獨立懸浮定位鍵 (Recenter Button 🎯 / my_location)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      key: const Key('recenter_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.game.recenterOnPlayer,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 模式切換與右下角操作選單。
///
/// 採用極簡空間的「堆疊滾輪式選單 (Stacked Wheel Menu)」呈現：
/// 平時僅佔用底部極小角落空間，點擊展開後以立體堆疊輪盤方式呈現
/// 街區漫步、黑市裝備、策展工作台三大核心行動，兼顧指尖順暢度與畫面開闊度。
class ModeToggle extends ConsumerStatefulWidget {
  const ModeToggle({
    super.key,
    required this.game,
    required this.onOpenStudio,
    this.onOpenGearShop,
    this.onSwitchHierarchy,
    this.onOpenDistrictSelector,
    this.onReturnToBasin,
  });

  final UniversalOverworldGame game;
  final VoidCallback onOpenStudio;
  final VoidCallback? onOpenGearShop;
  final void Function({
    required OverworldMapManifest targetManifest,
    required String targetTitle,
    Vector2? spawnPixel,
  })? onSwitchHierarchy;
  final VoidCallback? onOpenDistrictSelector;
  final VoidCallback? onReturnToBasin;

  @override
  ConsumerState<ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends ConsumerState<ModeToggle>
    with SingleTickerProviderStateMixin {
  bool _isWheelExpanded = false;
  late AnimationController _wheelAnimController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _wheelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _wheelAnimController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void dispose() {
    _wheelAnimController.dispose();
    super.dispose();
  }

  void _toggleWheel() {
    setState(() {
      _isWheelExpanded = !_isWheelExpanded;
      if (_isWheelExpanded) {
        _wheelAnimController.forward();
      } else {
        _wheelAnimController.reverse();
      }
    });
  }

  void _closeWheel() {
    if (!_isWheelExpanded) return;
    setState(() {
      _isWheelExpanded = false;
      _wheelAnimController.reverse();
    });
  }

  Widget _buildWheelItem({
    required Key key,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color borderColor,
    required Widget icon,
    required String label,
    required Color textColor,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _closeWheel();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 4,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(locationControllerProvider).status.mode;
    final permission = ref.watch(locationControllerProvider).status.permission;
    final manifest = ref.watch(mapManifestProvider);
    final isStreet = manifest is KyotoDistrictStreetManifest ||
        manifest.mapId == 'kyoto_street_block' ||
        manifest.mapId.startsWith('kyoto_street_');
    final notifier = ref.read(locationControllerProvider.notifier);
    final isGps = mode == SourceMode.gps;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. 左側：GPS 定位模式切換與權限提示
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isGps && permission != PermissionState.ready)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      color: Colors.black87,
                      child: Text(
                        _hintFor(permission),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => isGps
                        ? notifier.switchToVirtual()
                        : notifier.requestGpsMode(),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isGps
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1E2430),
                        border: Border.all(
                          color: isGps ? Colors.white : Colors.black,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                            size: 14,
                            color: isGps
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGps ? 'GPS ON' : 'USE GPS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isGps
                                  ? Colors.white
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // 2. 右側：行動選單專屬垂直欄（完全靠右，展開時在觸發鈕正上方展開）
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 展開的堆疊選單項目
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: 1.0,
                    child: FadeTransition(
                      opacity: _expandAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 頂層：街區漫步 / 返回盆地
                            if (widget.onSwitchHierarchy != null ||
                                widget.onOpenDistrictSelector != null ||
                                widget.onReturnToBasin != null)
                              _buildWheelItem(
                                key: const Key('map_hierarchy_toggle_button'),
                                backgroundColor: isStreet
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF831843),
                                borderColor: Colors.amber,
                                icon: Icon(
                                  isStreet
                                      ? Icons.public
                                      : Icons.holiday_village,
                                  size: 15,
                                  color: Colors.amber,
                                ),
                                label: isStreet ? '🗺️ 返回盆地全覽' : '🏮 街區漫步',
                                textColor: Colors.white,
                                onTap: () {
                                  if (isStreet) {
                                    if (widget.onReturnToBasin != null) {
                                      widget.onReturnToBasin!();
                                    } else {
                                      widget.onSwitchHierarchy?.call(
                                        targetManifest:
                                            const KyotoNightMapManifest(),
                                        targetTitle: '京都盆地全覽（宏觀大地圖）',
                                        spawnPixel: Vector2(665.0, 395.0),
                                      );
                                    }
                                  } else {
                                    if (widget.onOpenDistrictSelector != null) {
                                      widget.onOpenDistrictSelector!();
                                    } else {
                                      widget.onSwitchHierarchy?.call(
                                        targetManifest:
                                            const KyotoStreetBlockManifest(),
                                        targetTitle:
                                            '洛中・河原町街區散步道（中觀町家）',
                                        spawnPixel: Vector2(512.0, 512.0),
                                      );
                                    }
                                  }
                                },
                              ),

                            // 中層：黑市裝備
                            if (widget.onOpenGearShop != null)
                              _buildWheelItem(
                                key: const Key('gear_shop_launcher_button'),
                                backgroundColor: const Color(0xFF1E293B),
                                borderColor: Colors.amber,
                                icon: const Icon(Icons.storefront,
                                    size: 15, color: Colors.amber),
                                label: '🛒 黑市裝備',
                                textColor: Colors.amber,
                                onTap: widget.onOpenGearShop!,
                              ),

                            // 底層：策展工作台
                            _buildWheelItem(
                              key: const Key('curator_studio_launcher_button'),
                              backgroundColor: const Color(0xFFF59E0B),
                              borderColor: Colors.black,
                              icon: const Icon(Icons.assignment,
                                  size: 15, color: Colors.black),
                              label: '📑 策展工作台',
                              textColor: Colors.black,
                              onTap: widget.onOpenStudio,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 底部觸發按鈕 (靠右貼齊)
                  GestureDetector(
                    key: const Key('stacked_wheel_trigger'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleWheel,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isWheelExpanded
                            ? const Color(0xFFD97706)
                            : const Color(0xFF1E2430),
                        border: Border.all(
                          color: _isWheelExpanded ? Colors.white : Colors.amber,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isWheelExpanded ? Icons.close : Icons.tune,
                            size: 15,
                            color: _isWheelExpanded
                                ? Colors.white
                                : Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isWheelExpanded ? '收合' : '🎡 行動選單 ▾',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: _isWheelExpanded
                                  ? Colors.white
                                  : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

/// 雙手放大或角色走入行政區時，頂部跳出的行政區到達與漫步提示條
class DistrictDiscoveryBanner extends ConsumerWidget {
  const DistrictDiscoveryBanner({
    super.key,
    required this.focusedDistrict,
    this.onEnterStreet,
    this.onEnterDistrict,
    this.isStreetBlock = false,
  });

  final ValueNotifier<(AdministrativeDistrict?, int)> focusedDistrict;
  final VoidCallback? onEnterStreet;
  final void Function(KyotoDistrictType district)? onEnterDistrict;
  final bool isStreetBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(mapManifestProvider);
    final inStreet = isStreetBlock ||
        manifest is KyotoDistrictStreetManifest ||
        manifest.mapId == 'kyoto_street_block' ||
        manifest.mapId.startsWith('kyoto_street_');
    if (inStreet) return const SizedBox.shrink();

    return ValueListenableBuilder<(AdministrativeDistrict?, int)>(
      valueListenable: focusedDistrict,
      builder: (context, data, _) {
        final (district, count) = data;
        final districtType =
            district == null ? null : KyotoDistrictType.fromCode(district.code);
        final canEnter = district != null &&
            (districtType != null || district.code.contains('nakagyo'));

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -0.8),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: district == null
                  ? const SizedBox.shrink(key: ValueKey('empty_district'))
                  : Container(
                      key: ValueKey(district.code),
                      margin: const EdgeInsets.only(
                        top: 48,
                        left: 12,
                        right: 12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        border: Border.all(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            districtType?.badgeIcon ?? '📍',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              count > 0
                                  ? '已抵達 ${district.name} · 可探索 $count 處景點'
                                  : '已抵達 ${district.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (canEnter) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              key: const Key('enter_district_street_button'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (districtType != null &&
                                    onEnterDistrict != null) {
                                  onEnterDistrict!(districtType);
                                } else {
                                  onEnterStreet?.call();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${districtType?.badgeIcon ?? '🏮'} 進入街區',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
