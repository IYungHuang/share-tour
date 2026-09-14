import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/proto/latency_probe.dart';

/// 便利包裝：以固定間隔連續餵樣本，模擬玩家連打。
void feed(JitterStats s, Iterable<double> deltas, {int stepMs = 400}) {
  var t = Duration.zero;
  for (final d in deltas) {
    t += Duration(milliseconds: stepMs);
    s.add(d, t);
  }
}

void main() {
  group('epoch 差異（回歸：曾讓全部樣本被丟掉，n 一直是 0）', () {
    test('指標時戳與本地時鐘相差數億毫秒時，樣本仍須被收下', () {
      final s = JitterStats();
      // 裝置已開機 3 天：差值約 2.6e8 ms。
      feed(s, [for (var i = 0; i < 40; i++) 259200000 + (i.isEven ? 8 : -8)]);
      expect(s.count, 40, reason: 'epoch 差異不得使樣本被當成雜訊丟棄');
      expect(s.mad, greaterThan(0));
    });

    test('離散度與 epoch 無關：整體平移不改變 MAD 與 σ', () {
      final a = JitterStats();
      final b = JitterStats();
      const samples = [0.0, 5.0, -5.0, 12.0, -3.0, 7.0, -9.0, 2.0];
      feed(a, samples);
      feed(b, samples.map((x) => x + 987654321));
      expect(b.mad, closeTo(a.mad, 1e-6));
      expect(b.sigma, closeTo(a.sigma, 1e-6));
    });
  });

  group('穩健統計（回歸：σ 曾因少數離群值從 12.8 跳到 40.2）', () {
    test('少數離群值大幅抬高 σ，但幾乎不動 MAD', () {
      final clean = JitterStats();
      final dirty = JitterStats();
      final base = [for (var i = 0; i < 40; i++) i.isEven ? 6.0 : -6.0];
      feed(clean, base);
      feed(dirty, [...base, 400.0, -380.0, 420.0]);

      expect(
        dirty.sigma,
        greaterThan(clean.sigma * 2),
        reason: 'σ 對離群值敏感 —— 這正是它不能當裁決依據的理由',
      );
      expect(
        dirty.mad,
        closeTo(clean.mad, 1.0),
        reason: 'MAD 幾乎不受少數離群值影響',
      );
    });

    test('常態樣本下 穩健σ 與 σ 同量級', () {
      final s = JitterStats();
      feed(s, [
        for (var i = 0; i < 60; i++) (i % 7 - 3) * 4.0,
      ]);
      expect(s.robustSigma, closeTo(s.sigma, s.sigma * 0.8));
    });
  });

  group('閒置樣本（回歸：1500 ms 門檻設在人的再進入時間之下，42 筆丟掉 39 筆）', () {
    test('閒置後的第一筆須被採計 —— 它正是遊戲內的典型情境', () {
      final s = JitterStats();
      var t = Duration.zero;
      for (var i = 0; i < 5; i++) {
        t += const Duration(milliseconds: 300);
        expect(s.add(10, t), isTrue);
      }
      t += const Duration(seconds: 15);
      expect(
        s.add(10, t),
        isTrue,
        reason: '兩次取材之間玩家要走路，閒置後按下不是雜訊',
      );
      expect(s.count, 6);
    });

    test('實測節奏（每次 15.1 s）下不得清空母體', () {
      final s = JitterStats();
      var t = Duration.zero;
      for (var i = 0; i < 42; i++) {
        t += const Duration(milliseconds: 15100);
        s.add(i.isEven ? 8 : -8, t);
      }
      expect(s.count, 42, reason: '正常節奏按滿 42 次就該有 42 筆');
      expect(s.verdictFor(120), isNot(JitterVerdict.insufficientData));
    });

    test('連續子集與全樣本併列，閒置後的按壓只計入全樣本', () {
      // 組成比照實測：少數連打，多數是走過去才按 —— 後者帶著喚醒延遲。
      final s = JitterStats();
      var t = Duration.zero;
      for (var i = 0; i < 5; i++) {
        t += const Duration(milliseconds: 300);
        s.add(10, t);
      }
      for (var i = 0; i < 10; i++) {
        t += const Duration(seconds: 15);
        s.add(i.isEven ? 60 : -40, t);
      }

      expect(s.count, 15);
      expect(s.continuousCount, 4, reason: '第一筆無前筆可比，不算連續');
      expect(
        s.continuousRobustSigma,
        lessThan(s.robustSigma),
        reason: '排除閒置樣本會讓估計偏樂觀 —— 這正是要併列兩者的理由',
      );
    });

    test('第一筆沒有前筆可比，計入全樣本但不計入連續子集', () {
      final s = JitterStats();
      expect(s.add(10, const Duration(seconds: 99)), isTrue);
      expect(s.count, 1);
      expect(s.continuousCount, 0);
    });

    test('扣掉基準後仍離群的丟棄（例如切出去又切回來）', () {
      final s = JitterStats();
      feed(s, [for (var i = 0; i < 10; i++) 1000 + i.toDouble()]);
      final before = s.count;
      var t = const Duration(milliseconds: 4000 + 300);
      expect(s.add(1000 + 5000, t), isFalse);
      t += const Duration(milliseconds: 300);
      expect(s.count, before);
    });
  });

  group('裁決四段（回歸：曾在 σ=40 放硬懸崖，越線即紅字但建議值只差 1 ms）', () {
    JitterStats statsWithMad(double mad) {
      final s = JitterStats();
      // 首筆是基準，會被扣成 0 —— 所以要讓首筆落在分佈中心，否則整組被平移
      // 半個振幅，實際 MAD 會是傳入值的兩倍。
      feed(s, [0, for (var i = 0; i < 40; i++) i.isEven ? mad : -mad]);
      return s;
    }

    // 抖動須高到不被下限綁住，否則裁決會（正確地）落在 unconstrained，
    // 就測不到餘裕分段本身。
    test('窗寬有 25% 以上餘裕 → 充裕', () {
      final s = statsWithMad(40); // 穩健σ 59.3 → 建議 178
      expect(s.verdictFor(240), JitterVerdict.comfortable);
    });

    test('窗寬剛好夠但無餘裕 → 臨界，不是抽獎', () {
      final s = statsWithMad(40);
      expect(s.recommendedWindowMs, greaterThan(JitterStats.windowFloorMs));
      expect(s.verdictFor(180), JitterVerdict.marginal);
    });

    test('窗寬低於建議值 → 抽獎', () {
      final s = statsWithMad(40); // 穩健σ 59.3 → 建議 178
      expect(s.recommendedWindowMs, greaterThan(120));
      expect(s.verdictFor(120), JitterVerdict.lottery);
    });

    test('抖動遠低於下限時，裁決不得卡在「臨界」（實測 穩健σ 0.7 ms）', () {
      final s = statsWithMad(0.5);
      expect(s.recommendedWindowMs, JitterStats.windowFloorMs);
      expect(
        s.verdictFor(JitterStats.windowFloorMs),
        JitterVerdict.unconstrained,
        reason: '建議值被下限綁住時，比 needed × 1.25 必然不成立 —— '
            '抖動越低越卡在臨界，是判準自己打自己',
      );
    });

    test('窗寬低於絕對下限時仍是抽獎，不因抖動低而放行', () {
      final s = statsWithMad(0.5);
      expect(
        s.verdictFor(JitterStats.windowFloorMs - 1),
        JitterVerdict.lottery,
      );
    });

    test('樣本不足時不裁決', () {
      final s = JitterStats();
      feed(s, [
        for (var i = 0; i < JitterStats.minSamplesForVerdict - 1; i++)
          i.toDouble(),
      ]);
      expect(s.verdictFor(120), JitterVerdict.insufficientData);
    });
  });

  group('建議窗寬', () {
    test('低抖動時由 120 ms 絕對下限綁住', () {
      final s = JitterStats();
      feed(s, [for (var i = 0; i < 40; i++) i.isEven ? 0.5 : -0.5]);
      expect(s.recommendedWindowMs, JitterStats.windowFloorMs);
    });

    test('高抖動時為 3 × 穩健σ', () {
      final s = JitterStats();
      feed(s, [for (var i = 0; i < 40; i++) i.isEven ? 100.0 : -100.0]);
      expect(s.recommendedWindowMs, closeTo(3 * s.robustSigma, 1e-6));
      expect(s.recommendedWindowMs, greaterThan(120));
    });
  });

  test('clear 會一併清掉基準、連續子集與閒置狀態', () {
    final s = JitterStats();
    s.add(999999, const Duration(milliseconds: 100));
    s.clear();
    expect(s.add(0, const Duration(milliseconds: 200)), isTrue);
    expect(s.continuousCount, 0);
    expect(s.count, 1);
  });
}
