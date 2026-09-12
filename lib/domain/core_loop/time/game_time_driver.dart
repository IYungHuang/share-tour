import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'game_time_snapshot.dart';

/// 時鐘驅動抽象介面
abstract class GameTimeDriver {
  /// 依據阿導體力、採集進度與階段計算當前時間快照
  GameTimeSnapshot computeSnapshot({
    required int currentHp,
    required int maxHp,
    required int gatheredCount,
    required int waistBagCapacity,
    required CuratorRunPhase phase,
  });
}
