import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

import 'components/live_preview_hud.dart';
import 'components/timeline_rail.dart';
import 'components/waist_bag_drawer.dart';
import 'review_settlement_modal.dart';

/// 策展工作台主容器 (CuratorStudioModal，佔螢幕高度 90%)
class CuratorStudioModal extends ConsumerWidget {
  const CuratorStudioModal({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final philosophy = ref.watch(
      curatorRunControllerProvider.select((s) => s.philosophy),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 頂部導航列
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        '📑 策展工作台',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          philosophy.name,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    key: const Key('studio_close_button'),
                    onTap: () {
                      if (onClose != null) {
                        onClose!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 四幕劇時間線軌道
            const TimelineRail(),

            // 即時數值看板
            LivePreviewHUD(onSubmit: () => _handleSubmit(context, ref)),

            // 阿導腰包抽屜 (可滾動)
            const Expanded(child: WaistBagDrawer()),
          ],
        ),
      ),
    );
  }

  void _handleSubmit(BuildContext context, WidgetRef ref) {
    // 預設以社畜視角呈送
    ref
        .read(curatorRunControllerProvider.notifier)
        .submitReview(ClientType.budgetWorker);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => const ReviewSettlementModal(),
    );
  }
}
