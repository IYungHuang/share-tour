import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/shutter/held_ms.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_input.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_judge.dart';

HeldMs heldFor(int ms) => HeldMs(
      downTimeStamp: Duration.zero,
      upTimeStamp: Duration(milliseconds: ms),
    );

void main() {
  group('AC-M5-1.1: photographer 三態邊界', () {
    test('Δt=60 → perfect（tMatch 1100, Wp 160 → 邊界 80）', () {
      expect(
        judgeShutter(Pressed(heldFor(1100 + 60)), ShutterDifficulty.photographer),
        ShotTier.perfect,
      );
    });
    test('Δt=200 → normal', () {
      expect(
        judgeShutter(Pressed(heldFor(1100 + 200)), ShutterDifficulty.photographer),
        ShotTier.normal,
      );
    });
    test('Δt=400 → failed（Wn/2=360）', () {
      expect(
        judgeShutter(Pressed(heldFor(1100 + 400)), ShutterDifficulty.photographer),
        ShotTier.failed,
      );
    });
  });

  group('AC-M5-1.2: 邊界值閉區間', () {
    test('decisiveMoment Wp/2=60 邊界含端點', () {
      expect(
        judgeShutter(Pressed(heldFor(800 + 60)), ShutterDifficulty.decisiveMoment),
        ShotTier.perfect,
      );
      expect(
        judgeShutter(Pressed(heldFor(800 + 61)), ShutterDifficulty.decisiveMoment),
        ShotTier.normal,
      );
    });
    test('decisiveMoment Wn/2=150 邊界含端點', () {
      expect(
        judgeShutter(Pressed(heldFor(800 + 150)), ShutterDifficulty.decisiveMoment),
        ShotTier.normal,
      );
      expect(
        judgeShutter(Pressed(heldFor(800 + 151)), ShutterDifficulty.decisiveMoment),
        ShotTier.failed,
      );
    });
  });

  group('AC-M5-1.3: tourist 恆無 failed', () {
    test('任意 Δt 皆不產生 failed', () {
      for (final ms in [0, 100, 1400, 2000, 5000, 100000]) {
        expect(
          judgeShutter(Pressed(heldFor(ms)), ShutterDifficulty.tourist),
          isNot(ShotTier.failed),
        );
      }
    });
  });

  group('AC-M5-1.5/1.6: timedOut', () {
    test('三檔難度下 timedOut 皆判 failed，含 tourist', () {
      for (final d in ShutterDifficulty.values) {
        expect(judgeShutter(const TimedOut(), d), ShotTier.failed);
      }
    });
  });

  group('AC-M5-1.7: 純函式一致性與靜態檢查', () {
    test('同一輸入重複呼叫 1000 次結果一致', () {
      final input = Pressed(heldFor(1100 + 60));
      final first = judgeShutter(input, ShutterDifficulty.photographer);
      for (var i = 0; i < 1000; i++) {
        expect(judgeShutter(input, ShutterDifficulty.photographer), first);
      }
    });

    test('判定模組不出現 DateTime.now / Random', () async {
      final src = await File(
        'lib/domain/core_loop/shutter/shutter_judge.dart',
      ).readAsString();
      expect(src.contains('DateTime.now'), isFalse);
      expect(src.contains('Random'), isFalse);
    });
  });

  group('AC-M5-1.8: 判定模組不出現 riskLevel/cameraLevel', () {
    test('原始碼靜態檢查', () async {
      final src = await File(
        'lib/domain/core_loop/shutter/shutter_judge.dart',
      ).readAsString();
      expect(src.contains('riskLevel'), isFalse);
      expect(src.contains('cameraLevel'), isFalse);
    });
  });

  group('AC-M5-1.9: 時戳取自指標事件而非幀時間', () {
    test('跨過 Wp/2 邊界時判定結果因指標時戳改變', () {
      // decisiveMoment tMatch=800, Wp/2=60；850ms 邊界內，851ms 邊界外。
      final inside = HeldMs(
        downTimeStamp: Duration.zero,
        upTimeStamp: const Duration(milliseconds: 860),
      );
      final outside = HeldMs(
        downTimeStamp: Duration.zero,
        upTimeStamp: const Duration(milliseconds: 861),
      );
      expect(
        judgeShutter(Pressed(inside), ShutterDifficulty.decisiveMoment),
        ShotTier.perfect,
      );
      expect(
        judgeShutter(Pressed(outside), ShutterDifficulty.decisiveMoment),
        ShotTier.normal,
      );
    });
  });
}
