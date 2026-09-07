import 'package:vector_math/vector_math.dart';

import '../projection/map_manifest.dart';

sealed class ProjectionResult {
  const ProjectionResult();
}

class Projected extends ProjectionResult {
  const Projected(this.pixel);
  final Vector2 pixel;
}

class OutsideCoverage extends ProjectionResult {
  const OutsideCoverage();
}

/// 範圍檢查 → 投影。
///
/// 範圍檢查必須在投影之前。反距離加權插值對範圍外的輸入不會失敗——它回傳一個
/// 落在錨點凸包內、看起來完全合理而實際上完全錯誤的點，所以事後才檢查的話，
/// 讀到的是一個憑空捏造的位置。
///
/// 兩者一律委派注入的圖資模組，通用引擎不得內含任何特定城市邏輯。
class ProjectionStage {
  const ProjectionStage(this.manifest);

  final OverworldMapManifest manifest;

  ProjectionResult project(double lat, double lng) {
    if (!manifest.containsGeo(lat, lng)) return const OutsideCoverage();
    return Projected(manifest.projectToPixel(lat, lng));
  }
}
