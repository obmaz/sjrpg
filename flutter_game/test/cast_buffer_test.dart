import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt(), heroClass: HeroClass.mage)..start(TestGame());
    s.mobs.clear();
    s.progress.gainXp(1000);
    for (final id in [
      'arcaneMastery',
      'chainLightning',
      'warmth',
      'warmth',
      'iceArmor',
      'meteor',
    ]) {
      expect(
        s.progress.learn(s.progress.skills.firstWhere((v) => v.id == id)),
        true,
      );
    }
    s.progress.selectSkill('frostNova');
    s.progress.energy = s.progress.maxEnergy;
  });
  tearDown(() => s.dispose());
  void step(int count) {
    for (var i = 0; i < count; i++) {
      s.hero.update(.05);
    }
  }

  test(
    'a skill tapped during a basic cast fires once before the next held attack',
    () {
      final energy = s.progress.energy;
      s.hero.slash();
      s.holdAttack('test', true);
      s.hero.skill();
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(s.progress.energy, energy);
      step(6);
      expect(s.hero.cooldowns['frostNova'], 6);
      expect(s.progress.energy, energy - 18);
      final cooldown = s.hero.cooldowns['frostNova']!;
      step(3);
      expect(s.hero.cooldowns['frostNova'], lessThan(cooldown));
      expect(s.progress.energy, energy - 18);
    },
  );
  test(
    'rapid taps retain only the last valid spell and keep individual cooldowns',
    () {
      final energy = s.progress.energy;
      s.hero.slash();
      s.hero.skill(slot: 0);
      s.hero.skill(slot: 1);
      step(6);
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(s.hero.cooldowns['chainLightning'], 5);
      expect(s.progress.energy, energy - 28);
    },
  );
  for (final action in ['pause', 'roll', 'reset', 'slot']) {
    test('$action cancels a pending cast without spending its resource', () {
      s.progress.energy = 60;
      final energy = s.progress.energy;
      s.hero.slash();
      s.hero.skill();
      switch (action) {
        case 'pause':
          s.pause();
          s.resume();
        case 'roll':
          s.hero.dodge();
        case 'reset':
          s.progress.gold = 10000;
          expect(s.resetSkills(), true);
        case 'slot':
          s.progress.selectSkill('meteor');
      }
      step(15);
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(s.hero.cooldowns['meteor'], isNull);
      expect(s.progress.energy, energy);
    });
  }
  test('resource is checked again when the pending cast can execute', () {
    s.hero.slash();
    s.hero.skill();
    s.progress.energy = 0;
    step(6);
    expect(s.hero.cooldowns['frostNova'], isNull);
    expect(s.progress.energy, 0);
  });
  test(
    'basic bolt waits for the release pose, follows the casting origin and pauses with the hero',
    () {
      final game = TestGame();
      final mage = Adventure(GameArt(), heroClass: HeroClass.mage)..start(game);
      addTearDown(mage.dispose);
      mage.mobs.clear();
      mage.hero.position.setValues(6000, 4200);
      mage.hero.slash();
      final bolt = game.added.whereType<ArcaneBolt>().single;
      final origin = bolt.position.clone();
      mage.hero.update(.05);
      bolt.update(.05);
      expect(bolt.position, origin);
      expect(bolt.remaining, .88);
      mage.pause();
      bolt.update(.5);
      expect(bolt.launchDelay, closeTo(.08, .001));
      mage.resume();
      mage.hero.position.x += 20;
      for (var i = 0; i < 2; i++) {
        mage.hero.update(.05);
        bolt.update(.05);
      }
      expect(bolt.launchDelay, 0);
      expect(bolt.position.x, closeTo(mage.hero.body.center.dx, .001));
      expect(bolt.position.y, greaterThan(mage.hero.body.center.dy));
      expect(mage.hero.swing, lessThan(mage.hero.swingDuration * .58));
    },
  );
  test('rolling cancels an unreleased basic bolt', () {
    final game = TestGame();
    final mage = Adventure(GameArt(), heroClass: HeroClass.mage)..start(game);
    addTearDown(mage.dispose);
    mage.mobs.clear();
    mage.hero.slash();
    final bolt = game.added.whereType<ArcaneBolt>().single;
    mage.hero.dodge();
    bolt.update(.05);
    expect(bolt.resolved, true);
  });
}
