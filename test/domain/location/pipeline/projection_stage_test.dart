import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/pipeline/projection_stage.dart';
import '../../../fakes/fake_map_manifest.dart';

void main() {
  test('AC-4.1 目標點等於範圍檢查通過後投影再吸附的結果', () {
    final m = FakeMapManifest.linear();
    final r = ProjectionStage(m).project(24.0, 121.0) as Projected;
    final reference = FakeMapManifest.linear();
    final expected =
        reference.snapToRoad(reference.projectToPixel(24.0, 121.0));
    expect(r.pixel, expected);
  });

  test('AC-4.4 / AC-0.1 範圍外時不呼叫投影', () {
    final m = FakeMapManifest.linear()..resetCallCounts();
    final r = ProjectionStage(m).project(80.0, 0.0);
    expect(r, isA<OutsideCoverage>());
    expect(m.projectCallCount, 0,
        reason: 'IDW 對範圍外輸入不報錯，只回傳凸包內看似合理的錯點，'
            '所以範圍檢查必須在投影之前');
  });

  test('AC-4.3 距所有道路超過上限則不吸附', () {
    final m = FakeMapManifest.linear(); // 路網在 y=100
    final r = ProjectionStage(m).project(24.9, 121.0) as Projected;
    expect(r.pixel, Vector2(100, 10), reason: '距路網 90px > 50px 上限');
  });

  test('在吸附範圍內則被拉到路段上', () {
    final m = FakeMapManifest.linear();
    // 緯度 24.7 → y = 30；距路網 70px，仍超過上限
    // 緯度 24.6 → y = 40；距路網 60px，超過上限
    // 緯度 24.55 → y = 45；距路網 55px，超過上限
    // 緯度 24.5 → y = 50；距路網 50px，恰為上限 → 吸附
    final r = ProjectionStage(m).project(24.5, 121.0) as Projected;
    expect(r.pixel, Vector2(100, 100));
  });
}
