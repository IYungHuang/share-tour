import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 客戶意圖表情頭像組件 (ClientExpressionTile, AC-CF-3.1)
/// 僅呈現本局指派客戶（單一），依 clientImpression 六態切換，點擊彈出定性心態氣泡
class ClientExpressionTile extends ConsumerWidget {
  const ClientExpressionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 嚴格依 AC-CF-3.1：單一客戶表情元件，監聽本局指派客戶與心態
    final client = ref.watch(
      curatorRunControllerProvider.select((s) => s.client),
    );
    final impression = ref.watch(
      itineraryCausalReportProvider.select((r) => r.clientImpression),
    );

    final (icon, dialogue) = _resolveImpression(impression);

    return GestureDetector(
      key: const Key('client_expression'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _showBubble(context, client, dialogue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _resolveBorderColor(impression),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Text(
                icon,
                key: ValueKey(impression),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              client.personaName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (String, String) _resolveImpression(ClientImpression impression) {
    return switch (impression) {
      ClientImpression.ecstatic => (
        '🤩',
        '太棒了！這簡直是為我量身打造的完美行程！',
      ),
      ClientImpression.pleased => (
        '😊',
        '很不錯呢，有打中我的期待，通過！',
      ),
      ClientImpression.neutral => (
        '😐',
        '還行吧，但總覺得差了那麼一點點...',
      ),
      ClientImpression.stressed => (
        '😰',
        '這真的不行...雖然有些亮點，但整體問題太大。',
      ),
      ClientImpression.furious => (
        '😡',
        '完全不知所云！這是在整我嗎？立刻重排！',
      ),
      ClientImpression.idle => (
        '💤',
        '阿導，行程還沒排完呢，我先瞇一下...',
      ),
    };
  }

  static Color _resolveBorderColor(ClientImpression impression) {
    return switch (impression) {
      ClientImpression.ecstatic => const Color(0xFFF59E0B),
      ClientImpression.pleased => const Color(0xFF10B981),
      ClientImpression.neutral => const Color(0xFF64748B),
      ClientImpression.stressed => const Color(0xFFEA580C),
      ClientImpression.furious => const Color(0xFFDC2626),
      ClientImpression.idle => const Color(0xFF475569),
    };
  }

  void _showBubble(BuildContext context, ClientSpec client, String dialogue) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const Key('client_expression_bubble'),
            constraints: const BoxConstraints(maxWidth: 280),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${client.personaName}（${client.displayName}）',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dialogue,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
