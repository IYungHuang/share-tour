import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/core_loop/models/meta_equipment.dart';
import '../../../state/core_loop/curator_run_providers.dart';

/// 黑市裝備舖彈窗 (Task M6, 360dp 防破版)
class GearShopModal extends ConsumerWidget {
  const GearShopModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curatorRunControllerProvider);
    final equipment = state.equipment;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 頂部把手
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 標題與金幣列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag, color: Color(0xFFFF9800), size: 20),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '🛒 黑市裝備舖',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 金幣指標
                  Container(
                    key: const Key('gear_shop_coins_indicator'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.0),
                    ),
                    child: Text(
                      '🪙 金幣: ${equipment.coins}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 關閉按鈕
                  IconButton(
                    key: const Key('gear_shop_close_button'),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            // 3 張裝備卡垂直列表 (可滾動防破版)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _buildGearCard(
                      ref: ref,
                      keyName: 'gear_card_sneakers',
                      buttonKeyName: 'upgrade_button_sneakers',
                      type: EquipmentType.sneakers,
                      item: equipment.sneakers,
                      currentCoins: equipment.coins,
                      icon: Icons.directions_walk,
                      name: '👟 暴走球鞋',
                      desc: '當前 HP 上限: ${equipment.sneakers.maxHp}',
                      nextDesc: equipment.sneakers.level == 1
                          ? '升級後: 125 HP'
                          : (equipment.sneakers.level == 2 ? '升級後: 155 HP' : ''),
                    ),
                    const SizedBox(height: 10),
                    _buildGearCard(
                      ref: ref,
                      keyName: 'gear_card_camera',
                      buttonKeyName: 'upgrade_button_camera',
                      type: EquipmentType.camera,
                      item: equipment.camera,
                      currentCoins: equipment.coins,
                      icon: Icons.camera_alt,
                      name: '📸 廣角相機',
                      desc: '黃昏高潮加成: ${equipment.camera.cameraMultiplier}x',
                      nextDesc: equipment.camera.level == 1
                          ? '升級後: 1.8x'
                          : (equipment.camera.level == 2 ? '升級後: 2.2x' : ''),
                    ),
                    const SizedBox(height: 10),
                    _buildGearCard(
                      ref: ref,
                      keyName: 'gear_card_waistBag',
                      buttonKeyName: 'upgrade_button_waistBag',
                      type: EquipmentType.waistBag,
                      item: equipment.waistBag,
                      currentCoins: equipment.coins,
                      icon: Icons.shopping_basket,
                      name: '🎒 多功能腰包',
                      desc: '素材容量上限: ${equipment.waistBag.capacity} 格',
                      nextDesc: equipment.waistBag.level == 1
                          ? '升級後: 8 格'
                          : (equipment.waistBag.level == 2 ? '升級後: 10 格' : ''),
                    ),
                  ],
                ),
              ),
            ),

            // 底部說明提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white54, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '💡 裝備升級立即保存，新數值於下一局出發時生效！',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGearCard({
    required WidgetRef ref,
    required String keyName,
    required String buttonKeyName,
    required EquipmentType type,
    required EquipmentItem item,
    required int currentCoins,
    required IconData icon,
    required String name,
    required String desc,
    required String nextDesc,
  }) {
    final isMax = item.isMaxLevel;
    final cost = item.nextUpgradeCost;
    final canAfford = item.canAffordUpgrade(currentCoins);

    return Container(
      key: Key(keyName),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMax ? const Color(0xFFFFD700) : const Color(0xFF383838),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // 裝備圖示
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isMax ? const Color(0xFF3E3618) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMax ? const Color(0xFFFFD700) : Colors.grey[700]!,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isMax ? const Color(0xFFFFD700) : const Color(0xFFFF9800),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // 裝備說明
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Lv. ${item.level}',
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (!isMax && nextDesc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    nextDesc,
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 升級按鈕
          ElevatedButton(
            key: Key(buttonKeyName),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMax
                  ? const Color(0xFFFFD700)
                  : (canAfford ? const Color(0xFFFF9800) : Colors.grey[800]),
              disabledBackgroundColor: isMax ? const Color(0xFFFFD700) : Colors.grey[800],
              foregroundColor: isMax ? Colors.black : Colors.white,
              disabledForegroundColor: isMax ? Colors.black : Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: (!isMax && canAfford)
                ? () {
                    ref
                        .read(curatorRunControllerProvider.notifier)
                        .upgradeEquipment(type);
                  }
                : null,
            child: Text(
              isMax ? 'MAX' : (canAfford ? '升級 ($cost幣)' : '需 $cost幣'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
