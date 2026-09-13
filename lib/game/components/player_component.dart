import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/character_action/character_action.dart';
import '../../domain/character_action/character_direction.dart';
import 'character_component.dart';
import '../characters/guide_action_sheet_registry.dart';

/// 小人。只負責把 domain 算出的顯示點畫出來，不含任何位置計算。
///
/// 讀寫座標一律用 setFrom／clone 明確表達意圖：所用引擎的座標 getter 在不同
/// 元件上語意相反（一者回傳活參考、一者回傳副本），兩種失效模式都不報錯。
class PlayerComponent extends PositionComponent {
  PlayerComponent({required Vector2 position, this.characterComponent})
    : placeholder = characterComponent == null
          ? CircleComponent(
              radius: 8,
              anchor: Anchor.center,
              paint: Paint()..color = const Color(0xFFFF4757),
            )
          : null,
      super(
        position: position,
        size: Vector2.all(16),
        anchor: Anchor.center,
        priority: 20,
      ) {
    final child = characterComponent ?? placeholder!;
    child.position = Vector2.zero();
    add(child);
  }

  final CharacterComponent? characterComponent;
  final CircleComponent? placeholder;

  void syncTo(Vector2 renderedPixel) => position.setFrom(renderedPixel);

  bool play(CharacterAction action) =>
      characterComponent?.controller.play(action) ?? false;

  void setDirection(CharacterDirection direction) {
    characterComponent?.controller.setDirection(direction);
  }

  Future<void> playCell(CharacterActionSheetCell cell) async {
    await characterComponent?.playCell(cell);
  }
}
