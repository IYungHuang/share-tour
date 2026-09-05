import 'geo_distance.dart';

enum RelocationCause { continuousTracking, discontinuity }

/// 傳送的細分原因。保證非空、列舉固定。
///
/// 供任務 A 日後區分用（例如「換層不記入旅程、背景恢復要記」），本 SPEC 不依賴
/// 它做行為分歧。訂為「可為空、不影響行為」等於禁止任務 A 依賴它，屆時要回頭改。
enum RelocationNote {
  backgroundResume,
  serviceRecovered,
  modeSwitch,
  coverageRecovered,
  debugTeleport,
  realMovement,
}

class RelocationDecision {
  const RelocationDecision({
    required this.distanceMeters,
    required this.speedMetersPerSecond,
    required this.cause,
    required this.note,
  });

  final double distanceMeters;
  final double speedMetersPerSecond;
  final RelocationCause cause;
  final RelocationNote note;
}

/// 大跨距偵測。
///
/// 判準是地理位移與速度，不是像素——手繪地圖的尺度在不同區域可差數倍，
/// 同一個像素門檻在一處是幾公里、在另一處是幾十公里。
///
/// 成因是二元的，只由「訂閱是否連續」決定。先前的五分法讓三種成因可同時成立
/// 而無優先序，冷啟動與範圍恢復兩條實際路徑則無任何成因適用。
///
/// 本模組只發出事實，不建議任何遊戲後果。二元成因的兩側目前都不該被懲罰：
/// continuousTracking 是玩家真的在高速移動（搭高鐵是這款遊戲的核心體驗），
/// discontinuity 的每條路徑也都是 app 自己造成的，不是玩家的錯。
class RelocationDetector {
  const RelocationDetector({
    required this.jumpLimitMeters,
    required this.jumpSpeedLimitMps,
  });

  final double jumpLimitMeters;
  final double jumpSpeedLimitMps;

  /// 回傳 null 代表不構成大跨距。
  RelocationDecision? evaluate({
    required double previousLat,
    required double previousLng,
    required double currentLat,
    required double currentLng,
    required Duration interval,
    required bool subscriptionWasContinuous,
    required RelocationNote note,
  }) {
    final meters =
        haversineMeters(previousLat, previousLng, currentLat, currentLng);
    final seconds = interval.inMicroseconds / 1e6;
    final speed = seconds > 0 ? meters / seconds : double.infinity;

    if (meters <= jumpLimitMeters && speed <= jumpSpeedLimitMps) return null;

    return RelocationDecision(
      distanceMeters: meters,
      speedMetersPerSecond: speed,
      cause: subscriptionWasContinuous
          ? RelocationCause.continuousTracking
          : RelocationCause.discontinuity,
      note: note,
    );
  }
}
