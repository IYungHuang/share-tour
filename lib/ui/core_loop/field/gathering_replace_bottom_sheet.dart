import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';

/// 腰包滿額現場換牌純選擇器抽屜 (REQ-M3-03, G4)
///
/// 點選既有卡片時回傳該卡片 index (0~5)，點選放棄或關閉時回傳 null。
/// 純選擇器模式，不直接突變 Controller 狀態，保證 Modal 完全 Pop 後再處理後續轉場。
class GatheringReplaceBottomSheet extends StatelessWidget {
  const GatheringReplaceBottomSheet({
    super.key,
    required this.newMaterial,
    required this.currentMaterials,
  });

  final TravelMaterial newMaterial;
  final List<TravelMaterial> currentMaterials;

  static Future<int?> show({
    required BuildContext context,
    required TravelMaterial newMaterial,
    required List<TravelMaterial> currentMaterials,
  }) {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GatheringReplaceBottomSheet(
        newMaterial: newMaterial,
        currentMaterials: currentMaterials,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2430),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Colors.amber, width: 2),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 6),
                    Text(
                      '👝 腰包客滿！選擇一張舊卡替換',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 新獲得素材預覽
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748),
                border: Border.all(color: const Color(0xFF48BB78), width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('✨ 新素材：', style: TextStyle(color: Color(0xFF48BB78), fontSize: 11, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      '${newMaterial.name} (${newMaterial.tags.join(' ')})',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Text('點選欲捨棄之舊卡：', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 6),

            // 腰包現存素材清單 (最多 6~10 張)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: currentMaterials.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = currentMaterials[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A202C),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.tags.join(' '),
                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53E3E),
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: const Text(
                              '捨棄此卡',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // 放棄按鈕
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A5568),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('放棄此新素材 (保留現狀)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
