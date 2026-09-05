import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _OverworldScaffoldState extends ConsumerState<OverworldScaffold> {
  late final UniversalOverworldGame _game;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(locationControllerProvider.notifier);
    _game = UniversalOverworldGame(
      manifest: ref.read(mapManifestProvider),
      onTick: notifier.controller.tick,
      renderedPixelOf: () => notifier.controller.state.renderedPixel,
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
        },
        initialActiveOverlays: const ['RetroHUD', 'DPad'],
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
