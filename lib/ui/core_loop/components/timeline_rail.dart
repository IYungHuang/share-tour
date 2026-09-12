import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

import 'compact_slot_card.dart';

/// 四幕劇時間線軌道與連動光軌組件 (TimelineRail)
class TimelineRail extends ConsumerWidget {
  const TimelineRail({super.key, this.onSlotTap});

  final void Function(int slotIndex)? onSlotTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 硬約束：編排期因果符號一律只從 itineraryCausalReportProvider 的 facts 渲染
    final causalReport = ref.watch(itineraryCausalReportProvider);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 頂部連動狀態提示軌 (Synergy Rail)
            _buildSynergyRail(causalReport.facts),
            const SizedBox(height: 6),

            // 4 槽位橫向軌道 (自適應彈性排版，無溢出)
            Row(
              children: [
                CompactSlotCard(
                  slotIndex: 0,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(0)
                      : _defaultSlotTap(ref, 0),
                ),
                CompactSlotCard(
                  slotIndex: 1,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(1)
                      : _defaultSlotTap(ref, 1),
                ),
                CompactSlotCard(
                  slotIndex: 2,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(2)
                      : _defaultSlotTap(ref, 2),
                ),
                CompactSlotCard(
                  slotIndex: 3,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(3)
                      : _defaultSlotTap(ref, 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _defaultSlotTap(WidgetRef ref, int index) {
    ref
        .read(curatorRunControllerProvider.notifier)
        .removeMaterialFromSlot(index);
  }

  Widget _buildSynergyRail(List<CausalFact> facts) {
    final indicators = <Widget>[];

    // 檢查相鄰配對事實在 (0,1), (1,2), (2,3) 軌道上的投影
    final pairFacts = facts.where((f) => f.pairIndices != null).toList();

    for (final fact in pairFacts) {
      final (i, next) = fact.pairIndices!;
      final key = switch (fact.reasonCode) {
        'fatigue_spike' => Key('fatigue_warning_${i}_$next'),
        'fatigue_hype_penalty' => Key('fatigue_hype_warning_${i}_$next'),
        'tag_synergy' => Key('combo_indicator_${i}_$next'),
        'chaotic_combo' => Key('chaotic_combo_indicator_${i}_$next'),
        _ => Key('rail_indicator_${fact.reasonCode}_${i}_$next'),
      };

      final (bgColor, borderColor, textColor) = switch (fact.reasonCode) {
        'fatigue_spike' => (
          const Color(0xFFDC2626),
          Colors.redAccent,
          Colors.white,
        ),
        'fatigue_hype_penalty' => (
          const Color(0xFFBE185D),
          Colors.pinkAccent,
          Colors.white,
        ),
        'rhythm_complement' => (
          const Color(0xFF0284C7),
          Colors.lightBlueAccent,
          Colors.white,
        ),
        'chaotic_combo' => (
          const Color(0xFF7C3AED),
          Colors.purpleAccent,
          Colors.white,
        ),
        'tag_synergy' => (
          const Color(0xFFF59E0B),
          Colors.amberAccent,
          Colors.black,
        ),
        _ => (
          const Color(0xFF475569),
          Colors.blueGrey,
          Colors.white,
        ),
      };

      indicators.add(
        Container(
          key: key,
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fact.reasonCode == 'tag_synergy') ...[
                const Icon(Icons.link, size: 11, color: Colors.black),
                const SizedBox(width: 2),
              ],
              Text(
                '$i-$next ${fact.sourceSignifier}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (indicators.isEmpty) {
      return const SizedBox(
        height: 16,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '四幕行程軌道 · 點擊槽位可卸下素材',
            style: TextStyle(fontSize: 9, color: Colors.white54),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: indicators),
    );
  }
}
