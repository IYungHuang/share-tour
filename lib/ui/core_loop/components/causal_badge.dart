import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';

/// 因果回饋定性徽章組件 (CausalBadge)
/// 承載 reasonCode、sourceSignifier、intensity、direction，點擊可彈出 Codex 詞條 Tooltip
class CausalBadge extends StatelessWidget {
  const CausalBadge({
    super.key,
    required this.reasonCode,
    required this.sourceSignifier,
    this.intensity = ImpactIntensity.minor,
    this.direction = ImpactDirection.positive,
    this.onTap,
    this.isGold = false,
  });

  factory CausalBadge.fromFact(CausalFact fact, {VoidCallback? onTap}) {
    return CausalBadge(
      key: Key('causal_badge_${fact.reasonCode}'),
      reasonCode: fact.reasonCode,
      sourceSignifier: fact.sourceSignifier,
      intensity: fact.intensity,
      direction: fact.direction,
      onTap: onTap,
      isGold: fact.reasonCode == 'ambient_slot_affinity',
    );
  }

  final String reasonCode;
  final String sourceSignifier;
  final ImpactIntensity intensity;
  final ImpactDirection direction;
  final VoidCallback? onTap;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = _resolveColors();

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        sourceSignifier,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: badge,
      );
    }

    return badge;
  }

  (Color, Color, Color) _resolveColors() {
    if (isGold) {
      return (
        const Color(0xFFFEF3C7),
        const Color(0xFFF59E0B),
        const Color(0xFF92400E),
      );
    }
    if (direction == ImpactDirection.positive) {
      return (
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
        const Color(0xFF166534),
      );
    } else {
      return (
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
        const Color(0xFF991B1B),
      );
    }
  }
}
