import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 阿導腰包素材抽屜組件 (WaistBagDrawer)
class WaistBagDrawer extends ConsumerWidget {
  const WaistBagDrawer({super.key, this.onSelectMaterial});

  final void Function(TravelMaterial material)? onSelectMaterial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(
      curatorRunControllerProvider.select((s) => s.inventory),
    );

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 抽屜頂部工具列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '阿導腰包 (${inventory.count}/${inventory.capacity})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  key: const Key('draw_sample_material_button'),
                  onTap: () => ref
                      .read(curatorRunControllerProvider.notifier)
                      .drawSampleMaterial(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🎲 [測試] 採集素材',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 素材清單
            Expanded(
              child: inventory.materials.isEmpty
                  ? const Center(
                      child: Text(
                        '腰包空空如也，點擊右上方「採集素材」按鈕探索！',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: inventory.materials.length,
                      itemBuilder: (context, index) {
                        final material = inventory.materials[index];
                        return _WaistBagCardItem(
                          material: material,
                          onTap: () {
                            if (onSelectMaterial != null) {
                              onSelectMaterial!(material);
                            } else {
                              _defaultPlaceMaterial(ref, material);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _defaultPlaceMaterial(WidgetRef ref, TravelMaterial material) {
    final slots = ref.read(curatorRunControllerProvider).itinerary.slots;
    final emptyIndex = slots.indexWhere((s) => s == null);
    if (emptyIndex != -1) {
      ref
          .read(curatorRunControllerProvider.notifier)
          .placeMaterialInSlot(emptyIndex, material);
    }
  }
}

/// 細粒度監聽入槽狀態之獨立卡片項目 (避免抽屜全量重繪)
class _WaistBagCardItem extends ConsumerWidget {
  const _WaistBagCardItem({required this.material, required this.onTap});

  final TravelMaterial material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 家族選擇器：僅當該素材入槽狀態改變時局部重繪
    final slottedIndex = ref.watch(
      curatorRunControllerProvider.select(
        (s) => s.itinerary.slots.indexWhere((slot) => slot?.id == material.id),
      ),
    );

    final isSlotted = slottedIndex != -1;

    return GestureDetector(
      key: Key('bag_card_${material.id}'),
      onTap: isSlotted ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black12, offset: Offset(1, 1)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${material.isSpotlight ? '⭐ ' : ''}${material.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '¥${material.cost}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '🔥${material.hypeValue}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🎯${material.themeValue}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '危險: ${'★' * material.riskLevel}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      material.tags.join(' '),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 入槽遮罩
            if (isSlotted)
              Positioned.fill(
                child: Container(
                  key: Key('in_use_overlay_${material.id}'),
                  color: Colors.white.withAlpha(210),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '已排入 Slot $slottedIndex',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
