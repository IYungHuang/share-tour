import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/pipeline/projection_stage.dart';
import '../../../fakes/fake_map_manifest.dart';

void main() {
  test('AC-4.1 目標點等於範圍檢查通過後投影的結果（修訂四：吸附已刪除）', () {
    final m = FakeMapManifest.linear();
    final r = ProjectionStage(m).project(24.0, 121.0) as Projected;
    final reference = FakeMapManifest.linear();
    final expected = reference.projectToPixel(24.0, 121.0);
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

  test('AC-4.7 圖資介面不存在吸附與道路節點相關成員（靜態檢查）', () {
    final source =
        File('lib/domain/location/projection/map_manifest.dart').readAsStringSync();
    for (final banned in ['snapToRoad', 'snapLimitMeters', 'roadNodes']) {
      expect(source.contains(banned), isFalse,
          reason: '圖資介面不得保留 $banned（修訂四，v6 刪除道路吸附）');
    }
  });
}
