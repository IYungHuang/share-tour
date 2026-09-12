import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/proto/shutter_verdict.dart';

void main() {
  group('三態判定（v4 REQ-M5-01）', () {
    test('AC-M5-1.1 photographer 的三個代表點', () {
      expect(
        judgeShutter(ShutterDifficulty.photographer, const Pressed(100)),
        ShutterTier.perfect,
      );
      expect(
        judgeShutter(ShutterDifficulty.photographer, const Pressed(200)),
        ShutterTier.normal,
      );
      expect(
        judgeShutter(ShutterDifficulty.photographer, const Pressed(400)),
        ShutterTier.failed,
      );
    });

    test('AC-M5-1.2 完美窗邊界採閉區間', () {
      for (final d in ShutterDifficulty.values) {
        final p = shutterParamTable[d]!;
        final half = p.perfectWindowMs ~/ 2;
        expect(
          judgeShutter(d, Pressed(half)),
          ShutterTier.perfect,
          reason: '$d 的 Wp/2 = $half 應仍為 perfect（閉區間）',
        );
        expect(
          judgeShutter(d, Pressed(half + 1)),
          isNot(ShutterTier.perfect),
          reason: '$d 超出 Wp/2 一毫秒即不得為 perfect',
        );
      }
    });

    test('AC-M5-1.2 普通窗邊界（tourist 無上限故不適用）', () {
      for (final d in [
        ShutterDifficulty.photographer,
        ShutterDifficulty.decisiveMoment,
      ]) {
        final half = shutterParamTable[d]!.normalWindowMs! ~/ 2;
        expect(judgeShutter(d, Pressed(half)), ShutterTier.normal);
        expect(judgeShutter(d, Pressed(half + 1)), ShutterTier.failed);
      }
    });

    test('AC-M5-1.3 tourist 只要放開就不可能 failed', () {
      for (var offset = 0; offset <= 5000; offset += 7) {
        expect(
          judgeShutter(ShutterDifficulty.tourist, Pressed(offset)),
          isNot(ShutterTier.failed),
          reason: 'offset=$offset',
        );
      }
    });

    test('AC-M5-1.4 三檔的完美窗皆不低於 120 ms 硬下限', () {
      for (final d in ShutterDifficulty.values) {
        expect(
          shutterParamTable[d]!.perfectWindowMs,
          greaterThanOrEqualTo(ShutterParams.minPerfectWindowMs),
          reason: '$d',
        );
      }
    });

    test('AC-M5-1.5 逾時在三檔皆為 failed，含 tourist', () {
      for (final d in ShutterDifficulty.values) {
        expect(judgeShutter(d, const TimedOut()), ShutterTier.failed,
            reason: '$d 的逾時必須優先於難度參數');
      }
    });

    test('AC-M5-1.7 同一輸入重複呼叫結果一致', () {
      final first = judgeShutter(
        ShutterDifficulty.decisiveMoment,
        const Pressed(61),
      );
      for (var i = 0; i < 1000; i++) {
        expect(
          judgeShutter(ShutterDifficulty.decisiveMoment, const Pressed(61)),
          first,
        );
      }
    });

    test('完美窗不得低於下限：違規參數在建構時即失敗', () {
      expect(
        () => ShutterParams(
          matchMs: 800,
          perfectWindowMs: 60,
          normalWindowMs: 300,
          totalMs: 1200,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('完美窗落在動畫全長之內（參數表自檢）', () {
      for (final entry in shutterParamTable.entries) {
        final p = entry.value;
        final lo = p.matchMs - p.perfectWindowMs / 2;
        final hi = p.matchMs + p.perfectWindowMs / 2;
        expect(lo, greaterThanOrEqualTo(0), reason: '${entry.key} 完美窗起點');
        expect(hi, lessThanOrEqualTo(p.totalMs), reason: '${entry.key} 完美窗終點');
      }
    });
  });

  group('絕景構圖懲罰（v4 REQ-M5-03.5）', () {
    test('AC-M5-4.2 構圖通過則最終態等於時機態', () {
      for (final t in ShutterTier.values) {
        expect(applyFramingPenalty(t, framingOk: true), t);
      }
    });

    test('AC-M5-4.2 構圖不通過則下降一階，且 perfect 不會直接掉到 failed', () {
      expect(
        applyFramingPenalty(ShutterTier.perfect, framingOk: false),
        ShutterTier.normal,
      );
      expect(
        applyFramingPenalty(ShutterTier.normal, framingOk: false),
        ShutterTier.failed,
      );
      expect(
        applyFramingPenalty(ShutterTier.failed, framingOk: false),
        ShutterTier.failed,
      );
    });
  });

  group('節奏預算（v4 REQ-M5-09）', () {
    test('AC-M5-10.2 最壞情況：Lv.3 球鞋 26 次，三檔皆須 <= 90 秒', () {
      // gatheringHpCost = riskLevel * 6；Lv.3 球鞋 155 HP。
      // 取材前置是 currentHp > 0（非「HP 足夠支付」），故 25 次用掉 150 HP
      // 後仍剩 5 HP，第 26 次合法。
      const worstCaseGathers = 26;
      for (final entry in shutterParamTable.entries) {
        final totalMs = entry.value.ceremonyMs * worstCaseGathers;
        expect(
          totalMs,
          lessThanOrEqualTo(90 * 1000),
          reason: '${entry.key} 在 $worstCaseGathers 次下為 ${totalMs / 1000} 秒',
        );
      }
    });
  });
}
