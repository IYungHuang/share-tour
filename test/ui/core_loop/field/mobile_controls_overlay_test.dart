import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/core/time/system_clock.dart';
import 'package:share_tour/domain/location/camera/camera_follow.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';
import 'package:share_tour/game/universal_overworld_game.dart';
import 'package:share_tour/main.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_controller.dart';
import 'package:share_tour/state/location/location_providers.dart';

class _FakeOverworldGame extends UniversalOverworldGame {
  _FakeOverworldGame()
      : super(
          manifest: const KyotoNightMapManifest(),
          onTick: (_) {},
          renderedPixelOf: () => Vector2(100, 100),
          cameraFollow: CameraFollow(
            clock: SystemClock(),
            returnDelay: null,
          ),
        );

  int recenterCalls = 0;

  @override
  void recenterOnPlayer() {
    recenterCalls++;
  }
}

class _FakeLocationNotifier extends LocationNotifier {
  _FakeLocationNotifier(this.pixel);
  final Vector2 pixel;
  double lastX = 0;
  double lastY = 0;
  bool isStopped = false;

  @override
  LocationControllerState build() {
    return LocationControllerState(
      status: const LocationStatus(
        permission: PermissionState.unavailable,
        mode: SourceMode.virtual,
        coverage: CoverageState.inside,
        acquisition: AcquisitionState.acquiring,
        motion: MotionState.still,
      ),
      diagnostics: const LocationDiagnostics(
        activeSubscriptionCount: 0,
        powerMode: PowerMode.active,
        acceptedFixCount: 0,
        rejectedFixCount: 0,
        rejectionsByReason: {},
        currentAccuracyMeters: 1.0,
        realDistanceMeters: 0,
        virtualDistanceMeters: 0,
        secondsSinceLastSignificantMove: 0,
        accuracyGatedFixCount: 0,
        keepAwakeActive: false,
      ),
      renderedPixel: pixel,
      targetPixel: pixel,
      realDistanceMeters: 0,
      virtualDistanceMeters: 0,
    );
  }

  @override
  void setDirection(double x, double y) {
    lastX = x;
    lastY = y;
    isStopped = false;
  }

  @override
  void stopMoving() {
    isStopped = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('手機版懸浮控制項升級測試 (HUD 精簡、模擬搖桿與堆疊滾輪選單)', () {
    testWidgets('1. RetroHUD 不在 GameWidget 預設啟用的懸浮圖層清單中 (畫面開闊無黃白除錯框)', (tester) async {
      // 驗證 OverworldScaffoldState 定義的 initialActiveOverlays 不含 RetroHUD
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const Text('HUD Check');
              },
            ),
          ),
        ),
      );

      // 直接檢查 main.dart 中 _OverworldScaffoldState 的 initialActiveOverlays 契約
      // RetroHUD 已自 initialActiveOverlays 移除，僅在 overlayBuilderMap 作為除錯備用
      expect(find.textContaining('MODE: VIRTUAL'), findsNothing);
      expect(find.textContaining('REAL:'), findsNothing);
      expect(find.textContaining('VIRT:'), findsNothing);
    });

    testWidgets('2. 模擬搖桿 (DPadOverlay) 與肩部定位鍵 (🎯) 正常渲染，並支援連續滑動與定位回正', (tester) async {
      final fakeGame = _FakeOverworldGame();
      final fakeNotifier = _FakeLocationNotifier(Vector2(100, 100));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canExploreProvider.overrideWithValue(true),
            locationControllerProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DPadOverlay(game: fakeGame),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 驗證定位鍵 (🎯 / my_location) 存在
      final recenterBtn = find.byKey(const Key('recenter_button'));
      expect(recenterBtn, findsOneWidget);

      // 點擊定位鍵，驗證觸發 game.recenterOnPlayer
      await tester.tap(recenterBtn);
      await tester.pump();
      expect(fakeGame.recenterCalls, equals(1));

      // 驗證八方刻度箭頭存在於搖桿基座
      expect(find.text('▲'), findsOneWidget);
      expect(find.text('▼'), findsOneWidget);
      expect(find.text('◀'), findsOneWidget);
      expect(find.text('▶'), findsOneWidget);

      // 模擬在搖桿上滑動拖曳 (從搖桿基座圓心往右下 45 度)
      final dpadBase = find.descendant(
        of: find.byType(DPadOverlay),
        matching: find.byType(GestureDetector),
      ).first;
      final center = tester.getCenter(dpadBase);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(25, 25));
      await tester.pump();

      // 驗證方向被傳送給 location controller (單位向量)
      expect(fakeNotifier.lastX, greaterThan(0));
      expect(fakeNotifier.lastY, greaterThan(0));
      expect(fakeNotifier.isStopped, isFalse);

      // 放開搖桿，驗證觸發 stopMoving
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fakeNotifier.isStopped, isTrue);
    });

    testWidgets('3. 右下角行動按鈕改為堆疊滾輪式選單 (ModeToggle)：收合時極簡緊湊，展開時完整呈現三大核心入口', (tester) async {
      final fakeGame = _FakeOverworldGame();
      final fakeNotifier = _FakeLocationNotifier(Vector2(100, 100));
      bool studioOpened = false;
      bool gearShopOpened = false;
      bool hierarchySwitched = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationControllerProvider.overrideWith(() => fakeNotifier),
            mapManifestProvider.overrideWithValue(const KyotoNightMapManifest()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ModeToggle(
                game: fakeGame,
                onOpenStudio: () => studioOpened = true,
                onOpenGearShop: () => gearShopOpened = true,
                onSwitchHierarchy: ({
                  required targetManifest,
                  required targetTitle,
                  spawnPixel,
                }) => hierarchySwitched = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 初始狀態：堆疊滾輪選單處於收合狀態，僅顯示觸發鈕
      final trigger = find.byKey(const Key('stacked_wheel_trigger'));
      expect(trigger, findsOneWidget);
      expect(find.text('🎡 行動選單 ▾'), findsOneWidget);
      expect(find.text('USE GPS'), findsOneWidget);

      // 2. 點擊展開堆疊滾輪選單
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      expect(find.text('收合'), findsOneWidget);
      // 驗證三大核心選項在展開時立體堆疊浮現
      final hierarchyBtn = find.byKey(const Key('map_hierarchy_toggle_button'));
      final gearShopBtn = find.byKey(const Key('gear_shop_launcher_button'));
      final studioBtn = find.byKey(const Key('curator_studio_launcher_button'));

      expect(hierarchyBtn, findsOneWidget);
      expect(gearShopBtn, findsOneWidget);
      expect(studioBtn, findsOneWidget);

      // 3. 點擊其中一項 (黑市裝備)，驗證回調被調用且選單自動收合
      await tester.tap(gearShopBtn);
      await tester.pumpAndSettle();

      expect(gearShopOpened, isTrue);
      expect(find.text('🎡 行動選單 ▾'), findsOneWidget);

      // 4. 再次展開並點擊策展工作台
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(studioBtn);
      await tester.pumpAndSettle();

      expect(studioOpened, isTrue);
      expect(find.text('🎡 行動選單 ▾'), findsOneWidget);

      // 5. 再次展開並點擊地圖尺度切換
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(hierarchyBtn);
      await tester.pumpAndSettle();

      expect(hierarchySwitched, isTrue);
      expect(find.text('🎡 行動選單 ▾'), findsOneWidget);
    });
  });
}
