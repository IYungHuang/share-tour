import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/game/map_module/manifests/classification_mask.dart';

/// 遮罩解析度 256×144，主圖層 2048×1152，scale = 8（CLAUDE.md §4 記載）。
/// 海洋色（0,0,255）視為範圍外；其餘顏色（陸地綠、海岸磁紅、POI 標記黃）
/// 一律視為範圍內——本模組只需要二元的陸/海判定。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClassificationMask mask;

  setUpAll(() async {
    mask = await ClassificationMask.loadFromAsset(
      'assets/maps/taiwan/mask.png',
      scale: 8,
    );
  });

  test('太平洋（畫布左上角，海洋藍）→ 範圍外', () {
    expect(mask.isInside(Vector2(0, 0)), isFalse);
  });

  test('台北 101 附近（陸地）→ 範圍內', () {
    expect(mask.isInside(Vector2(1162, 148)), isTrue);
  });

  test('鵝鑾鼻附近（陸地南端）→ 範圍內', () {
    expect(mask.isInside(Vector2(967, 1083)), isTrue);
  });

  test('主圖層座標超出遮罩換算範圍 → 範圍外（不拋例外）', () {
    expect(mask.isInside(Vector2(-100, -100)), isFalse);
    expect(mask.isInside(Vector2(999999, 999999)), isFalse);
  });

  test('scale 換算：遮罩座標 = 主圖層座標 / scale', () {
    expect(mask.width, 256);
    expect(mask.height, 144);
  });
}
