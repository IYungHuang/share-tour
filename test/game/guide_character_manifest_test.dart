import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_manifest_validator.dart';
import 'package:share_tour/game/characters/guide_character_manifest.dart';

void main() {
  test(
    'production guide manifests declare idle, walk, and run in four directions',
    () {
      expect(guideCharacterManifest.assets, hasLength(12));
      expect(femaleGuideCharacterManifest.assets, hasLength(12));
      expect(
        guideCharacterManifest.assets
            .where((asset) => asset.actionId.contains('locomotion=run'))
            .every((asset) => asset.playbackFrameCount == 4),
        isTrue,
      );

      expect(
        () => CharacterManifestValidator().validate(guideCharacterManifest, {
          'guide_overworld_sheet_v1_generated.png': const CharacterSheetInfo(
            width: 1448,
            height: 1086,
          ),
        }),
        returnsNormally,
      );
      expect(
        () => CharacterManifestValidator()
            .validate(femaleGuideCharacterManifest, {
              'guide_female_overworld_sheet_v3_generated.png':
                  const CharacterSheetInfo(width: 1448, height: 1086),
            }),
        returnsNormally,
      );
    },
  );
}
