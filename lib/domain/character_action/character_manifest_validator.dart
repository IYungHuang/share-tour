import 'character_action.dart';
import 'character_animation_manifest.dart';
import 'character_direction.dart';

typedef AlphaSampler = bool Function(int x, int y);

/// Decoded image facts supplied by an outer asset adapter.
///
/// Keeping this value outside Flutter lets manifest validation run in the
/// domain boundary without importing `dart:ui`.
class CharacterSheetInfo {
  const CharacterSheetInfo({
    required this.width,
    required this.height,
    this.decodable = true,
    this.hasAlpha = true,
    this.isTransparent,
  });

  final int width;
  final int height;
  final bool decodable;
  final bool hasAlpha;
  final AlphaSampler? isTransparent;

  bool pixelIsTransparent(int x, int y) => isTransparent?.call(x, y) ?? false;
}

class CharacterManifestValidationException implements Exception {
  CharacterManifestValidationException(Iterable<String> errors)
    : errors = List.unmodifiable(errors);

  final List<String> errors;

  @override
  String toString() =>
      'CharacterManifestValidationException:\n${errors.join('\n')}';
}

class CharacterManifestValidator {
  void validate(
    CharacterAnimationManifest manifest,
    Map<String, CharacterSheetInfo> sheets, {
    Map<String, String> fallbackByAction = const {},
  }) {
    final errors = <String>[];
    final seenRecords = <String>{};
    final seenAnimationKeys = <String>{};
    final actionsByCharacter = <String, Set<String>>{};
    final directionsByAction = <String, Set<CharacterDirection>>{};
    final firstAssetByAction = <String, CharacterAnimationAsset>{};

    for (final asset in manifest.assets) {
      final recordKey =
          '${asset.characterId}|${asset.actionId}|${asset.direction.name}';
      if (!seenRecords.add(recordKey)) {
        errors.add('duplicate action/direction key: $recordKey');
      }
      if (!seenAnimationKeys.add(asset.animationKey)) {
        errors.add('duplicate animationKey: ${asset.animationKey}');
      }

      actionsByCharacter
          .putIfAbsent(asset.characterId, () => <String>{})
          .add(asset.actionId);
      directionsByAction
          .putIfAbsent(recordKeyWithoutDirection(asset), () => {})
          .add(asset.direction);
      final actionKey = recordKeyWithoutDirection(asset);
      final firstAsset = firstAssetByAction[actionKey];
      if (firstAsset == null) {
        firstAssetByAction[actionKey] = asset;
      } else if (!_sameActionContract(firstAsset, asset)) {
        errors.add('$actionKey direction records must be consistent');
      }

      if (asset.assetKind != CharacterAssetKind.overworld) {
        errors.add('${asset.assetPath} must use overworld assetKind');
      }
      if (asset.frameWidth <= 0) {
        errors.add('$recordKey frameWidth must be positive');
      }
      if (asset.frameHeight <= 0) {
        errors.add('$recordKey frameHeight must be positive');
      }
      if (asset.frameCount <= 0) {
        errors.add('$recordKey frameCount must be positive');
      }
      if (!asset.fps.isFinite || asset.fps <= 0) {
        errors.add('$recordKey fps must be finite and positive');
      }
      if (!_isNormalized(asset.anchor)) {
        errors.add('$recordKey anchor must be normalized');
      }
      if (asset.renderWidth <= 0 || !asset.renderWidth.isFinite) {
        errors.add('$recordKey renderWidth must be finite and positive');
      }
      if (asset.renderHeight <= 0 || !asset.renderHeight.isFinite) {
        errors.add('$recordKey renderHeight must be finite and positive');
      }
      if (!_isNonNegative(asset.sourceOrigin.x, asset.sourceOrigin.y)) {
        errors.add('$recordKey sourceOrigin must be non-negative');
      }
      if (!_isNonNegative(
        asset.padding.left,
        asset.padding.top,
        asset.padding.right,
        asset.padding.bottom,
      )) {
        errors.add('$recordKey padding must be non-negative');
      }
      if (!_isNonNegative(asset.spacing.horizontal, asset.spacing.vertical)) {
        errors.add('$recordKey spacing must be non-negative');
      }

      final sheet = sheets[asset.assetPath];
      if (sheet == null) {
        errors.add('${asset.assetPath} asset is missing');
        continue;
      }
      if (!sheet.decodable) {
        errors.add('${asset.assetPath} failed to decode');
        continue;
      }
      if (!sheet.hasAlpha) {
        errors.add('${asset.assetPath} must be RGBA');
      }
      if (!_hasValidGeometry(asset)) {
        continue;
      }

      final right = asset.sourceOrigin.x + asset.regionWidth;
      final bottom = asset.sourceOrigin.y + asset.regionHeight;
      if (right > sheet.width || bottom > sheet.height) {
        errors.add('$recordKey region exceeds sheet bounds');
        continue;
      }
      if (_hasOpaquePadding(asset, sheet)) {
        errors.add('$recordKey declared padding must be transparent');
      }
    }

    for (final entry in directionsByAction.entries) {
      if (entry.value.length != CharacterDirection.values.length) {
        errors.add('${entry.key} must declare all four directions');
      }
    }

    for (final character in actionsByCharacter.keys) {
      final hasIdle = manifest.assets.any(
        (asset) =>
            asset.characterId == character &&
            (asset.actionId == 'idle' ||
                asset.actionId == const CharacterAction().canonicalKey),
      );
      if (!hasIdle) {
        errors.add('$character must declare idle');
      }
    }

    _validateFallbackCycles(fallbackByAction, errors);

    if (errors.isNotEmpty) {
      throw CharacterManifestValidationException(errors);
    }
  }

  bool _hasValidGeometry(CharacterAnimationAsset asset) {
    return asset.frameWidth > 0 &&
        asset.frameHeight > 0 &&
        asset.frameCount > 0 &&
        asset.padding.left >= 0 &&
        asset.padding.top >= 0 &&
        asset.padding.right >= 0 &&
        asset.padding.bottom >= 0 &&
        asset.spacing.horizontal >= 0 &&
        asset.spacing.vertical >= 0;
  }

  bool _hasOpaquePadding(
    CharacterAnimationAsset asset,
    CharacterSheetInfo sheet,
  ) {
    if (asset.padding == PixelPadding.zero) {
      return false;
    }

    for (var y = 0; y < asset.regionHeight; y++) {
      for (var x = 0; x < asset.regionWidth; x++) {
        if (_isFramePixel(asset, x, y)) {
          continue;
        }
        final sourceX = asset.sourceOrigin.x + x;
        final sourceY = asset.sourceOrigin.y + y;
        if (!sheet.pixelIsTransparent(sourceX, sourceY)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isFramePixel(CharacterAnimationAsset asset, int x, int y) {
    final contentX = x - asset.padding.left;
    final contentY = y - asset.padding.top;
    if (contentX < 0 || contentY < 0) {
      return false;
    }

    return switch (asset.directionAxis) {
      CharacterDirectionAxis.row => _isFrameCoordinate(
        contentX,
        contentY,
        asset.frameWidth,
        asset.frameHeight,
        asset.frameCount,
        asset.spacing.horizontal,
        asset.spacing.vertical,
        fourRows: true,
      ),
      CharacterDirectionAxis.column => _isFrameCoordinate(
        contentX,
        contentY,
        asset.frameWidth,
        asset.frameHeight,
        asset.frameCount,
        asset.spacing.horizontal,
        asset.spacing.vertical,
        fourRows: false,
      ),
    };
  }

  bool _isFrameCoordinate(
    int x,
    int y,
    int frameWidth,
    int frameHeight,
    int frameCount,
    int horizontalSpacing,
    int verticalSpacing, {
    required bool fourRows,
  }) {
    final frameAxisLength = fourRows ? frameCount : 4;
    final crossAxisLength = fourRows ? 4 : frameCount;
    final frameAxisStep = fourRows
        ? frameWidth + horizontalSpacing
        : frameHeight + verticalSpacing;
    final crossAxisStep = fourRows
        ? frameHeight + verticalSpacing
        : frameWidth + horizontalSpacing;
    final frameAxis = fourRows ? x : y;
    final crossAxis = fourRows ? y : x;

    final frameIndex = frameAxis ~/ frameAxisStep;
    final crossIndex = crossAxis ~/ crossAxisStep;
    if (frameIndex < 0 || frameIndex >= frameAxisLength) {
      return false;
    }
    if (crossIndex < 0 || crossIndex >= crossAxisLength) {
      return false;
    }
    return frameAxis % frameAxisStep < (fourRows ? frameWidth : frameHeight) &&
        crossAxis % crossAxisStep < (fourRows ? frameHeight : frameWidth);
  }

  void _validateFallbackCycles(
    Map<String, String> fallbackByAction,
    List<String> errors,
  ) {
    for (final start in fallbackByAction.keys) {
      final visited = <String>{};
      var current = start;
      while (fallbackByAction.containsKey(current)) {
        if (!visited.add(current)) {
          errors.add('fallback cycle detected at $current');
          break;
        }
        current = fallbackByAction[current]!;
      }
    }
  }

  bool _sameActionContract(
    CharacterAnimationAsset first,
    CharacterAnimationAsset second,
  ) {
    return first.assetKind == second.assetKind &&
        first.assetPath == second.assetPath &&
        first.frameWidth == second.frameWidth &&
        first.frameHeight == second.frameHeight &&
        first.frameCount == second.frameCount &&
        first.fps == second.fps &&
        first.loop == second.loop &&
        first.anchor == second.anchor &&
        first.renderWidth == second.renderWidth &&
        first.renderHeight == second.renderHeight &&
        first.directionAxis == second.directionAxis &&
        first.sourceOrigin == second.sourceOrigin &&
        first.padding == second.padding &&
        first.spacing == second.spacing;
  }

  bool _isNormalized(NormalizedAnchor anchor) =>
      anchor.x.isFinite &&
      anchor.y.isFinite &&
      anchor.x >= 0 &&
      anchor.x <= 1 &&
      anchor.y >= 0 &&
      anchor.y <= 1;

  bool _isNonNegative(int first, int second, [int? third, int? fourth]) =>
      first >= 0 &&
      second >= 0 &&
      (third == null || third >= 0) &&
      (fourth == null || fourth >= 0);

  String recordKeyWithoutDirection(CharacterAnimationAsset asset) =>
      '${asset.characterId}|${asset.actionId}';
}
