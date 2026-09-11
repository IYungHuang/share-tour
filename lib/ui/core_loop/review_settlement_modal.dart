import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

import 'gear_shop/gear_shop_modal.dart';

/// 雙客戶動態審查跳分與 Near Miss 結算彈窗 (ReviewSettlementModal)
class ReviewSettlementModal extends ConsumerStatefulWidget {
  const ReviewSettlementModal({
    super.key,
    this.initialReport,
    this.onClose,
    this.onOpenGearShop,
    this.onRestartRun,
  });

  final ReviewReport? initialReport;
  final VoidCallback? onClose;
  final VoidCallback? onOpenGearShop;
  final VoidCallback? onRestartRun;

  @override
  ConsumerState<ReviewSettlementModal> createState() =>
      _ReviewSettlementModalState();
}

class _ReviewSettlementModalState extends ConsumerState<ReviewSettlementModal> {
  late ClientType _currentClientType;

  @override
  void initState() {
    super.initState();
    final state = ref.read(curatorRunControllerProvider);
    final initialType = widget.initialReport != null
        ? (widget.initialReport!.clientType == 'hypeInfluencer'
              ? ClientType.hypeInfluencer
              : ClientType.budgetWorker)
        : (state.latestReport != null
              ? (state.latestReport!.clientType == 'hypeInfluencer'
                    ? ClientType.hypeInfluencer
                    : ClientType.budgetWorker)
              : state.client.type);
    _currentClientType = initialType;
  }

  void _switchClient(ClientType type) {
    setState(() {
      _currentClientType = type;
    });
  }

  /// 本局指派客戶的報告。結算的去留與佣金一律以它為準；
  /// 客戶頁籤只是「另一位客戶會怎麼評」的唯讀對照，不得變成免費重骰。
  ReviewReport _assignedReport() {
    final assignedType = ref.watch(
      curatorRunControllerProvider.select((state) => state.client.type),
    );
    if (widget.initialReport != null &&
        widget.initialReport!.clientType == assignedType.name) {
      return widget.initialReport!;
    }
    return ref.watch(assignedReviewReportProvider);
  }

  ReviewReport _resolveReport() {
    if (widget.initialReport != null &&
        widget.initialReport!.clientType == _currentClientType.name) {
      return widget.initialReport!;
    }
    return ref.watch(comparisonReviewReportProvider(_currentClientType));
  }


  @override
  Widget build(BuildContext context) {
    final report = _resolveReport();
    final outcome = report.outcome;
    final runState = ref.watch(curatorRunControllerProvider);
    final isSettled = runState.phase == CuratorRunPhase.settled;
    // 行動區 (收佣金 / 返回微調) 依指派客戶的結果決定，與當前檢視的頁籤無關。
    final assignedReport = _assignedReport();
    final assignedOutcome = assignedReport.outcome;
    final isNearMissOrRejected = assignedOutcome == ReviewOutcome.nearMiss ||
        assignedOutcome == ReviewOutcome.rejected;

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
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // 雙客戶切換頁籤
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

              // 滿意度大看板與結果印章
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '滿意度評分',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${report.satisfaction}',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: _scoreColor(outcome),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildStamp(outcome),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),

                    // 客戶吐槽微文案
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '「${report.feedbackQuote}」',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ),

                    // Near Miss 反事實導購提示 (REQ-M4-04)
                    if (outcome == ReviewOutcome.nearMiss) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('near_miss_shop_tip'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDBA74), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _buildNearMissTip(
                                  clientType: report.clientType,
                                  equipment: runState.equipment,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9A3412),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // 細部評分擊穿
                    _buildSubscores(report),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 底部動作按鈕
              if (isSettled) ...[
                // 結算完成雙出口 (AC-M4-4.3)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('settlement_go_to_shop_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE65100),
                          side: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () {
                          if (widget.onOpenGearShop != null) {
                            widget.onOpenGearShop!();
                          } else {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => const GearShopModal(),
                            );
                          }
                        },
                        icon: const Icon(Icons.shopping_bag, size: 18),
                        label: const Text(
                          '🛒 前往黑市',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('settlement_restart_run_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(curatorRunControllerProvider.notifier)
                              .restartRun();
                          if (widget.onRestartRun != null) {
                            widget.onRestartRun!();
                          } else {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text(
                          '🔄 再來一局',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isNearMissOrRejected) ...[
                ElevatedButton(
                  key: const Key('btn_tweak_itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
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
                    if (widget.onRestartRun != null) {
                      widget.onRestartRun!();
                    } else {
                      Navigator.of(context).popUntil((r) => r.isFirst);
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
                        .acceptReview(acceptedReport: assignedReport);
                    if (widget.onClose != null) {
                      widget.onClose!();
                    }
                  },
                  child: Text(
                    '💰 收下佣金 (+${assignedReport.earnedCoins} 金幣)',
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
      final boredomThreshold = report.boredomThreshold;
      final maxBudgetScore = report.maxBudgetScore;
      final themeWeight = report.themeWeight;

      return Column(
        children: [
          _buildScoreRow('預算得分 (超支扣分)', '$budgetScore / $maxBudgetScore'),
          _buildScoreRow('主題契合得分', '$themeScore / $themeWeight'),
          if (report.hasPurityBonus)
            _buildScoreRow(
              '風格純度獎勵',
              report.purityBonus > 0
                  ? '+${report.purityBonus} 分 (純度達成)'
                  : '0 分 (純度失效)',
              isNegative: report.purityBonus <= 0,
            ),
          if (report.themeFatigue > 0)
            _buildScoreRow(
              '拉車疲勞扣分',
              '-${report.themeFatigue} 分',
              isNegative: true,
            ),
          if (boredomPenalty > 0)
            _buildScoreRow(
              '反無聊懲罰 (Hype<$boredomThreshold)',
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
          (report.subscores['spotlightMultiplier'] ?? 1.0).toDouble();
      final themeFactor =
          (report.subscores['themeFactor'] ?? 1.0).toDouble();
      final spotlightCount = report.spotlightCount;

      final String spotlightText;
      if (spotlightCount == 0 && spotlightMultiplier < 1.0) {
        spotlightText = '無絕景 (階梯 ${(spotlightMultiplier * 100).round()}%)';
      } else if (spotlightMultiplier < 1.0 && spotlightCount > 0) {
        spotlightText = '絕景 $spotlightCount/4 張 (階梯 ${(spotlightMultiplier * 100).round()}%)';
      } else {
        spotlightText = '絕景已達標 (階梯 ${(spotlightMultiplier * 100).round()}%)';
      }

      return Column(
        children: [
          _buildScoreRow('爆點熱度折算', '$effectiveHype 點'),
          if (report.adventureCombo > 0)
            _buildScoreRow(
              '冒險連段加成',
              '+${report.adventureCombo} Hype',
            ),
          if (report.hypeFatigue > 0)
            _buildScoreRow(
              '拉車脫妝懲罰',
              '-${report.hypeFatigue} Hype',
              isNegative: true,
            ),
          if (report.themeFatigue > 0)
            _buildScoreRow(
              '拉車疲勞扣分',
              '-${report.themeFatigue} 分',
              isNegative: true,
            ),
          if (report.hasPurityBonus)
            _buildScoreRow(
              '風格純度獎勵',
              report.purityBonus > 0
                  ? '+${report.purityBonus} 分 (純度達成)'
                  : '0 分 (純度失效)',
              isNegative: report.purityBonus <= 0,
            ),
          _buildScoreRow('主題加權係數', '${(themeFactor * 100).round()} %'),
          if (spotlightMultiplier < 1.0)
            _buildScoreRow('絕景打折提醒', spotlightText, isNegative: true),
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

  String _buildNearMissTip({
    required String clientType,
    required EquipmentInventory equipment,
  }) {
    if (clientType == 'hypeInfluencer') {
      final camLv = equipment.camera.level;
      final nextLv = camLv < 3 ? camLv + 1 : 3;
      return '要是黃昏再震撼一點就好了... 📸 相機目前 Lv.$camLv，升至 Lv.$nextLv 可提升高潮加成！';
    } else {
      final shoeLv = equipment.sneakers.level;
      final nextLv = shoeLv < 3 ? shoeLv + 1 : 3;
      return '要是體力能再多走兩步就好了... 👟 球鞋目前 Lv.$shoeLv，升至 Lv.$nextLv 可提升 HP 上限！';
    }
  }
}
