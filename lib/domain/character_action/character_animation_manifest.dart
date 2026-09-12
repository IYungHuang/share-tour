import 'character_direction.dart';

enum CharacterAssetKind { overworld, dialogue, halfbody, portrait, expression }

enum CharacterDirectionAxis { row, column }

class PixelPoint {
  const PixelPoint(this.x, this.y);

  static const zero = PixelPoint(0, 0);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is PixelPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PixelPoint($x, $y)';
}

class NormalizedAnchor {
  const NormalizedAnchor(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is NormalizedAnchor && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'NormalizedAnchor($x, $y)';
}

class PixelPadding {
  const PixelPadding(this.left, this.top, this.right, this.bottom);

  static const zero = PixelPadding(0, 0, 0, 0);

  final int left;
  final int top;
  final int right;
  final int bottom;

  @override
  bool operator ==(Object other) =>
      other is PixelPadding &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class PixelSpacing {
  const PixelSpacing(this.horizontal, this.vertical);

  static const zero = PixelSpacing(0, 0);

  final int horizontal;
  final int vertical;

  @override
  bool operator ==(Object other) =>
      other is PixelSpacing &&
      other.horizontal == horizontal &&
      other.vertical == vertical;

  @override
  int get hashCode => Object.hash(horizontal, vertical);
}

class CharacterAnimationAsset {
  const CharacterAnimationAsset({
    required this.characterId,
    required this.actionId,
    required this.direction,
    required this.assetKind,
    required this.assetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameCount,
    required this.fps,
    required this.loop,
    required this.anchor,
    required this.renderWidth,
    required this.renderHeight,
    required this.directionAxis,
    required this.sourceOrigin,
    required this.padding,
    required this.spacing,
    required this.animationKey,
  });

  final String characterId;
  final String actionId;
  final CharacterDirection direction;
  final CharacterAssetKind assetKind;
  final String assetPath;
  final int frameWidth;
  final int frameHeight;
  final int frameCount;
  final double fps;
  final bool loop;
  final NormalizedAnchor anchor;
  final double renderWidth;
  final double renderHeight;
  final CharacterDirectionAxis directionAxis;
  final PixelPoint sourceOrigin;
  final PixelPadding padding;
  final PixelSpacing spacing;
  final String animationKey;

  int get regionWidth => switch (directionAxis) {
    CharacterDirectionAxis.row =>
      padding.left +
          frameCount * frameWidth +
          (frameCount - 1) * spacing.horizontal +
          padding.right,
    CharacterDirectionAxis.column =>
      padding.left + 4 * frameWidth + 3 * spacing.horizontal + padding.right,
  };

  int get regionHeight => switch (directionAxis) {
    CharacterDirectionAxis.row =>
      padding.top + 4 * frameHeight + 3 * spacing.vertical + padding.bottom,
    CharacterDirectionAxis.column =>
      padding.top +
          frameCount * frameHeight +
          (frameCount - 1) * spacing.vertical +
          padding.bottom,
  };

  PixelPoint frameOrigin(CharacterDirection frameDirection, int frameIndex) {
    if (frameIndex < 0 || frameIndex >= frameCount) {
      throw RangeError.range(frameIndex, 0, frameCount - 1, 'frameIndex');
    }

    final directionIndex = frameDirection.indexInSheet;
    final x = switch (directionAxis) {
      CharacterDirectionAxis.row =>
        sourceOrigin.x +
            padding.left +
            frameIndex * (frameWidth + spacing.horizontal),
      CharacterDirectionAxis.column =>
        sourceOrigin.x +
            padding.left +
            directionIndex * (frameWidth + spacing.horizontal),
    };
    final y = switch (directionAxis) {
      CharacterDirectionAxis.row =>
        sourceOrigin.y +
            padding.top +
            directionIndex * (frameHeight + spacing.vertical),
      CharacterDirectionAxis.column =>
        sourceOrigin.y +
            padding.top +
            frameIndex * (frameHeight + spacing.vertical),
    };
    return PixelPoint(x, y);
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterAnimationAsset &&
      other.characterId == characterId &&
      other.actionId == actionId &&
      other.direction == direction &&
      other.assetKind == assetKind &&
      other.assetPath == assetPath &&
      other.frameWidth == frameWidth &&
      other.frameHeight == frameHeight &&
      other.frameCount == frameCount &&
      other.fps == fps &&
      other.loop == loop &&
      other.anchor == anchor &&
      other.renderWidth == renderWidth &&
      other.renderHeight == renderHeight &&
      other.directionAxis == directionAxis &&
      other.sourceOrigin == sourceOrigin &&
      other.padding == padding &&
      other.spacing == spacing &&
      other.animationKey == animationKey;

  @override
  int get hashCode => Object.hash(
    characterId,
    actionId,
    direction,
    assetKind,
    assetPath,
    frameWidth,
    frameHeight,
    frameCount,
    fps,
    loop,
    anchor,
    renderWidth,
    renderHeight,
    directionAxis,
    sourceOrigin,
    padding,
    spacing,
    animationKey,
  );
}

class CharacterAnimationManifest {
  CharacterAnimationManifest(Iterable<CharacterAnimationAsset> assets)
    : assets = List.unmodifiable(assets);

  final List<CharacterAnimationAsset> assets;
}
