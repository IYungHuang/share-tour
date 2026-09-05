import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 小人。只負責把 domain 算出的顯示點畫出來，不含任何位置計算。
///
/// 讀寫座標一律用 setFrom／clone 明確表達意圖：所用引擎的座標 getter 在不同
/// 元件上語意相反（一者回傳活參考、一者回傳副本），兩種失效模式都不報錯。
class PlayerComponent extends CircleComponent {
  PlayerComponent({required super.position})
      : super(
          radius: 8,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFFF4757),
        );

  void syncTo(Vector2 renderedPixel) => position.setFrom(renderedPixel);
}
