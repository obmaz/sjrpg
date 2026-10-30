import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/health_feedback.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt())..start(TestGame());
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
  });
  tearDown(() => s.dispose());

  test(
    'damage lands now, knockback eases, and pause freezes both feedbacks',
    () {
      final mob = s.spawnEnemy('goblin', const Offset(6180, 4200))!..stun = 2;
      final life = mob.life.value, at = mob.position.toOffset();
      s.hit(mob, 10, const Offset(42, 0));
      expect(mob.life.value, life - 10);
      expect(mob.position.toOffset(), at);
      s.pause();
      mob.update(.5);
      expect(mob.position.toOffset(), at);
      expect(mob.damageTrail.value, 1);
      s.resume();
      mob.update(1 / 60);
      expect(mob.position.x, inExclusiveRange(at.dx, at.dx + 42));
      expect(mob.motion.stride, 0, reason: 'recoil must not animate walking');
      for (var i = 0; i < 12; i++) {
        mob.update(1 / 60);
        expect(s.world.blocked(mob.body), false);
      }
      expect(mob.position.x, closeTo(at.dx + 42, .001));
      expect(mob.damageTrail.value, greaterThan(mob.life.value / mob.life.max));
      for (var i = 0; i < 60; i++) {
        mob.update(1 / 60);
      }
      expect(mob.position.x, closeTo(at.dx + 42, .001));
      expect(mob.damageTrail.value, mob.life.value / mob.life.max);
    },
  );
  test(
    'knockback reaches the same position at 30 and 60 frames per second',
    () {
      final slow = s.spawnEnemy('goblin', const Offset(6180, 4200))!..stun = 3;
      final fast = s.spawnEnemy('goblin', const Offset(6180, 4260))!..stun = 3;
      for (final (mob, frames) in [(slow, 6), (fast, 12)]) {
        s.hit(mob, 1, const Offset(42, 0));
        for (var i = 0; i < frames; i++) {
          mob.update(.2 / frames);
        }
      }
      expect(slow.position.x, closeTo(6222, .001));
      expect(fast.position.x, closeTo(slow.position.x, .001));
    },
  );
  test(
    'repeated pushes are bounded and cannot pass a tree or world boundary',
    () {
      final tree = s.world.props.firstWhere(
        (p) =>
            p.kind == 'tree' &&
            !s.world.blocked(
              Rect.fromLTWH(p.body.left - 44, p.body.top, 24, 22),
            ),
      );
      final mob = s.spawnEnemy(
        'goblin',
        Offset(tree.body.left - 44, tree.body.top),
      )!..stun = 3;
      for (var i = 0; i < 20; i++) {
        s.hit(mob, .001, const Offset(42, 0));
      }
      final from = mob.position.toOffset();
      for (var i = 0; i < 20; i++) {
        mob.update(.02);
        expect(s.world.blocked(mob.body), false);
        expect(mob.body.right, lessThanOrEqualTo(tree.body.left + .001));
      }
      expect((mob.position.toOffset() - from).distance, lessThanOrEqualTo(80));
      final edge = s.spawnEnemy('goblin', const Offset(20, 100))!..stun = 3;
      s.hit(edge, 1, const Offset(-60, 0));
      for (var i = 0; i < 12; i++) {
        edge.update(.02);
        expect(s.world.blocked(edge.body), false);
      }
      expect(edge.position.x, greaterThanOrEqualTo(0));
    },
  );
  test('restored and healed health never displays a false damage trail', () {
    final trail = DamageTrail()..update(0, .3);
    expect(trail.value, .3);
    trail.damage(.3, .1);
    trail.update(.05, .1);
    expect(trail.value, .3);
    trail.update(.05, .7);
    expect(trail.value, .7);
    trail.damage(.7, .5);
    trail.update(.12, .5);
    expect(trail.value, .7);
    trail.update(.05, .5);
    expect(trail.value, inExclusiveRange(.5, .7));
    trail.damage(.5, .2);
    trail.update(.05, .2);
    expect(trail.value, greaterThan(.5));
    trail.update(1, .2);
    expect(trail.value, .2);
  });
  test(
    'the rendered bar shows lost health briefly without covering real health',
    () async {
      final art = await GameArt.load(),
          rendered = Adventure(art)..start(TestGame());
      addTearDown(() {
        rendered.dispose();
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in art.images.values) {
          image.dispose();
        }
      });
      rendered.mobs.clear();
      rendered.hero.position.setValues(6000, 4200);
      final mob = rendered.spawnEnemy('goblin', const Offset(6180, 4200))!
        ..life.initial(500)
        ..stun = 2;
      rendered.hit(mob, 100, Offset.zero);
      Future<List<int>> pixel(int x, int y) async {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.translate(100, 200);
        mob.render(canvas);
        final picture = recorder.endRecording(),
            image = await picture.toImage(200, 240);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (y * 200 + x) * 4;
        final result = [for (var i = 0; i < 3; i++) data.getUint8(offset + i)];
        image.dispose();
        return result;
      }

      final barY = (200 - 88 * HuntEnemy.visualScale + 3).round();
      expect(await pixel(133, barY), [255, 216, 149]);
      expect(await pixel(110, barY), [173, 36, 32]);
      for (var i = 0; i < 40; i++) {
        mob.update(.02);
      }
      expect(await pixel(133, barY), isNot([255, 216, 149]));
      expect(await pixel(110, barY), [173, 36, 32]);
      expect(mob.life.value, 400);
    },
  );
}
