import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_district_street_manifest.dart';
import 'package:share_tour/ui/core_loop/field/kyoto_district_selector_modal.dart';

void main() {
  group('KyotoDistrictSelectorModal 五大分區漫步指南彈窗測試', () {
    testWidgets('1. 完整渲染五大分區選項與標題', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KyotoDistrictSelectorModal(
              onSelectDistrict: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('京都街區漫步指南'), findsOneWidget);
      expect(find.text('選擇深入體驗的中觀散步道（1km × 1km 探索層次）'), findsOneWidget);

      expect(find.text('洛中・河原町街區'), findsOneWidget);
      expect(find.text('洛東・祇園清水街區'), findsOneWidget);
      expect(find.text('洛西・嵐山嵯峨街區'), findsOneWidget);
      expect(find.text('洛東北・左京大文字街區'), findsOneWidget);
      expect(find.text('洛南・伏見宇治街區'), findsOneWidget);
    });

    testWidgets('2. 點擊特定分區項目觸發回呼並回傳對應分區類型', (tester) async {
      KyotoDistrictType? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KyotoDistrictSelectorModal(
              onSelectDistrict: (d) => selected = d,
            ),
          ),
        ),
      );

      // 點擊嵐山分區
      await tester.tap(find.byKey(const Key('district_select_kyoto_arashiyama')));
      await tester.pump();

      expect(selected, KyotoDistrictType.arashiyama);
    });
  });
}
