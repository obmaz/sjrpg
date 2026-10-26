import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure mountedSession({bool aimed = false}) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    if (aimed) {
      s.progress.ranks['charge'] = 1;
      expect(s.progress.selectSkill('charge'), true);
    }
    final horse = s.mounts.firstWhere((m) => m.def.id == 'horse');
    horse.at = const Offset(6000, 4200);
    s.hero.position.setValues(5990, 4250);
    expect(s.boardNearbyMount(), true);
    return s;
  }

  for (final aimed in [false, true]) {
    for (final rejection in ['resource', 'cooldown', 'empty', 'unlearned']) {
      test(
        '${aimed ? 'aimed' : 'instant'} skill rejected for $rejection keeps the rider mounted',
        () {
          final s = mountedSession(aimed: aimed);
          final horse = s.riding, body = s.hero.body;
          final def = s.progress.skillAt(0)!;
          final slot = rejection == 'empty' ? 3 : 0;
          switch (rejection) {
            case 'resource':
              s.progress.energy = 0;
            case 'cooldown':
              s.hero.cooldowns[def.id] = 2;
            case 'unlearned':
              s.progress.ranks[def.id] = 0;
          }
          final energy = s.progress.energy;
          final cooldowns = Map<String, double>.of(s.hero.cooldowns);

          if (aimed) {
            s.hero.beginAim(slot);
            s.hero.finishAim(false);
          } else {
            s.hero.skill(slot: slot);
          }

          expect(s.progress.energy, energy);
          expect(s.hero.cooldowns, cooldowns);
          expect(s.riding, same(horse));
          expect(s.hero.body, body);
          expect(s.hero.aim, isNull);
          expect(
            s.texts.where((text) => text.label.endsWith(' 부족')).length,
            rejection == 'resource' ? 1 : 0,
          );
        },
      );
    }

    test(
      '${aimed ? 'aimed' : 'instant'} valid skill still dismounts and casts',
      () {
        final s = mountedSession(aimed: aimed);
        final def = s.progress.skillAt(0)!;
        final energy = s.progress.energy;

        if (aimed) {
          s.hero.beginAim(0);
          expect(s.riding, isNull);
          expect(s.hero.aim, isNotNull);
          expect(s.progress.energy, energy);
          s.hero.finishAim(false);
        } else {
          s.hero.skill();
        }

        expect(s.riding, isNull);
        expect(s.hero.body.size, Guardian.onFootSize);
        expect(s.progress.energy, energy - def.cost);
        expect(s.hero.cooldowns[def.id], greaterThan(0));
        expect(s.texts.where((text) => text.label.endsWith(' 부족')), isEmpty);
      },
    );
  }
}
