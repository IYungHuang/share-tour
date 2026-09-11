import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 即時數值看板組件 (LivePreviewHUD)
class LivePreviewHUD extends ConsumerStatefulWidget {
  const LivePreviewHUD({super.key, this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  ConsumerState<LivePreviewHUD> createState() => _LivePreviewHUDState();
}

class _LivePreviewHUDState extends ConsumerState<LivePreviewHUD> {
  ClientType _selectedClientView = ClientType.budgetWorker;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(itineraryStatsProvider);
    final canSubmit = ref.watch(
      curatorRunControllerProvider.select((s) => s.canSubmit),
    );
    final submissionIssue = ref.watch(
      curatorRunControllerProvider.select((s) => s.submissionIssue),
    );

    final targetBudget = switch (_selectedClientView) {
      ClientType.budgetWorker => ClientSpec.budgetWorker.targetBudget,
      ClientType.hypeInfluencer => ClientSpec.hypeInfluencer.targetBudget,
    };

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
            // 客群視角切換器
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '即時試算看板',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildClientTab(
                      label: '社畜視角',
                      type: ClientType.budgetWorker,
                    ),
                    const SizedBox(width: 4),
                    _buildClientTab(
                      label: '網紅視角',
                      type: ClientType.hypeInfluencer,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 10, thickness: 1),

            // 數值指標列
            Row(
              children: [
                // 開銷
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

                // 熱度
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        '有效爆點',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      Text(
                        '🔥 ${stats.totalHype}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 主題性
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        '主題適配',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      Text(
                        '🎯 ${stats.finalTheme} / 100',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                onPressed: canSubmit ? (widget.onSubmit ?? () {}) : null,
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

  Widget _buildClientTab({required String label, required ClientType type}) {
    final isSelected = _selectedClientView == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedClientView = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
