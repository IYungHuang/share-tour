import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/core_loop/models/shutter_difficulty.dart';
import '../../../domain/core_loop/models/travel_philosophy.dart';
import '../../../domain/core_loop/review/client_spec.dart';
import '../../../state/core_loop/curator_run_providers.dart';

/// 難度顯示名稱（純呈現層，REQ-M5-05.1：難度是唯一的 QTE 旋鈕）。
const Map<ShutterDifficulty, (String, String)> _kDifficultyPresentation = {
  ShutterDifficulty.tourist: ('觀光客', '零失手，慢'),
  ShutterDifficulty.photographer: ('攝影師', '中等窗寬'),
  ShutterDifficulty.decisiveMoment: ('決定性瞬間', '窄窗，高賭注'),
};

/// 阿導行前委託底抽屜彈窗 (Task M5, 360dp 防破版)
class CuratorBriefingModal extends ConsumerWidget {
  const CuratorBriefingModal({
    super.key,
    this.onOpenGearShop,
    this.onDepart,
  });

  final VoidCallback? onOpenGearShop;
  final VoidCallback? onDepart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curatorRunControllerProvider);
    final client = state.client;
    final choices = state.philosophyChoices;
    final selectedChoice = state.selectedPhilosophy;
    final canDepart = state.canDepart;
    final nextRerollCost = state.nextRerollCost;
    final canReroll = state.canReroll;
    final selectedDifficulty = state.shutterDifficulty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
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

            // 標題列 (使用 Expanded 防範窄螢幕溢出)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Color(0xFFFFB300), size: 20),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '📋 阿導行前委託 (Briefing)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 局外持有金幣標籤
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
                    ),
                    child: Text(
                      '🪙 ${state.equipment.coins}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 可滾動內容區 (客戶卡 + 3 張垂直哲學卡)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 今日委託客戶卡
                    _buildClientCard(client),

                    const SizedBox(height: 12),
                    const Text(
                      '🎲 選擇旅行哲學 (三選一)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 垂直 3 張哲學卡
                    for (final choice in choices) ...[
                      _buildPhilosophyCard(
                        choice: choice,
                        isSelected: selectedChoice == choice,
                        onTap: () {
                          ref
                              .read(curatorRunControllerProvider.notifier)
                              .selectPhilosophy(choice);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 4),
                    const Text(
                      '📸 選擇快門難度',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final difficulty in ShutterDifficulty.values) ...[
                          Expanded(
                            child: _buildDifficultyPill(
                              difficulty: difficulty,
                              isSelected: selectedDifficulty == difficulty,
                              onTap: () => ref
                                  .read(curatorRunControllerProvider.notifier)
                                  .selectDifficulty(difficulty),
                            ),
                          ),
                          if (difficulty != ShutterDifficulty.values.last)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 底部雙層控制列 (徹底杜絕 360dp RenderFlex overflow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 上層：次要操作 (重擲 + 裝備舖)
                  Row(
                    children: [
                      // 靈感重擲按鈕
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('briefing_reroll_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFD700),
                            side: const BorderSide(color: Color(0xFFFFD700)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: canReroll
                              ? () {
                                  ref
                                      .read(curatorRunControllerProvider.notifier)
                                      .rerollPhilosophies();
                                }
                              : null,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(
                            nextRerollCost == 0 ? '🎲 換一批 (首局免費)' : '🎲 換一批 (100幣)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 黑市裝備舖入口
                      OutlinedButton.icon(
                        key: const Key('briefing_gear_shop_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF9800),
                          side: const BorderSide(color: Color(0xFFFF9800)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onOpenGearShop,
                        icon: const Icon(Icons.shopping_bag, size: 16),
                        label: const Text(
                          '🛒 黑市裝備',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 下層：主要行動 (出發踩線)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('briefing_depart_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        disabledBackgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: canDepart
                          ? () {
                              ref
                                  .read(curatorRunControllerProvider.notifier)
                                  .departToFieldTrip();
                              if (onDepart != null) {
                                onDepart!();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            }
                          : null,
                      icon: const Icon(Icons.flight_takeoff, size: 20),
                      label: Text(
                        canDepart ? '🚀 出發踩線！' : '請先選定一項哲學',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildClientCard(ClientSpec client) {
    final isWorker = client.type == ClientType.budgetWorker;
    final accentColor = isWorker ? const Color(0xFF42A5F5) : const Color(0xFFEC407A);
    final iconData = isWorker ? Icons.work_outline : Icons.camera_alt_outlined;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '委託客戶：${client.personaName}（${client.displayName}）',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '預算: \$${client.targetBudget}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            client.description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPill({
    required ShutterDifficulty difficulty,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final (label, hint) = _kDifficultyPresentation[difficulty]!;
    final borderColor = isSelected ? const Color(0xFF42A5F5) : const Color(0xFF333333);
    final bgColor = isSelected ? const Color(0xFF1E2A38) : const Color(0xFF222222);

    return InkWell(
      key: Key('difficulty_pill_${difficulty.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF42A5F5) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhilosophyCard({
    required TravelPhilosophy choice,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor =
        isSelected ? const Color(0xFFFFD700) : const Color(0xFF333333);
    final bgColor =
        isSelected ? const Color(0xFF2A281E) : const Color(0xFF222222);

    return InkWell(
      key: Key('philosophy_card_${choice.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    choice.displayName,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFFFFD700),
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '「${choice.quote}」',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            // 加扣分標籤
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in choice.preferredTags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$tag +50%',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                for (final tag in choice.repelledTags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$tag 罰分',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
