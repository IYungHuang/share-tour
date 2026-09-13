import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_providers.dart';

import '../field/shutter_qte_overlay.dart';
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
    this.onSuspendCameraForQte,
    this.onResumeCameraFromQte,
  });

  final ValueNotifier<DistrictAttraction?> selectedAttraction;
  final VoidCallback? onFocusCamera;
  final void Function(TravelMaterial material, int deltaHp)? onGathered;

  /// QTE 開始/結束時呼叫，暫停/恢復相機回歸計時（REQ-M5-10.7）。薄轉接
  /// ——不在此處直接依賴 `game/` 型別，維持 ui/ 與 game/ 之間僅靠
  /// `main.dart` 接線，不新增跨層 import。
  final VoidCallback? onSuspendCameraForQte;
  final VoidCallback? onResumeCameraFromQte;

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
                        child: Text(
                          attraction.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
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
                  Row(
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
                      const SizedBox(width: 8),
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
                      if (isPhilosophyMatch) ...[
                        const SizedBox(width: 6),
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
                      ],
                      if (material != null && material.hasFatigueRisk) ...[
                        const SizedBox(width: 6),
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
                            onSuspendCameraForQte: onSuspendCameraForQte,
                            onResumeCameraFromQte: onResumeCameraFromQte,
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

    return Row(
      children: [
        const Icon(Icons.directions_walk, size: 14, color: Colors.black87),
        const SizedBox(width: 4),
        Text(
          '距玩家: $distText',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 獨立 6 態取材按鈕 (依 GatheringEligibility 驅動)
class _AttractionGatherActionButton extends ConsumerWidget {
  const _AttractionGatherActionButton({
    required this.attraction,
    required this.material,
    this.onGathered,
    this.onSuspendCameraForQte,
    this.onResumeCameraFromQte,
  });

  final DistrictAttraction attraction;
  final TravelMaterial? material;
  final void Function(TravelMaterial material, int deltaHp)? onGathered;
  final VoidCallback? onSuspendCameraForQte;
  final VoidCallback? onResumeCameraFromQte;

  /// 開啟 QTE 覆蓋層，等判定就緒後回傳結果（REQ-M5-01、G12 產物）。
  /// 中斷（`onInterrupted`）額外呼叫 `controller.recordShutterInterruption()`
  /// 疊加本局 ×0.9（REQ-M5-04.2），但仍照 `onResolved` 給出的三態走正常
  /// 取材流程——中斷不是跳過，是照算後打折扣。
  Future<ShotTier?> _runQte({
    required BuildContext context,
    required WidgetRef ref,
    required bool isSpotlight,
  }) {
    final difficulty = ref.read(
      curatorRunControllerProvider.select((s) => s.shutterDifficulty),
    );
    final controller = ref.read(curatorRunControllerProvider.notifier);
    onSuspendCameraForQte?.call();

    return showGeneralDialog<ShotTier>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (dialogContext, _, _) => ShutterQteOverlay(
        difficulty: difficulty,
        isSpotlight: isSpotlight,
        onResolved: (result) => Navigator.of(dialogContext).pop(result),
        onInterrupted: controller.recordShutterInterruption,
      ),
    ).whenComplete(() => onResumeCameraFromQte?.call());
  }

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
                  // 鎖定當下目標（REQ-M5-07.1）：QTE 判定期間玩家可能移動，
                  // 判定完成後以此 ID 為準，變了就整次取消，不做任何狀態變更。
                  final lockedPoiId = effectiveAttraction.id;
                  final shotTier = await _runQte(
                    context: context,
                    ref: ref,
                    isSpotlight: effectiveMaterial.isSpotlight,
                  );
                  if (shotTier == null || !context.mounted) return;
                  final freshPlayerPixel = ref.read(
                    locationControllerProvider.select((s) => s.renderedPixel),
                  );
                  try {
                    final result = controller.gatherPoi(
                      lockedPoiId,
                      manifest: manifest,
                      playerPixel: freshPlayerPixel,
                      expectedPoiId: lockedPoiId,
                      shotTier: shotTier,
                    );
                    onGathered?.call(result.material, result.hpSpent);
                  } on PoiTargetChangedException {
                    // 目標已變更，靜默取消——QTE 判定前未扣過任何資源，
                    // 沒有狀態需要復原（REQ-M5-07.1）。
                  }
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
                  // 先抽屜、通過後才進 QTE（REQ-M5-07.2）——選「放棄」
                  // (dropIndex == null) 就不進 QTE，不扣資源。
                  if (dropIndex != null && context.mounted) {
                    final lockedPoiId = effectiveAttraction.id;
                    final shotTier = await _runQte(
                      context: context,
                      ref: ref,
                      isSpotlight: effectiveMaterial.isSpotlight,
                    );
                    if (shotTier == null || !context.mounted) return;
                    final freshPlayerPixel = ref.read(
                      locationControllerProvider.select((s) => s.renderedPixel),
                    );
                    final result = controller.replaceGatheredPoi(
                      poiId: lockedPoiId,
                      dropIndex: dropIndex,
                      manifest: manifest,
                      playerPixel: freshPlayerPixel,
                      expectedPoiId: lockedPoiId,
                      shotTier: shotTier,
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
