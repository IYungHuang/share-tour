import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_fix.dart';
import 'rejection_reason.dart';

part 'location_status.freezed.dart';
part 'location_status.g.dart';

enum PermissionState {
  ready,
  serviceDisabled,
  denied,
  deniedForever,
  approximate,
  unavailable,
}

enum CoverageState { inside, outside }

enum AcquisitionState { acquiring, acquired }

enum MotionState { still, moving }

enum PowerMode { active, suspended }

/// HUD 顯示優先序。同時成立時只顯示最高者。
enum HudPriority {
  permissionProblem,
  virtualMode,
  outsideCoverage,
  acquiring,
  normal,
}

/// 定位的可觀測狀態。
///
/// 五個維度互相獨立：一個已授權的玩家可以同時處於圖資範圍外、以方向鍵移動、
/// 且尚未取得可信位置。把它們壓成單一互斥列舉，會產生型別無法表達的合法狀態。
@freezed
abstract class LocationStatus with _$LocationStatus {
  const factory LocationStatus({
    required PermissionState permission,
    required SourceMode mode,
    required CoverageState coverage,
    required AcquisitionState acquisition,
    required MotionState motion,
  }) = _LocationStatus;

  /// 用 static const 而非 `const factory LocationStatus.initial()`。
  /// 後者會讓 LocationStatus 變成 union，union 上沒有共用的 copyWith，
  /// 而多條測試依賴 copyWith 驗證維度獨立性。
  static const LocationStatus initial = LocationStatus(
    permission: PermissionState.unavailable,
    mode: SourceMode.gps,
    coverage: CoverageState.inside,
    acquisition: AcquisitionState.acquiring,
    motion: MotionState.still,
  );
}

/// 顯示優先序寫成函式而非散落在 UI 條件式，
/// 才能對「任一組合唯一決定」這件事寫測試。
HudPriority hudPriorityOf(LocationStatus s) {
  if (s.permission != PermissionState.ready) return HudPriority.permissionProblem;
  if (s.mode == SourceMode.virtual) return HudPriority.virtualMode;
  if (s.coverage == CoverageState.outside) return HudPriority.outsideCoverage;
  if (s.acquisition == AcquisitionState.acquiring) return HudPriority.acquiring;
  return HudPriority.normal;
}

/// 唯讀診斷快照。
///
/// 多條驗收條件依賴這些計數才能斷言，故它是有 AC 的功能需求而非非功能項。
/// 依隱私規則，不含任何原始經緯度。
@freezed
abstract class LocationDiagnostics with _$LocationDiagnostics {
  const factory LocationDiagnostics({
    required int activeSubscriptionCount,
    required PowerMode powerMode,
    required int acceptedFixCount,
    required int rejectedFixCount,
    required Map<RejectionReason, int> rejectionsByReason,
    required double currentAccuracyMeters,
    required double realDistanceMeters,
    required double virtualDistanceMeters,
    required int secondsSinceLastSignificantMove,
  }) = _LocationDiagnostics;

  factory LocationDiagnostics.fromJson(Map<String, dynamic> json) =>
      _$LocationDiagnosticsFromJson(json);
}
