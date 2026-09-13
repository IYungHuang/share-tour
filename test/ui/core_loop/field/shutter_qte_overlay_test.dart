// 煙霧測試等級（`CLAUDE.md` §2：`ui/` 不追求覆蓋率）。
//
// 只驗證 G12 施工內容列出的三條 AC，外加一條 plan 遺漏但值得順手補上的
// AC-M5-4.6（不擴大任務範圍——同一份測試檔，多一個 group）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/ui/core_loop/field/shutter_qte_overlay.dart';

Widget _wrapWithBelowLayer(Widget overlay, {required VoidCallback onTapBelow}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('belowLayer'),
              onTap: onTapBelow,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned.fill(child: overlay),
        ],
      ),
    ),
  );
}

void main() {
  group('AC-M5-11.1: 三態各自觸發可區分的 Overlay 回饋，IgnorePointer 不阻塞點擊', () {
    // photographer: tMatch=1100, perfectWindow=160(半80), normalWindow=720(半360)。
    const cases = {
      ShotTier.perfect: 1100,
      ShotTier.normal: 1400,
      ShotTier.failed: 1550,
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key.name} 觸發可區分回饋且結算後不阻塞下層點擊', (tester) async {
        ShotTier? resolved;
        var tappedBelow = false;

        await tester.pumpWidget(
          _wrapWithBelowLayer(
            ShutterQteOverlay(
              difficulty: ShutterDifficulty.photographer,
              isSpotlight: false,
              onResolved: (r) => resolved = r,
              onInterrupted: () {},
            ),
            onTapBelow: () => tappedBelow = true,
          ),
        );

        final gesture = await tester.createGesture();
        await gesture.down(const Offset(150, 150), timeStamp: Duration.zero);
        await gesture.up(timeStamp: Duration(milliseconds: entry.value));
        await tester.pump();

        expect(resolved, entry.key, reason: '放開時戳應解析出 ${entry.key}');
        expect(
          find.byKey(Key('shutterResult.${entry.key.name}.early')).evaluate().isNotEmpty ||
              find.byKey(Key('shutterResult.${entry.key.name}.late')).evaluate().isNotEmpty,
          isTrue,
          reason: '${entry.key} 應有可區分的結果 Key',
        );

        await tester.tap(find.byKey(const Key('belowLayer')));
        await tester.pump();
        expect(tappedBelow, isTrue, reason: '結算後 IgnorePointer 須放行，點擊能穿透到下層');
      });
    }
  });

  group('AC-M5-11.6: 結果文字為態 × 方向的正交組合，逾時獨立且無方向', () {
    testWidgets('perfect・早（up 早於 tMatch）', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.up(timeStamp: const Duration(milliseconds: 1050)); // delta -50
      await tester.pump();
      expect(find.byKey(const Key('shutterResult.perfect.early')), findsOneWidget);
    });

    testWidgets('normal・晚（up 晚於 tMatch）', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.up(timeStamp: const Duration(milliseconds: 1400)); // delta +300
      await tester.pump();
      expect(find.byKey(const Key('shutterResult.normal.late')), findsOneWidget);
    });

    testWidgets('failed・晚，與逾時使用不同 Key（不併入「太晚」）', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.up(timeStamp: const Duration(milliseconds: 1550)); // delta +450
      await tester.pump();
      expect(find.byKey(const Key('shutterResult.failed.late')), findsOneWidget);
      expect(find.byKey(const Key('shutterResult.timedOut')), findsNothing);
    });

    testWidgets('逾時：獨立 Key，無方向維度', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (r) => resolved = r,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      // 全程不觸碰螢幕，讓動畫全長（1600ms）+ 100ms 送達餘裕跑完。多推進一點
      // 邊際（16ms）——`AnimationStatus.completed` 在 `value` 打到 1.0 的
      // 下一個影格才翻轉，剛好打滿總長的單次 pump 還停在 `forward`。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1716));
      expect(find.byKey(const Key('shutterResult.timedOut')), findsOneWidget);
      expect(resolved, ShotTier.failed, reason: '逾時的判定結果仍是 failed，只是文字獨立呈現');
    });
  });

  group('AC-M5-1.9: 判定依指標時戳而非幀時間', () {
    testWidgets('邊界內（delta 80ms）判 perfect', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (r) => resolved = r,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.up(timeStamp: const Duration(milliseconds: 1180)); // delta 80，邊界內
      await tester.pump();
      expect(resolved, ShotTier.perfect);
    });

    testWidgets('邊界外 1ms（delta 81ms）判 normal——證明結果隨指標時戳而非幀時間改變', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (r) => resolved = r,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.up(timeStamp: const Duration(milliseconds: 1181)); // delta 81，邊界外 1ms
      await tester.pump();
      expect(resolved, ShotTier.normal);
    });
  });

  group('AC-M5-4.6: 收縮指示的呈現依 isSpotlight 分派', () {
    testWidgets('非絕景為同心圓，絕景為取景框邊框', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.tourist,
            isSpotlight: false,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      expect(find.byKey(const Key('shutterIndicator.ring')), findsOneWidget);
      expect(find.byKey(const Key('shutterIndicator.frame')), findsNothing);

      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.tourist,
            isSpotlight: true,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      expect(find.byKey(const Key('shutterIndicator.frame')), findsOneWidget);
      expect(find.byKey(const Key('shutterIndicator.ring')), findsNothing);
    });
  });
}
