import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/time/curator_run_progression_driver.dart';
import 'package:share_tour/domain/core_loop/time/game_time_driver.dart';
import 'package:share_tour/domain/core_loop/time/game_time_snapshot.dart';
import 'package:share_tour/domain/core_loop/time/realtime_gps_driver.dart';
import 'curator_run_providers.dart';

/// 時間推移模式
enum GameTimeMode {
  runProgression, // 策展局內進程 (由體力與採集進度驅動)
  realtimeGps, // 大世界漫遊 (由本地時間或縮時模擬驅動)
}

/// 時間驅動模式 Provider (預設為策展局內進程)
final gameTimeModeProvider =
    StateProvider<GameTimeMode>((ref) => GameTimeMode.runProgression);

/// 策展進程時鐘驅動器 Provider
final progressionDriverProvider =
    Provider<GameTimeDriver>((ref) => const CuratorRunProgressionDriver());

/// 真實 GPS / 縮時時鐘驅動器 Provider
final realtimeGpsDriverProvider =
    Provider<GameTimeDriver>((ref) => const RealtimeGpsDriver());

/// 當前遊戲時間快照 Provider (單一真理源)
final gameTimeProvider = Provider<GameTimeSnapshot>((ref) {
  final mode = ref.watch(gameTimeModeProvider);
  final runState = ref.watch(curatorRunControllerProvider);

  // 若在踩線或局內階段，自動遵循 runProgression
  final isRunActive = runState.phase != CuratorRunPhase.philosophizing &&
      runState.phase != CuratorRunPhase.settled;

  final driver = (mode == GameTimeMode.realtimeGps && !isRunActive)
      ? ref.watch(realtimeGpsDriverProvider)
      : ref.watch(progressionDriverProvider);

  return driver.computeSnapshot(
    currentHp: runState.resources.hp,
    maxHp: runState.resources.maxHp,
    gatheredCount: runState.inventory.count,
    waistBagCapacity: runState.inventory.capacity,
    phase: runState.phase,
  );
});
