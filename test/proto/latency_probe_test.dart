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

  group('閒置丟棄', () {
    test('間隔超過門檻的那一筆不採計', () {
      final s = JitterStats();
      var t = Duration.zero;
      for (var i = 0; i < 5; i++) {
        t += const Duration(milliseconds: 300);
        expect(s.add(10, t), isTrue);
      }
      t += JitterStats.idleGap + const Duration(milliseconds: 1);
      expect(s.add(10, t), isFalse, reason: '閒置後的第一筆帶著喚醒延遲');
      expect(s.count, 5);
    });

    test('第一筆沒有前筆可比，須採計', () {
      final s = JitterStats();
      expect(s.add(10, const Duration(seconds: 99)), isTrue);
      expect(s.count, 1);
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

  group('裁決三段（回歸：曾在 σ=40 放硬懸崖，越線即紅字但建議值只差 1 ms）', () {
    JitterStats statsWithMad(double mad) {
      final s = JitterStats();
      // 對稱雙點分佈：MAD 恰為該值。
      feed(s, [for (var i = 0; i < 40; i++) i.isEven ? mad : -mad]);
      return s;
    }

    test('窗寬有 25% 以上餘裕 → 充裕', () {
      final s = statsWithMad(4); // robustSigma 約 5.9 → 建議 120（地板）
      expect(s.verdictFor(240), JitterVerdict.comfortable);
    });

    test('窗寬剛好等於建議值 → 臨界，不是抽獎', () {
      final s = statsWithMad(4);
      expect(s.recommendedWindowMs, JitterStats.windowFloorMs);
      expect(s.verdictFor(120), JitterVerdict.marginal);
    });

    test('窗寬低於建議值 → 抽獎', () {
      final s = statsWithMad(40); // robustSigma 59.3 → 建議 178
      expect(s.recommendedWindowMs, greaterThan(120));
      expect(s.verdictFor(120), JitterVerdict.lottery);
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

  test('clear 會一併清掉基準與閒置狀態', () {
    final s = JitterStats();
    s.add(999999, const Duration(milliseconds: 100));
    s.clear();
    expect(s.add(0, const Duration(milliseconds: 200)), isTrue);
    expect(s.count, 1);
  });
}
