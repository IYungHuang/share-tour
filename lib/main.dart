import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game/universal_overworld_game.dart';
import 'game/map_module/manifests/taiwan_map_manifest.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverworldScaffold(),
    ),
  ));
}

class OverworldScaffold extends StatefulWidget {
  const OverworldScaffold({super.key});

  @override
  State<OverworldScaffold> createState() => _OverworldScaffoldState();
}

class _OverworldScaffoldState extends State<OverworldScaffold> {
  late final UniversalOverworldGame _game;

  @override
  void initState() {
    super.initState();
    // 注入台灣圖資清單
    _game = UniversalOverworldGame(manifest: TaiwanMapManifest());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<UniversalOverworldGame>.controlled(
        gameFactory: () => _game,
        overlayBuilderMap: {
          'RetroHUD': (context, game) => const _RetroHudOverlay(),
        },
        initialActiveOverlays: const ['RetroHUD'],
      ),
    );
  }
}

class _RetroHudOverlay extends StatelessWidget {
  const _RetroHudOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左上方：木紋資訊看板
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFC0834B),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TAIWAN: OVERWORLD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                  SizedBox(height: 2),
                  Text('LOCATION: TAIPEI', style: TextStyle(fontSize: 10, color: Colors.black)),
                  Text('EXPLORER LV. 10', style: TextStyle(fontSize: 10, color: Colors.black)),
                ],
              ),
            ),
            // 右上方：金幣與道具槽
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('COINS: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                  Text('9999', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFF39C12))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
