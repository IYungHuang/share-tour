import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 雙客戶動態審查跳分與 Near Miss 結算彈窗 (ReviewSettlementModal)
class ReviewSettlementModal extends ConsumerStatefulWidget {
  const ReviewSettlementModal({super.key, this.initialReport, this.onClose});

  final ReviewReport? initialReport;
  final VoidCallback? onClose;

  @override
  ConsumerState<ReviewSettlementModal> createState() =>
      _ReviewSettlementModalState();
}

class _ReviewSettlementModalState extends ConsumerState<ReviewSettlementModal> {
  late ClientType _currentClientType;
  ReviewReport? _report;

  @override
  void initState() {
    super.initState();
    final initialType = widget.initialReport != null
        ? (widget.initialReport!.clientType == 'hypeInfluencer'
              ? ClientType.hypeInfluencer
              : ClientType.budgetWorker)
        : ClientType.budgetWorker;
    _currentClientType = initialType;
    _report = widget.initialReport;
  }

  void _switchClient(ClientType type) {
    setState(() {
      _currentClientType = type;
      final state = ref.read(curatorRunControllerProvider);
      final clientSpec = type == ClientType.budgetWorker
          ? ClientSpec.budgetWorker
          : ClientSpec.hypeInfluencer;
      _report = ClientReviewEngine.evaluate(
        client: clientSpec,
        stats: state.currentStats,
      );
    });
  }

  ReviewReport _resolveReport() {
    if (_report != null) return _report!;
    final state = ref.read(curatorRunControllerProvider);
    if (state.latestReport != null &&
        state.latestReport!.clientType == _currentClientType.name) {
      return state.latestReport!;
    }
    final clientSpec = _currentClientType == ClientType.budgetWorker
        ? ClientSpec.budgetWorker
        : ClientSpec.hypeInfluencer;
    return ClientReviewEngine.evaluate(
      client: clientSpec,
      stats: state.currentStats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _resolveReport();
    final outcome = report.outcome;
    final isNearMissOrRejected =
        outcome == ReviewOutcome.nearMiss || outcome == ReviewOutcome.rejected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 頂部把手與標題
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '客戶審查結果',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // 客戶切換頁籤
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      keyName: 'client_tab_budgetWorker',
                      label: '社畜小林 (預算控)',
                      type: ClientType.budgetWorker,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      keyName: 'client_tab_hypeInfluencer',
                      label: '網紅安娜 (爆點控)',
                      type: ClientType.hypeInfluencer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 分數與大印章看板
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, offset: Offset(2, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    // 大印章
                    _buildStamp(outcome),
                    const SizedBox(height: 10),

                    // 滿意度大字
                    Text(
                      '${report.satisfaction} 分',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor(outcome),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 客戶吐槽/金句
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: const Color(0xFFF8FAFC),
                      child: Text(
                        '「${report.feedbackQuote}」',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(height: 20),

                    // 子分數細項
                    _buildSubscores(report),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 操作按鈕 (雙軌：Near Miss 微調 vs 放棄重來)
              if (isNearMissOrRejected) ...[
                ElevatedButton(
                  key: const Key('btn_tweak_itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(curatorRunControllerProvider.notifier)
                        .tweakItinerary();
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: const Text(
                    '🔧 返回微調行程 (保留素材)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('btn_restart_run'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.black38, width: 1),
                  ),
                  onPressed: () {
                    ref
                        .read(curatorRunControllerProvider.notifier)
                        .restartRun();
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: const Text('🔄 放棄並再來一局'),
                ),
              ] else ...[
                ElevatedButton(
                  key: const Key('btn_collect_rewards'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(curatorRunControllerProvider.notifier)
                        .acceptReview();
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: Text(
                    '💰 收下佣金 (+${report.earnedCoins} 金幣)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String keyName,
    required String label,
    required ClientType type,
  }) {
    final isSelected = _currentClientType == type;
    return GestureDetector(
      key: Key(keyName),
      onTap: () => _switchClient(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildStamp(ReviewOutcome outcome) {
    final (text, color, key) = switch (outcome) {
      ReviewOutcome.perfect => (
        '🌟 PERFECT 100',
        const Color(0xFF16A34A),
        'stamp_perfect',
      ),
      ReviewOutcome.pass => ('✅ PASSED', const Color(0xFF0284C7), 'stamp_pass'),
      ReviewOutcome.nearMiss => (
        '🔄 NEAR MISS!',
        const Color(0xFFEA580C),
        'stamp_near_miss',
      ),
      ReviewOutcome.rejected => (
        '❌ REJECTED',
        const Color(0xFFDC2626),
        'stamp_rejected',
      ),
    };

    return Container(
      key: Key(key),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Color _scoreColor(ReviewOutcome outcome) {
    return switch (outcome) {
      ReviewOutcome.perfect => const Color(0xFF16A34A),
      ReviewOutcome.pass => const Color(0xFF0284C7),
      ReviewOutcome.nearMiss => const Color(0xFFEA580C),
      ReviewOutcome.rejected => const Color(0xFFDC2626),
    };
  }

  Widget _buildSubscores(ReviewReport report) {
    if (report.clientType == 'budgetWorker') {
      final budgetScore = report.subscores['budgetScore'] ?? 0;
      final themeScore = report.subscores['themeScore'] ?? 0;
      final boredomPenalty = report.subscores['boredomPenalty'] ?? 0;
      final totalCost = report.subscores['totalCost'] ?? 0;
      final targetBudget = report.subscores['targetBudget'] ?? 2000;
      final isOverspent = totalCost > targetBudget;

      return Column(
        children: [
          _buildScoreRow('預算得分 (超支扣分)', '$budgetScore / 70'),
          _buildScoreRow('主題契合得分', '$themeScore / 30'),
          if (boredomPenalty > 0)
            _buildScoreRow(
              '反無聊懲罰 (Hype<30)',
              '-$boredomPenalty 分',
              isNegative: true,
            ),
          if (isOverspent)
            _buildScoreRow(
              '超支扣分提醒',
              '已超支 ${totalCost - targetBudget} 円',
              isNegative: true,
            ),
        ],
      );
    } else {
      final effectiveHype = report.subscores['effectiveHype'] ?? 0;
      final spotlightMultiplier =
          report.subscores['spotlightMultiplier'] ?? 1.0;
      final themeFactor = report.subscores['themeFactor'] ?? 1.0;
      final hasNoSpotlight = spotlightMultiplier < 1.0;

      return Column(
        children: [
          _buildScoreRow('爆點熱度折算', '$effectiveHype 點'),
          _buildScoreRow('主題加權係數', '${(themeFactor * 100).round()} %'),
          if (hasNoSpotlight)
            _buildScoreRow('絕景打折提醒', '無絕景打五折', isNegative: true),
        ],
      );
    }
  }

  Widget _buildScoreRow(String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isNegative ? const Color(0xFFDC2626) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
