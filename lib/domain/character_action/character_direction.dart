enum CharacterDirection { front, left, back, right }

extension CharacterDirectionIndex on CharacterDirection {
  int get indexInSheet => switch (this) {
    CharacterDirection.front => 0,
    CharacterDirection.left => 1,
    CharacterDirection.back => 2,
    CharacterDirection.right => 3,
  };
}
