import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/skill_aim.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

class ControlArt extends GameArt {
  @override
  void control(ui.Canvas canvas, String key, ui.Rect destination) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late TestGame game;
  setUp(() {
    s = Adventure(GameArt(), heroClass: HeroClass.mage);
    game = TestGame();
    s.start(game);
    s.progress.gainXp(1000);
    for (final id in [
      'firebolt',
      'emberFocus',
      'arcaneMastery',
      'chainLightning',
      'iceArmor',
      'meteor',
    ]) {
      expect(
        s.progress.learn(s.progress.skills.firstWhere((d) => d.id == id)),
        true,
      );
    }
    s.progress.selectSkill('meteor');
    s.hero.position.setValues(6000, 4200);
    s.mobs.clear();
  });
  tearDown(() => s.dispose());

  test(
    'phone targeting stays visible and wider screens retain the skill range',
    () {
      final aim = SkillAim(3, 'meteor', 0)..delta = const Offset(74, 0);
      expect(aim.distanceWithin(const Size(390, 844)), 171);
      expect(aim.distanceWithin(const Size(1280, 800)), 450);
      aim.delta = const Offset(-74, 0);
      expect(
        aim.distanceWithin(
          const Size(390, 844),
          screenOrigin: const Offset(35, 422),
        ),
        11,
      );
      aim.delta = const Offset(0, -74);
      expect(aim.distanceWithin(const Size(390, 844)), 278);
      expect(aim.distanceWithin(const Size(320, 420), cameraOffsetY: 36), 69);
    },
  );

  test(
    'dragged meteor follows the chosen direction rather than a nearby enemy',
    () {
      s.spawnEnemy('goblin', const Offset(5880, 4200));
      final energy = s.progress.energy;
      s.hero.beginAim(0);
      s.hero.moveAim(const Offset(74, 0));
      expect(s.progress.energy, energy);
      expect(game.added.whereType<MeteorFall>(), isEmpty);
      s.hero.finishAim(false);
      final meteor = game.added.whereType<MeteorFall>().single;
      expect(meteor.target.dx, greaterThan(s.hero.body.center.dx));
      expect(meteor.target.dy, s.hero.body.center.dy);
      expect(s.progress.energy, energy - 38);
      expect(s.hero.aim, null);
      s.hero.finishAim(false);
      expect(game.added.whereType<MeteorFall>().length, 1);
    },
  );

  test('tap keeps auto aim and cancellation or pause spends no resource', () {
    final enemy = s.spawnEnemy('goblin', const Offset(5880, 4200))!;
    final energy = s.progress.energy;
    s.hero.beginAim(0);
    s.hero.moveAim(const Offset(0, -180));
    s.hero.finishAim(false);
    expect(s.progress.energy, energy);
    s.hero.beginAim(0);
    s.hero.moveAim(const Offset(0, -60));
    s.pause();
    s.hero.finishAim(false);
    expect(s.progress.energy, energy);
    expect(game.added.whereType<MeteorFall>(), isEmpty);
    s.resume();
    s.hero.beginAim(0);
    s.hero.moveAim(const Offset(3, 2));
    s.hero.finishAim(false);
    expect(game.added.whereType<MeteorFall>().single.target, enemy.body.center);
  });

  test(
    'manual slam strikes the aimed side while retaining movement direction',
    () {
      final warrior = Adventure(GameArt());
      warrior.start(TestGame());
      addTearDown(warrior.dispose);
      warrior.progress.gainXp(1000);
      for (final id in ['mastery', 'cleave', 'frenzy']) {
        expect(
          warrior.progress.learn(
            warrior.progress.skills.firstWhere((d) => d.id == id),
          ),
          true,
        );
      }
      expect(
        warrior.progress.learn(
          warrior.progress.skills.firstWhere((d) => d.id == 'whirlwind'),
        ),
        true,
      );
      warrior.progress.learn(
        warrior.progress.skills.firstWhere((d) => d.id == 'seismicSlam'),
      );
      warrior.progress.selectSkill('seismicSlam');
      warrior.progress.energy = 100;
      warrior.hero.position.setValues(6000, 4200);
      warrior.hero.bearing = 3.14;
      warrior.hero.velocity.setValues(-270, 0);
      warrior.mobs.clear();
      final left = warrior.spawnEnemy('skeleton', const Offset(5930, 4200))!;
      final right = warrior.spawnEnemy('skeleton', const Offset(6160, 4200))!;
      final leftHp = left.life.value, rightHp = right.life.value;
      warrior.hero.beginAim(0);
      warrior.hero.moveAim(const Offset(60, 0));
      warrior.hero.finishAim(false);
      expect(right.life.value, lessThan(rightHp));
      expect(left.life.value, leftHp);
      expect(warrior.hero.bearing, 3.14);
      expect(warrior.hero.velocity.x, -270);
    },
  );

  testWidgets(
    'skill touch defers casting until release and pointer cancellation cancels',
    (tester) async {
      var casts = 0;
      final ends = <bool>[];
      Offset? movement;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ActionButton(
              art: ControlArt(),
              sprite: 'roundEmpty',
              label: '',
              semanticLabel: '조준',
              size: 64,
              showLabel: false,
              onTap: () => casts++,
              onAimStart: () {},
              onAimMove: (delta) => movement = delta,
              onAimEnd: ends.add,
            ),
          ),
        ),
      );
      final at = tester.getCenter(find.byType(ActionButton));
      final gesture = await tester.startGesture(at);
      expect(casts, 0);
      await gesture.moveBy(const Offset(-50, -30));
      expect(movement, const Offset(-50, -30));
      await gesture.up();
      expect(ends, [false]);
      final cancelled = await tester.startGesture(at);
      await cancelled.cancel();
      expect(ends, [false, true]);
      expect(casts, 0);
    },
  );
}
