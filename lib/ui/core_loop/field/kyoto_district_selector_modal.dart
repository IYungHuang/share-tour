import 'package:flutter/material.dart';
import '../../../game/map_module/manifests/kyoto_district_street_manifest.dart';

/// 京都五大分區街區漫步選擇彈窗
///
/// 讓玩家從京都宏觀盆地全覽層自由挑選想進入的特定中觀街區散步道。
class KyotoDistrictSelectorModal extends StatelessWidget {
  const KyotoDistrictSelectorModal({
    super.key,
    required this.onSelectDistrict,
    this.activeDistrictCode,
  });

  final void Function(KyotoDistrictType district) onSelectDistrict;
  final String? activeDistrictCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border.all(color: const Color(0xFFF59E0B), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 標題欄
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text(
                        '🗺️',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '京都街區漫步指南',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFDE68A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '選擇深入體驗的中觀散步道（1km × 1km 探索層次）',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 12),
              // 五大分區選項列表
              ...KyotoDistrictType.values.map((district) {
                final isActive = activeDistrictCode == district.code ||
                    (activeDistrictCode != null &&
                        activeDistrictCode!.contains(district.code));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    key: Key('district_select_${district.code}'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectDistrict(district);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFF1E293B),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF60A5FA)
                              : Colors.white12,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              district.badgeIcon,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      district.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '${district.spotCount} 處景點',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  district.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
