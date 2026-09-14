import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/domain/character_action/character_manifest_validator.dart';

CharacterAnimationAsset asset({
  String actionId = 'idle',
  CharacterDirection direction = CharacterDirection.front,
  CharacterAssetKind assetKind = CharacterAssetKind.overworld,
  String assetPath = 'guide/idle.png',
  int frameWidth = 2,
  int frameHeight = 2,
  int frameCount = 2,
  double fps = 8,
  NormalizedAnchor anchor = const NormalizedAnchor(0.5, 1),
  double renderWidth = 16,
  double renderHeight = 16,
  CharacterDirectionAxis directionAxis = CharacterDirectionAxis.row,
  PixelPoint sourceOrigin = PixelPoint.zero,
  PixelPadding padding = PixelPadding.zero,
  PixelSpacing spacing = PixelSpacing.zero,
  String? animationKey,
}) {
  return CharacterAnimationAsset(
    characterId: 'guide',
    actionId: actionId,
    direction: direction,
    assetKind: assetKind,
    assetPath: assetPath,
    frameWidth: frameWidth,
    frameHeight: frameHeight,
    frameCount: frameCount,
    fps: fps,
    loop: true,
    anchor: anchor,
    renderWidth: renderWidth,
    renderHeight: renderHeight,
    directionAxis: directionAxis,
    sourceOrigin: sourceOrigin,
    padding: padding,
    spacing: spacing,
    animationKey: animationKey ?? '$actionId/${direction.name}',
  );
}

List<CharacterAnimationAsset> idleAssets({
  CharacterAnimationAsset Function(CharacterDirection direction)? make,
}) => CharacterDirection.values
    .map((direction) => make?.call(direction) ?? asset(direction: direction))
    .toList();

CharacterAnimationManifest manifestWith(
  CharacterAnimationAsset extra, {
  List<CharacterAnimationAsset>? base,
}) => CharacterAnimationManifest([...(base ?? idleAssets()), extra]);

CharacterSheetInfo sheet({
  int width = 4,
  int height = 8,
  bool decodable = true,
  bool hasAlpha = true,
  bool Function(int x, int y)? isTransparent,
}) {
  return CharacterSheetInfo(
    width: width,
    height: height,
    decodable: decodable,
    hasAlpha: hasAlpha,
    isTransparent: isTransparent,
  );
}

void expectInvalid(
  CharacterAnimationManifest manifest,
  Map<String, CharacterSheetInfo> sheets, {
  String? message,
  Map<String, String> fallbackByAction = const {},
}) {
  CharacterManifestValidationException? error;
  try {
    CharacterManifestValidator().validate(
      manifest,
      sheets,
      fallbackByAction: fallbackByAction,
    );
  } catch (caught) {
    error = caught as CharacterManifestValidationException;
  }
  expect(error, isNotNull);
  if (message != null) {
    expect(error!.errors, contains(contains(message)));
  }
}

void main() {
  test('validates complete idle directions and opaque zero-padding sheet', () {
    expect(
      () => CharacterManifestValidator().validate(
        CharacterAnimationManifest(idleAssets()),
        {'guide/idle.png': sheet()},
      ),
      returnsNormally,
    );
  });

  test('rejects RGB or undecodable character sheet', () {
    expectInvalid(CharacterAnimationManifest(idleAssets()), {
      'guide/idle.png': sheet(hasAlpha: false),
    }, message: 'RGBA');
    expectInvalid(CharacterAnimationManifest(idleAssets()), {
      'guide/idle.png': sheet(decodable: false),
    }, message: 'decode');
  });

  test('rejects illegal dimensions, fps, anchor, and sheet bounds', () {
    expectInvalid(manifestWith(asset(frameWidth: 0)), {
      'guide/idle.png': sheet(),
    }, message: 'frameWidth');
    expectInvalid(manifestWith(asset(fps: double.nan)), {
      'guide/idle.png': sheet(),
    }, message: 'fps');
    expectInvalid(
      manifestWith(asset(anchor: const NormalizedAnchor(1.1, 0.5))),
      {'guide/idle.png': sheet()},
      message: 'anchor',
    );
    expectInvalid(manifestWith(asset(sourceOrigin: const PixelPoint(3, 0))), {
      'guide/idle.png': sheet(),
    }, message: 'bounds');
    expectInvalid(manifestWith(asset(frameCount: 0)), {
      'guide/idle.png': sheet(),
    }, message: 'frameCount');
    expectInvalid(manifestWith(asset(renderHeight: 0)), {
      'guide/idle.png': sheet(),
    }, message: 'renderHeight');
  });

  test('rejects missing assets and negative layout values', () {
    expectInvalid(
      CharacterAnimationManifest(idleAssets()),
      const {},
      message: 'missing',
    );
    expectInvalid(
      manifestWith(asset(padding: const PixelPadding(-1, 0, 0, 0))),
      {'guide/idle.png': sheet()},
      message: 'padding',
    );
    expectInvalid(manifestWith(asset(spacing: const PixelSpacing(0, -1))), {
      'guide/idle.png': sheet(),
    }, message: 'spacing');
  });

  test(
    'rejects missing direction, duplicate keys, and non-overworld assets',
    () {
      expectInvalid(
        CharacterAnimationManifest(idleAssets().sublist(0, 3)),
        {'guide/idle.png': sheet()},
        message: 'directions',
      );
      expectInvalid(manifestWith(asset(), base: idleAssets()), {
        'guide/idle.png': sheet(),
      }, message: 'duplicate');
      expectInvalid(
        manifestWith(
          asset(actionId: 'dialogue', assetKind: CharacterAssetKind.dialogue),
        ),
        {'guide/idle.png': sheet()},
        message: 'overworld',
      );
      expectInvalid(
        manifestWith(asset(actionId: 'walk', animationKey: 'idle/front')),
        {'guide/idle.png': sheet()},
        message: 'animationKey',
      );
    },
  );

  test('rejects inconsistent records within one declared action', () {
    final walk = CharacterDirection.values.map(
      (direction) => asset(
        actionId: 'walk',
        direction: direction,
        assetPath: direction == CharacterDirection.left
            ? 'guide/walk_alt.png'
            : 'guide/walk.png',
        animationKey: 'walk/${direction.name}',
      ),
    );
    expectInvalid(CharacterAnimationManifest([...idleAssets(), ...walk]), {
      'guide/idle.png': sheet(),
      'guide/walk.png': sheet(),
      'guide/walk_alt.png': sheet(),
    }, message: 'consistent');
  });

  test('rejects non-transparent declared padding', () {
    final padded = asset(
      padding: const PixelPadding(1, 1, 1, 1),
      frameWidth: 1,
      frameHeight: 1,
      frameCount: 1,
    );
    expectInvalid(
      CharacterAnimationManifest([
        ...idleAssets(),
        ...CharacterDirection.values
            .skip(1)
            .map(
              (direction) => asset(
                direction: direction,
                padding: const PixelPadding(1, 1, 1, 1),
                frameWidth: 1,
                frameHeight: 1,
                frameCount: 1,
              ),
            ),
        padded,
      ]),
      {'guide/idle.png': sheet(width: 20, height: 20)},
      message: 'padding',
    );
  });

  test('rejects fallback cycle but allows missing optional action', () {
    expectInvalid(
      CharacterAnimationManifest(idleAssets()),
      {'guide/idle.png': sheet()},
      fallbackByAction: {'walk': 'run', 'run': 'walk'},
      message: 'cycle',
    );
  });
}
