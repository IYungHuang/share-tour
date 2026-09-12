import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 即時數值看板組件 (LivePreviewHUD)
/// 遵循 AC-CF-3.2：不含 finalTheme / totalHype 之渲染，絕景區以 4 格 pip 呈現，社畜局呈現階梯張力警示
class LivePreviewHUD extends ConsumerWidget {
  const LivePreviewHUD({super.key, this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(itineraryStatsProvider);
    final client = ref.watch(
      curatorRunControllerProvider.select((s) => s.client),
    );
    final canSubmit = ref.watch(
      curatorRunControllerProvider.select((s) => s.canSubmit),
    );
    final submissionIssue = ref.watch(
      curatorRunControllerProvider.select((s) => s.submissionIssue),
    );

    final targetBudget = client.targetBudget;
    final isOverspent = stats.totalCost > targetBudget;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(2, 2)),
          ],
        ),
        child: Column(
          children: [
            // 看板標題（呈現當前委託客戶具名稱呼，取消客群切換器）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '即時試算看板',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${client.personaName}（${client.displayName}）',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const Divider(height: 10, thickness: 1),

            // 數值與因果指標列
            Row(
              children: [
                // 1. 開銷
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        '預算開銷',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      Text(
                        '¥${stats.totalCost} / ¥$targetBudget',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOverspent
                              ? const Color(0xFFDC2626)
                              : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 2. 焦點絕景 4 格 pip (AC-CF-3.2, SPEC §3.1.2)
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        '焦點絕景',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < 3; i++) ...[
                              Text(
                                i < stats.spotlightCount ? '●' : '○',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: i < stats.spotlightCount
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                            Text(
                              stats.spotlightCount >= 4 ? '★' : '☆',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: stats.spotlightCount >= 4
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              stats.spotlightCount >= 4 ? '🌟 絕景大滿貫' : '📉 絕景缺口',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: stats.spotlightCount >= 4
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. 氛圍與張力警示 (社畜反無聊 / 網紅主題)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        client.type == ClientType.budgetWorker ? '反無聊警示' : '行程氛圍',
                        style: const TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      _buildTensionWarning(client, stats),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 呈送審查按鈕
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                key: const Key('submit_itinerary_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit
                      ? const Color(0xFF16A34A)
                      : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  elevation: canSubmit ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                onPressed: canSubmit ? (onSubmit ?? () {}) : null,
                child: Text(
                  canSubmit
                      ? '呈送客戶審查'
                      : switch (submissionIssue) {
                          ItinerarySubmissionIssue.nonContiguous => '素材需連續排列',
                          _ => '至少安排 3 個時段',
                        },
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTensionWarning(ClientSpec client, ItineraryStats stats) {
    if (client.type == ClientType.budgetWorker) {
      if (stats.totalHype < 120) {
        return const Text(
          '🚨 極度乏味',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        );
      } else if (stats.totalHype < 168) {
        return const Text(
          '⚠️ 稍嫌平淡',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
          ),
        );
      } else {
        return const SizedBox.shrink(); // totalHype >= 168 即時消褪
      }
    }
    return const Text(
      '✨ 網紅話題',
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF805AD5),
      ),
    );
  }
}
