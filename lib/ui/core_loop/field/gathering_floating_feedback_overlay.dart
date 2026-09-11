import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';

/// 漂浮反饋資料項
class GatheringFloatingFeedbackItem {
  const GatheringFloatingFeedbackItem({
    required this.materialName,
    required this.hpCost,
    this.isSpotlight = false,
  });

  final String materialName;
  final int hpCost;
  final bool isSpotlight;
}

/// 漂浮反饋控制器
class GatheringFloatingFeedbackController extends ChangeNotifier {
  GatheringFloatingFeedbackItem? _currentItem;
  GatheringFloatingFeedbackItem? get currentItem => _currentItem;

  void showFeedback({
    required String materialName,
    required int hpCost,
    bool isSpotlight = false,
  }) {
    _currentItem = GatheringFloatingFeedbackItem(
      materialName: materialName,
      hpCost: hpCost,
      isSpotlight: isSpotlight,
    );
    notifyListeners();
  }

  void showGatherFeedback({
    required TravelMaterial material,
    required int hpSpent,
  }) {
    showFeedback(
      materialName: material.name,
      hpCost: hpSpent,
      isSpotlight: material.isSpotlight,
    );
  }

  void clear() {
    _currentItem = null;
    notifyListeners();
  }
}

/// JRPG 街機風格踩線取材漂浮文字反饋 (REQ-M3-06, G5)
///
/// 呈現紅色「-XX HP」、金色「+ 👝 [素材名]」以及 Spotlight 絕景特效。
/// 根節點以 IgnorePointer 與 RepaintBoundary 包裹，確保零手勢干擾與 120Hz 隔離。
class GatheringFloatingFeedbackOverlay extends StatefulWidget {
  const GatheringFloatingFeedbackOverlay({
    super.key,
    required this.controller,
  });

  final GatheringFloatingFeedbackController controller;

  @override
  State<GatheringFloatingFeedbackOverlay> createState() =>
      _GatheringFloatingFeedbackOverlayState();
}

class _GatheringFloatingFeedbackOverlayState
    extends State<GatheringFloatingFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  GatheringFloatingFeedbackItem? _activeItem;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_animController);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.6),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    widget.controller.addListener(_onFeedbackTriggered);
  }

  void _onFeedbackTriggered() {
    final item = widget.controller.currentItem;
    if (item != null && mounted) {
      setState(() {
        _activeItem = item;
      });
      _animController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _activeItem = null;
          });
          widget.controller.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFeedbackTriggered);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeItem == null) return const SizedBox.shrink();

    final item = _activeItem!;

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 消耗 HP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      border: Border.all(color: const Color(0xFFFF4757), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: Text(
                      '-${item.hpCost} HP',
                      style: const TextStyle(
                        color: Color(0xFFFF4757),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 2. 取得素材
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A202C),
                      border: Border.all(
                        color: item.isSpotlight ? Colors.amber : const Color(0xFF48BB78),
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_photo_alternate, size: 16, color: Color(0xFF48BB78)),
                        const SizedBox(width: 4),
                        Text(
                          '+ 👝 ${item.materialName}',
                          style: TextStyle(
                            color: item.isSpotlight ? Colors.amber : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. 焦點絕景爆擊粒子提示
                  if (item.isSpotlight) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      color: Colors.amber,
                      child: const Text(
                        '✨ SPOTLIGHT!',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
