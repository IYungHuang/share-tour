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
          find
                  .byKey(Key('shutterResult.${entry.key.name}.early'))
                  .evaluate()
                  .isNotEmpty ||
              find
                  .byKey(Key('shutterResult.${entry.key.name}.late'))
                  .evaluate()
                  .isNotEmpty,
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
      await gesture.up(
        timeStamp: const Duration(milliseconds: 1050),
      ); // delta -50
      await tester.pump();
      expect(
        find.byKey(const Key('shutterResult.perfect.early')),
        findsOneWidget,
      );
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
      await gesture.up(
        timeStamp: const Duration(milliseconds: 1400),
      ); // delta +300
      await tester.pump();
      expect(
        find.byKey(const Key('shutterResult.normal.late')),
        findsOneWidget,
      );
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
      await gesture.up(
        timeStamp: const Duration(milliseconds: 1550),
      ); // delta +450
      await tester.pump();
      expect(
        find.byKey(const Key('shutterResult.failed.late')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shutterResult.timedOut')), findsNothing);
    });

    testWidgets('未按下前不啟動動畫或逾時計時', (tester) async {
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

      await tester.pump(const Duration(seconds: 3));

      expect(resolved, isNull);
      expect(find.byKey(const Key('shutterResult.timedOut')), findsNothing);
    });

    testWidgets('按下後逾時：獨立 Key，無方向維度', (tester) async {
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
      await gesture.down(const Offset(150, 150), timeStamp: Duration.zero);
      // 按下後讓動畫全長（1600ms）+ 100ms 送達餘裕跑完。多推進一點
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
      await gesture.up(
        timeStamp: const Duration(milliseconds: 1180),
      ); // delta 80，邊界內
      await tester.pump();
      expect(resolved, ShotTier.perfect);
    });

    testWidgets('邊界外 1ms（delta 81ms）判 normal——證明結果隨指標時戳而非幀時間改變', (
      tester,
    ) async {
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
      await gesture.up(
        timeStamp: const Duration(milliseconds: 1181),
      ); // delta 81，邊界外 1ms
      await tester.pump();
      expect(resolved, ShotTier.normal);
    });
  });

  group('AC-M5-1.11: 逾時界線與指標時戳同軸', () {
    testWidgets('PointerUp 在 L-1ms 依窗寬判態，不判 timedOut', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up(timeStamp: const Duration(milliseconds: 1599));
      await tester.pump();

      expect(
        find.byKey(const Key('shutterResult.failed.late')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shutterResult.timedOut')), findsNothing);
    });

    testWidgets('PointerUp 在 L+1ms 必須判 timedOut', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (result) => resolved = result,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up(timeStamp: const Duration(milliseconds: 1601));
      await tester.pump();

      expect(resolved, ShotTier.failed);
      expect(find.byKey(const Key('shutterResult.timedOut')), findsOneWidget);
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
      expect(find.byKey(const Key('shutterIndicator.target')), findsOneWidget);
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

    testWidgets('絕景取景框中心跟隨指標移動', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      const down = Offset(120, 140);
      const moved = Offset(360, 260);

      await gesture.down(down, timeStamp: Duration.zero);
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const Key('shutterIndicator.frame'))),
        down,
      );

      await gesture.moveTo(moved, timeStamp: const Duration(milliseconds: 100));
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const Key('shutterIndicator.frame'))),
        moved,
      );
    });

    testWidgets('吻合後外圈繼續縮小，不停在目標圈', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1350));
      await tester.pump(const Duration(milliseconds: 16));

      final dynamicRing = find.byKey(const Key('shutterIndicator.ringDynamic'));
      expect(tester.getSize(dynamicRing).width, lessThan(48));
      expect(tester.getSize(dynamicRing).height, lessThan(48));
    });

    testWidgets('絕景有固定基準框供動態框在吻合時重合', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );

      expect(
        find.byKey(const Key('shutterIndicator.frameBaseline')),
        findsOneWidget,
      );
    });

    testWidgets('絕景動態框在 tMatch 精確重合固定基準框', (tester) async {
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (_) {},
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(
        tester.getSize(find.byKey(const Key('shutterIndicator.frameDynamic'))),
        const Size(112, 112),
      );
    });

    testWidgets('絕景構圖以取景框中心相對畫面目標計算', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (result) => resolved = result,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final target = tester.getCenter(
        find.byKey(const Key('shutterIndicator.framingTarget')),
      );
      final gesture = await tester.createGesture();

      await gesture.down(const Offset(100, 100), timeStamp: Duration.zero);
      await gesture.moveTo(
        target,
        timeStamp: const Duration(milliseconds: 1050),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 1100));
      await tester.pump();

      expect(resolved, ShotTier.perfect);
    });

    testWidgets('絕景構圖忽略放開前 10ms 的 lift-off 座標漂移', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (result) => resolved = result,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final target = tester.getCenter(
        find.byKey(const Key('shutterIndicator.framingTarget')),
      );
      final gesture = await tester.createGesture();

      await gesture.down(target, timeStamp: Duration.zero);
      await gesture.moveTo(
        target,
        timeStamp: const Duration(milliseconds: 1000),
      );
      await gesture.moveTo(
        target + const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 1090),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 1100));
      await tester.pump();

      expect(resolved, ShotTier.perfect);
    });
  });

  group('REQ-M5-01.2: 單一 active pointer', () {
    testWidgets('第二指移動與放開不污染構圖或提前結算', (tester) async {
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (result) => resolved = result,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final target = tester.getCenter(
        find.byKey(const Key('shutterIndicator.framingTarget')),
      );
      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.down(target, timeStamp: Duration.zero);
      await second.down(
        target + const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 100),
      );
      await second.moveTo(
        target + const Offset(120, 0),
        timeStamp: const Duration(milliseconds: 1000),
      );
      await second.up(timeStamp: const Duration(milliseconds: 1100));
      await tester.pump();

      expect(resolved, isNull);
      expect(
        tester.getCenter(find.byKey(const Key('shutterIndicator.frame'))),
        target,
      );

      await first.up(timeStamp: const Duration(milliseconds: 1100));
      await tester.pump();
      expect(resolved, ShotTier.perfect);
    });
  });

  group('REQ-M5-01.13: 操作與逾時事前告知', () {
    testWidgets('非絕景在按下前與進行中都顯示放開與逾時提示', (tester) async {
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

      expect(find.textContaining('按住畫面任何位置'), findsOneWidget);
      expect(find.textContaining('縮到 0 就逾時'), findsOneWidget);

      final gesture = await tester.createGesture();
      await gesture.down(const Offset(150, 150), timeStamp: Duration.zero);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('shutterInstruction')), findsOneWidget);
    });
  });

  group('REQ-M5-04.2: 生命週期中斷', () {
    testWidgets('PointerCancel 單獨只記錄時戳，不結算也不加折扣', (tester) async {
      ShotTier? resolved;
      var interruptions = 0;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (result) => resolved = result,
            onInterrupted: () => interruptions += 1,
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);

      await gesture.cancel(timeStamp: const Duration(milliseconds: 1100));
      await tester.pump();

      expect(resolved, isNull);
      expect(interruptions, 0);
    });

    testWidgets('先 cancel 後 inactive 使用 cancel 時戳結算並記錄一次中斷', (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      ShotTier? resolved;
      var interruptions = 0;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (result) => resolved = result,
            onInterrupted: () => interruptions += 1,
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await gesture.cancel(timeStamp: const Duration(milliseconds: 1400));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(resolved, ShotTier.normal);
      expect(interruptions, 1);
    });

    testWidgets('沒有 cancel 時 inactive 仍以目前幀時戳結算一次中斷', (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      ShotTier? resolved;
      var interruptions = 0;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: false,
            onResolved: (result) => resolved = result,
            onInterrupted: () => interruptions += 1,
          ),
          onTapBelow: () {},
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero, timeStamp: Duration.zero);
      await tester.pump(const Duration(milliseconds: 1100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(resolved, isNotNull);
      expect(interruptions, 1);
    });

    testWidgets('絕景中斷一律視為構圖不通過並降一階', (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      ShotTier? resolved;
      await tester.pumpWidget(
        _wrapWithBelowLayer(
          ShutterQteOverlay(
            difficulty: ShutterDifficulty.photographer,
            isSpotlight: true,
            onResolved: (result) => resolved = result,
            onInterrupted: () {},
          ),
          onTapBelow: () {},
        ),
      );
      final target = tester.getCenter(
        find.byKey(const Key('shutterIndicator.framingTarget')),
      );
      final gesture = await tester.createGesture();
      await gesture.down(target, timeStamp: Duration.zero);
      await gesture.cancel(timeStamp: const Duration(milliseconds: 1100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(resolved, ShotTier.normal);
    });
  });
}
