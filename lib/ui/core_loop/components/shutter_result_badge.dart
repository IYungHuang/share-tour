import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';

/// 三態徽章共用元件（REQ-M5-11.4），供腰包抽屜、4 槽位卡面、結算歸因三處
/// 引用——符號集中在這一個檔案，三處才有辦法保持一致（AC-M5-11.3）。
class ShutterResultBadge extends StatelessWidget {
  const ShutterResultBadge({super.key, required this.tier, this.compact = false});

  final ShotTier tier;

  /// 縮小版供密集排列的槽位卡面使用，符號與顏色不變，只降字級與內距。
  final bool compact;

  static const Map<ShotTier, (String, String, Color)> _presentation = {
    ShotTier.perfect: ('💎', '完美', Color(0xFF38A169)),
    ShotTier.normal: ('📷', '普通', Color(0xFF718096)),
    ShotTier.failed: ('💢', '失手', Color(0xFFE53E3E)),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _presentation[tier]!;
    final fontSize = compact ? 8.0 : 9.0;
    return Container(
      key: Key('shutterResultBadge.${tier.name}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
