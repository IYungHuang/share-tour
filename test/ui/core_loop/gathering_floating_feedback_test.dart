import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/ui/core_loop/field/gathering_floating_feedback_overlay.dart';

void main() {
  group('GatheringFloatingFeedbackOverlay 測試 (G5, REQ-M3-06)', () {
    testWidgets('觸發漂浮反饋時呈現 -HP 與 +素材文字，1.2s 後自動消失', (tester) async {
      final controller = GatheringFloatingFeedbackController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('地圖背景')),
                GatheringFloatingFeedbackOverlay(controller: controller),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('HP'), findsNothing);

      // 觸發反饋
      controller.showFeedback(
        materialName: '台北101觀景台',
        hpCost: 14,
        isSpotlight: true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 驗證飄字內容
      expect(find.text('-14 HP'), findsOneWidget);
      expect(find.textContaining('台北101觀景台'), findsOneWidget);
      expect(find.text('✨ SPOTLIGHT!'), findsOneWidget);

      // 動畫推進 1.2 秒
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // 動畫結束，飄字消失
      expect(find.text('-14 HP'), findsNothing);
      expect(find.textContaining('台北101觀景台'), findsNothing);
    });
  });
}
