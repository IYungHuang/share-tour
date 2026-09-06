import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/location/camera/camera_follow.dart';
import 'domain/location/models/geo_fix.dart';
import 'domain/location/models/location_status.dart';
import 'game/map_module/manifests/taiwan_map_manifest.dart';
import 'game/universal_overworld_game.dart';
import 'state/location/location_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // 圖資在此注入。通用引擎與畫面都不知道自己跑的是哪座城市。
      overrides: [mapManifestProvider.overrideWithValue(TaiwanMapManifest())],
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

  /// 前後景事件只有 widget 樹拿得到，所以由這裡轉發給定位層。
  /// 取消訂閱與否的判斷不在這裡——那是 LocationSubscriptionManager 的職責，
  /// 每個接線點各自計時的話，寬限期會有好幾份實作。
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<UniversalOverworldGame>.controlled(
        gameFactory: () => _game,
        overlayBuilderMap: {
          'RetroHUD': (context, game) => const _RetroHudOverlay(),
          'DPad': (context, game) => _DPadOverlay(game: game),
          'ModeToggle': (context, game) => const _ModeToggle(),
        },
        initialActiveOverlays: const ['RetroHUD', 'DPad', 'ModeToggle'],
      ),
    );
  }
}

class _RetroHudOverlay extends ConsumerWidget {
  const _RetroHudOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationControllerProvider);
    final priority = hudPriorityOf(s.status);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RetroPanel(
              color: const Color(0xFFC0834B),
              children: [
                const Text('TAIWAN: OVERWORLD',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.black)),
                const SizedBox(height: 2),
                Text('MODE: ${s.status.mode.name.toUpperCase()}',
                    style: const TextStyle(fontSize: 10, color: Colors.black)),
                Text('STATUS: ${priority.name}',
                    style: const TextStyle(fontSize: 10, color: Colors.black)),
                Text('MOTION: ${s.status.motion.name}',
                    style: const TextStyle(fontSize: 10, color: Colors.black)),
                // 診斷（REQ-C-14 規則 5）。多條驗收條件依賴這些計數才能斷言，
                // 而「為什麼沒動」是它們最直接的用途。
                Text('FIX ok:${s.diagnostics.acceptedFixCount} '
                    'rej:${s.diagnostics.rejectedFixCount}',
                    style: const TextStyle(fontSize: 10, color: Colors.black)),
                Text('ACC: ${s.diagnostics.currentAccuracyMeters.toStringAsFixed(0)} m',
                    style: const TextStyle(fontSize: 10, color: Colors.black)),
                if (s.diagnostics.rejectionsByReason.isNotEmpty)
                  Text(
                      'REJ: ${s.diagnostics.rejectionsByReason.entries.map((e) => '${e.key.name}=${e.value}').join(' ')}',
                      style:
                          const TextStyle(fontSize: 9, color: Color(0xFF8B0000))),
              ],
            ),
            _RetroPanel(
              color: Colors.white,
              children: [
                Text('REAL: ${s.realDistanceMeters.toStringAsFixed(0)} m',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.black)),
                Text('VIRT: ${s.virtualDistanceMeters.toStringAsFixed(0)} m',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFF39C12))),
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
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3))
          ],
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

    Widget arrow(IconData icon, double dx, double dy) => Listener(
          onPointerDown: (_) => notifier.setDirection(dx, dy),
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
              Row(mainAxisSize: MainAxisSize.min, children: [
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
                    child: const Icon(Icons.my_location,
                        size: 20, color: Colors.black),
                  ),
                ),
                arrow(Icons.keyboard_arrow_right, 1, 0),
              ]),
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
  const _ModeToggle();

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
              if (!isGps && permission != PermissionState.ready)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black87,
                  child: Text(
                    _hintFor(permission),
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              GestureDetector(
                onTap: () =>
                    isGps ? notifier.switchToVirtual() : notifier.requestGpsMode(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isGps ? const Color(0xFF48BB78) : Colors.white,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3))
                    ],
                  ),
                  child: Text(
                    isGps ? 'GPS ON' : 'USE GPS',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.black),
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
