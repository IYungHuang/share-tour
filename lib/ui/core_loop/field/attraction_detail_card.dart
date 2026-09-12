import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_providers.dart';

import 'gathering_replace_bottom_sheet.dart';

/// 點選景點時在畫面底部彈出的 JRPG 像素風格詳細資訊與取材卡 (REQ-M3-02, REQ-M3-03, G4)
///
/// 內建 120Hz 渲染隔離：距離文字與按鈕狀態由獨立細粒度 Selector 驅動，
/// 避免小人走動時引發全卡全量 Rebuild。
class AttractionDetailCard extends ConsumerWidget {
  const AttractionDetailCard({
    super.key,
    required this.selectedAttraction,
    this.onFocusCamera,
    this.onGathered,
  });

  final ValueNotifier<DistrictAttraction?> selectedAttraction;
  final VoidCallback? onFocusCamera;
  final void Function(TravelMaterial material, int deltaHp)? onGathered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<DistrictAttraction?>(
      valueListenable: selectedAttraction,
      builder: (context, attraction, _) {
        if (attraction == null) return const SizedBox.shrink();

        final resolver = ref.watch(poiMaterialResolverProvider);
        TravelMaterial? material;
        try {
          material = resolver.resolveMaterialFor(attraction.id);
        } catch (_) {}

        final currentPhilosophy = ref.watch(
          curatorRunControllerProvider.select((s) => s.philosophy),
        );
        final bool isPhilosophyMatch = material != null &&
            material.tags.any((t) => currentPhilosophy.preferredTags.contains(t));

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 168, left: 16, right: 16),
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 標題與關閉按鈕
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              _iconForAttraction(attraction.title, attraction.category),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                attraction.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => selectedAttraction.value = null,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1.5),
                            color: Colors.grey.shade200,
                          ),
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 2. 行政區與評價資訊
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0834B),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Text(
                          attraction.districtName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          Text(
                            '${attraction.rating.toStringAsFixed(1)} ',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '(${attraction.reviewCount}+ 評價)',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      if (isPhilosophyMatch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          color: const Color(0xFFFAF5FF),
                          child: const Text(
                            '🎯 契合哲學',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF805AD5),
                            ),
                          ),
                        ),
                      if (material != null && material.hasFatigueRisk)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          color: const Color(0xFFFFF5F5),
                          child: const Text(
                            '[💀 拉車隱患]',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53E3E),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // 3. 描述
                  Text(
                    attraction.description,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),

                  const SizedBox(height: 6),

                  // 4. 代價與收穫預覽 (REQ-M3-02.3 資訊透明化)
                  if (material != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '⚡ 消耗: -${gatheringHpCost(material)} HP',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53E3E),
                            ),
                          ),
                          Text(
                            '💰 花費: ¥${material.cost}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD69E2E),
                            ),
                          ),
                          Text(
                            '⭐ 風險: ${material.riskLevel}★',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // 5. 底部操作列 (距離文字 + 視野聚焦 + 取材按鈕)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 距離文字 (細粒度 Selector 隔離 120Hz)
                      _AttractionDistanceBadge(attraction: attraction),

                      Row(
                        children: [
                          if (onFocusCamera != null)
                            GestureDetector(
                              onTap: onFocusCamera,
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: const Text(
                                  '聚焦',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          // 6 態取材按鈕 (隔離 120Hz)
                          _AttractionGatherActionButton(
                            attraction: attraction,
                            material: material,
                            onGathered: onGathered,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 獨立距離徽章 (僅在小人像素位移時局部重繪，隔絕大卡 Rebuild)
class _AttractionDistanceBadge extends ConsumerWidget {
  const _AttractionDistanceBadge({required this.attraction});

  final DistrictAttraction attraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerPixel = ref.watch(
      locationControllerProvider.select((s) => s.renderedPixel),
    );
    final manifest = ref.watch(mapManifestProvider);
    final distPx = (attraction.pixel - playerPixel).length;
    final String distText;
    if (attraction.triggerRadiusPixels != null) {
      distText = '${distPx.toStringAsFixed(0)} px';
    } else {
      final distM = distPx * manifest.metersPerPixelAt(playerPixel);
      distText = distM >= 1000
          ? '${(distM / 1000).toStringAsFixed(1)} km'
          : '${distM.toStringAsFixed(0)} m';
    }
    final inRange = attraction.triggerRadiusPixels != null
        ? distPx <= attraction.triggerRadiusPixels!
        : (distPx * manifest.metersPerPixelAt(playerPixel)) <=
            attraction.triggerRadiusMeters;

    return Row(
      children: [
        Icon(
          inRange ? Icons.camera_alt : Icons.directions_walk,
          size: 14,
          color: inRange ? const Color(0xFF15803D) : Colors.black87,
        ),
        const SizedBox(width: 4),
        Text(
          '距玩家: $distText',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: inRange ? const Color(0xFF15803D) : Colors.black,
          ),
        ),
        if (inRange) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              border: Border.all(color: const Color(0xFF16A34A), width: 1),
            ),
            child: const Text(
              '✨ 可取景',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _iconForAttraction(String title, AttractionCategory category) {
  if (title.contains('車') || title.contains('鐵') || title.contains('電車')) return '🚂';
  if (title.contains('竹林') || title.contains('螢火') || title.contains('高野川')) return '🎋';
  if (title.contains('鳥居') || title.contains('寺') || title.contains('宮') || title.contains('門') || title.contains('塔') || title.contains('堂')) return '⛩️';
  if (title.contains('山')) return '⛰️';
  if (title.contains('貓')) return '🐱';
  if (title.contains('拉麵') || title.contains('麵') || title.contains('市場') || title.contains('食堂')) return '🍜';
  if (title.contains('酒') || title.contains('立飲') || title.contains('立吞') || title.contains('割烹')) return '🏮';
  if (title.contains('咖啡') || title.contains('黑膠') || title.contains('手沖') || title.contains('星巴克') || title.contains('喫茶')) return '☕';
  if (title.contains('自販機')) return '🥤';

  return switch (category) {
    AttractionCategory.landmark => '⛩️',
    AttractionCategory.culture => '📜',
    AttractionCategory.nature => '🌲',
    AttractionCategory.food => '🍜',
    AttractionCategory.recreation => '🎡',
    AttractionCategory.sightseeing => '📷',
  };
}

/// 獨立 6 態取材按鈕 (依 GatheringEligibility 驅動)
class _AttractionGatherActionButton extends ConsumerWidget {
  const _AttractionGatherActionButton({
    required this.attraction,
    required this.material,
    this.onGathered,
  });

  final DistrictAttraction attraction;
  final TravelMaterial? material;
  final void Function(TravelMaterial material, int deltaHp)? onGathered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibility = ref.watch(attractionEligibilityProvider(attraction));
    final controller = ref.read(curatorRunControllerProvider.notifier);

    final outOfRangeLabel = attraction.triggerRadiusPixels != null
        ? '太遠 (需<${attraction.triggerRadiusPixels!.toStringAsFixed(0)}px)'
        : '太遠 (需<${attraction.triggerRadiusMeters.toStringAsFixed(0)}m)';

    final (label, bgColor, isClickable) = switch (eligibility) {
      GatheringEligibility.ready => ('📸 踩線取材', const Color(0xFF48BB78), true),
      GatheringEligibility.inventoryFull => ('👝 踩線換牌', const Color(0xFFED8936), true),
      GatheringEligibility.alreadyGathered => ('✅ 本日已踩線', Colors.grey.shade400, false),
      GatheringEligibility.outOfRange => (outOfRangeLabel, Colors.grey.shade300, false),
      GatheringEligibility.exhausted => ('💤 體力透支', Colors.grey.shade400, false),
      GatheringEligibility.unavailable => ('無可用素材', Colors.grey.shade300, false),
    };

    return GestureDetector(
      onTap: !isClickable
          ? null
          : () async {
              final playerPixel = ref.read(
                locationControllerProvider.select((s) => s.renderedPixel),
              );
              final manifest = ref.read(mapManifestProvider);
              final resolver = ref.read(poiMaterialResolverProvider);
              final runState = ref.read(curatorRunControllerProvider);
              final nearest = nearestGatherablePoi(
                attractions: manifest.districtAttractions,
                run: runState,
                playerPixel: playerPixel,
                manifest: manifest,
                resolver: resolver,
              );

              final effectiveAttraction = nearest?.attraction ?? attraction;
              final effectiveMaterial = nearest?.material ?? material;

              if (eligibility == GatheringEligibility.ready) {
                if (effectiveMaterial != null) {
                  final result = controller.gatherPoi(
                    effectiveAttraction.id,
                    manifest: manifest,
                    playerPixel: playerPixel,
                  );
                  onGathered?.call(result.material, result.hpSpent);
                }
              } else if (eligibility == GatheringEligibility.inventoryFull) {
                if (effectiveMaterial != null) {
                  final currentMaterials = ref.read(
                    curatorRunControllerProvider.select((s) => s.inventory.materials),
                  );
                  final dropIndex = await GatheringReplaceBottomSheet.show(
                    context: context,
                    newMaterial: effectiveMaterial,
                    currentMaterials: currentMaterials,
                  );
                  if (dropIndex != null && context.mounted) {
                    final result = controller.replaceGatheredPoi(
                      poiId: effectiveAttraction.id,
                      dropIndex: dropIndex,
                      manifest: manifest,
                      playerPixel: playerPixel,
                      expectedPoiId: effectiveAttraction.id,
                    );
                    if (result != null) {
                      onGathered?.call(result.material, result.hpSpent);
                    }
                  }
                }
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: isClickable
              ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isClickable ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
