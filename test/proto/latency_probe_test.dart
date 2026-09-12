import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/proto/latency_probe.dart';

void main() {
  group('抖動統計（回歸：epoch 差異曾讓全部樣本被丟掉）', () {
    test('指標時戳與本地時鐘的 epoch 差達數億毫秒時，樣本仍須被收下', () {
      final stats = LatencyStats();
      // 模擬裝置已開機 3 天：差值約 2.6e8 ms。
      const uptimeOffset = 259200000.0;
      for (var i = 0; i < 40; i++) {
        stats.add(uptimeOffset + (i.isEven ? 8 : -8));
      }
      expect(stats.count, 40, reason: 'epoch 差異不得使樣本被當成雜訊丟棄');
      expect(stats.sigma, greaterThan(0), reason: 'σ 必須算得出來');
    });

    test('σ 與 epoch 無關：整體平移不改變抖動', () {
      final a = LatencyStats();
      final b = LatencyStats();
      const samples = [0.0, 5.0, -5.0, 12.0, -3.0, 7.0, -9.0, 2.0];
      for (final s in samples) {
        a.add(s);
        b.add(s + 987654321);
      }
      expect(b.sigma, closeTo(a.sigma, 1e-6));
    });

    test('扣掉基準後仍離群的才丟棄（例如 App 切出去又切回來）', () {
      final stats = LatencyStats();
      for (var i = 0; i < 10; i++) {
        stats.add(1000 + i.toDouble());
      }
      final before = stats.count;
      stats.add(1000 + 5000); // 相對基準 +5000 ms，真雜訊
      expect(stats.count, before);
    });

    test('裁決依 §6 待決 1 的 40 ms 判準', () {
      final low = LatencyStats();
      final high = LatencyStats();
      for (var i = 0; i < LatencyStats.minSamplesForVerdict; i++) {
        low.add(i.isEven ? 5 : -5); // σ 約 5 ms
        high.add(i.isEven ? 80 : -80); // σ 約 80 ms
      }
      expect(low.verdict, LatencyVerdict.trainable);
      expect(high.verdict, LatencyVerdict.lottery);
    });

    test('樣本不足時不裁決', () {
      final stats = LatencyStats();
      for (var i = 0; i < LatencyStats.minSamplesForVerdict - 1; i++) {
        stats.add(i.toDouble());
      }
      expect(stats.verdict, LatencyVerdict.insufficientData);
    });

    test('建議最小完美窗不低於 120 ms 的絕對下限', () {
      final stats = LatencyStats();
      for (var i = 0; i < 40; i++) {
        stats.add(i.isEven ? 0.5 : -0.5); // 極低抖動
      }
      expect(stats.recommendedMinWindowMs, ShutterWindowFloor.absolute);
    });

    test('高抖動時建議窗寬為 3σ', () {
      final stats = LatencyStats();
      for (var i = 0; i < 40; i++) {
        stats.add(i.isEven ? 100 : -100);
      }
      expect(stats.recommendedMinWindowMs, closeTo(3 * stats.sigma, 1e-6));
      expect(stats.recommendedMinWindowMs, greaterThan(120));
    });

    test('clear 會一併清掉基準', () {
      final stats = LatencyStats()..add(999999);
      stats.clear();
      stats.add(0);
      expect(stats.count, 1);
    });
  });
}
