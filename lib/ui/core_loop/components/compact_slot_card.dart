import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 四幕劇緊湊槽位卡片組件 (76~95dp 自適應寬度，防溢出設計)
class CompactSlotCard extends ConsumerWidget {
  const CompactSlotCard({super.key, required this.slotIndex, this.onTap});

  final int slotIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 細粒度監聽該槽位之素材
    final material = ref.watch(
      curatorRunControllerProvider.select((s) => s.itinerary.slots[slotIndex]),
    );
    // 監聽相機倍率 (Slot 2 專用)
    final cameraMultiplier = ref.watch(
      curatorRunControllerProvider.select(
        (s) => s.equipment.camera.cameraMultiplier,
      ),
    );

    final (timeLabel, defaultHint, gradientColors) = switch (slotIndex) {
      0 => (
        '06:00 晨曦',
        '#散步+5',
        [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
      ),
      1 => (
        '11:00 午後',
        '#美食+5',
        [const Color(0xFFE1F5FE), const Color(0xFFB3E5FC)],
      ),
      2 => (
        '16:00 黃昏',
        '相機焦點',
        [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)],
      ),
      _ => (
        '19:00 深夜',
        '#深夜收尾',
        [const Color(0xFFE8EAF6), const Color(0xFFC5CAE9)],
      ),
    };

    return Expanded(
      child: GestureDetector(
        key: Key('slot_card_$slotIndex'),
        onTap: onTap,
        child: Container(
          height: 110,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: slotIndex == 2 ? const Color(0xFFD97706) : Colors.black,
              width: slotIndex == 2 ? 2.5 : 2.0,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, offset: Offset(2, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 時段標題
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Slot 2 黃昏相機倍率膠囊
              if (slotIndex == 2)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '📷 ${cameraMultiplier.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                  ),
                ),

              // 素材內容或未放置提示
              Expanded(
                child: material == null
                    ? _buildEmptyContent(defaultHint)
                    : _buildFilledContent(material),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContent(String hint) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black38, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 14, color: Colors.black54),
            Text(
              hint,
              style: const TextStyle(fontSize: 8.5, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledContent(TravelMaterial material) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 素材名稱
        Row(
          children: [
            if (material.isSpotlight)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Text('⭐', style: TextStyle(fontSize: 9)),
              ),
            Expanded(
              child: Text(
                material.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // 數值藥丸 (熱度與主題)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🔥${material.hypeValue}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
            Text(
              '🎯${material.themeValue}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
