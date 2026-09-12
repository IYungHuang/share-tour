import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/causal/curator_codex.dart';

/// 策展手冊詞條彈出氣泡組件 (CodexTooltip, AC-CF-3.3)
class CodexTooltip extends StatelessWidget {
  const CodexTooltip({
    super.key,
    required this.reasonCode,
    required this.entry,
  });

  final String reasonCode;
  final CodexEntry entry;

  static Future<void> show(BuildContext context, String reasonCode) {
    final entry = CuratorCodex.entries[reasonCode];
    if (entry == null) return Future.value();

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (ctx) => CodexTooltip(
        reasonCode: reasonCode,
        entry: entry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: Key('codex_tooltip_$reasonCode'),
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題與行話
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('📖 ', style: TextStyle(fontSize: 14)),
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.jargon,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 16),

              // 解釋
              Text(
                entry.explanation,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // 阿導筆記
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  entry.guideNote,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF38BDF8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
