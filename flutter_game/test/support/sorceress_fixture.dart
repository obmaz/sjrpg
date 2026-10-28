import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';

/// Set up learned prerequisites through the same API as the game. Callers that
/// verify level gates should supply their own level instead of this high-level fixture.
Progress trainedSorceress() => Progress(heroClass: HeroClass.mage)
  ..level = 100
  ..skillPoints = 1000;

void trainSkill(Progress progress, String id, [int target = 1]) {
  final skill = progress.skills.firstWhere((skill) => skill.id == id);
  for (final need in skill.requires.entries) {
    trainSkill(progress, need.key, need.value);
  }
  while (progress.rank(id) < target) {
    expect(progress.learn(skill), isTrue, reason: 'learn $id rank $target');
  }
}
