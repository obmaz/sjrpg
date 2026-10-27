import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mage_combat_art.dart';

import 'support/test_game.dart';

Future<Uint8List> raster(
  void Function(ui.Canvas) draw, {
  int side = 320,
}) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();
  return bytes;
}

int alphaSum(Uint8List bytes) {
  var sum = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    sum += bytes[i];
  }
  return sum;
}

class _Camera extends BonfireCamera {
  ui.Rect visible = const ui.Rect.fromLTWH(0, 0, 10, 10);
  @override
  ui.Rect get visibleWorldRect => visible;
}

class _Game extends TestGame {
  @override
  final _Camera camera = _Camera();
}

class _Contact extends MageContact {
  _Contact(
    super.session,
    super.at, {
    required super.element,
    required super.radius,
  });
  int draws = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final element in MageElement.values) {
    test(
      '$element flight and contact evolve instead of translating a still image',
      () async {
        final flightHashes = <int>{}, contactHashes = <int>{};
        for (var i = 0; i < 8; i++) {
          final art = MageCombatArt(), t = i * .07;
          flightHashes.add(
            Object.hashAll(
              await raster(
                (c) => art.projectile(
                  c,
                  const ui.Offset(180, 160),
                  .25,
                  t,
                  element,
                  3,
                ),
              ),
            ),
          );
          contactHashes.add(
            Object.hashAll(
              await raster(
                (c) => art.impact(
                  c,
                  const ui.Offset(160, 180),
                  .03 + i * .12,
                  90,
                  element,
                  3,
                ),
              ),
            ),
          );
        }
        expect(flightHashes, hasLength(8));
        expect(contactHashes, hasLength(8));
        expect(
          alphaSum(
            await raster(
              (c) => MageCombatArt().impact(
                c,
                const ui.Offset(160, 180),
                1,
                90,
                element,
                5,
              ),
            ),
          ),
          0,
        );
      },
    );
    test(
      '$element gains visible detail at every rank without widening its hitbox',
      () async {
        for (final impact in [false, true]) {
          final hashes = <int>{}, brightness = <int>[];
          for (var rank = 1; rank <= 5; rank++) {
            final art = MageCombatArt();
            final bytes = await raster(
              (c) => impact
                  ? art.impact(
                      c,
                      const ui.Offset(160, 180),
                      .24,
                      90,
                      element,
                      rank,
                    )
                  : art.projectile(
                      c,
                      const ui.Offset(180, 160),
                      .25,
                      .17,
                      element,
                      rank,
                    ),
            );
            hashes.add(Object.hashAll(bytes));
            brightness.add(alphaSum(bytes));
          }
          expect(hashes, hasLength(5));
          expect(brightness.last, greaterThan(brightness.first));
        }
      },
    );
    test(
      '$element emission gathers before the projectile starts moving',
      () async {
        final first = await raster(
          (c) => MageCombatArt().charge(
            c,
            const ui.Offset(160, 160),
            element,
            0,
            3,
          ),
        );
        final last = await raster(
          (c) => MageCombatArt().charge(
            c,
            const ui.Offset(160, 160),
            element,
            1,
            3,
          ),
        );
        expect(alphaSum(last), greaterThan(alphaSum(first)));
        expect(Object.hashAll(first), isNot(Object.hashAll(last)));
      },
    );
  }
  test(
    'three projectile elements keep distinct silhouettes at the same moment',
    () async {
      final hashes = <int>{};
      for (final element in MageElement.values) {
        hashes.add(
          Object.hashAll(
            await raster(
              (c) => MageCombatArt().projectile(
                c,
                const ui.Offset(180, 160),
                0,
                .15,
                element,
                1,
              ),
            ),
          ),
        );
      }
      expect(hashes, hasLength(3));
    },
  );
  test(
    'reused glow paint does not leak a prior charge alpha into a shot',
    () async {
      for (final element in [MageElement.fire, MageElement.ice]) {
        final art = MageCombatArt(), discarded = ui.PictureRecorder();
        art.charge(
          ui.Canvas(discarded),
          const ui.Offset(160, 160),
          element,
          .2,
          3,
        );
        discarded.endRecording().dispose();
        final reused = await raster(
          (c) =>
              art.projectile(c, const ui.Offset(180, 160), 0, .17, element, 3),
        );
        final fresh = await raster(
          (c) => MageCombatArt().projectile(
            c,
            const ui.Offset(180, 160),
            0,
            .17,
            element,
            3,
          ),
        );
        expect(reused, orderedEquals(fresh));
      }
    },
  );
  test(
    'an arc for a different pair never inherits another pair afterimage',
    () async {
      final arc = ElectricArcArt(), discarded = ui.PictureRecorder();
      arc.paint(
        ui.Canvas(discarded),
        const ui.Offset(20, 30),
        const ui.Offset(90, 60),
        .1,
        rank: 5,
      );
      discarded.endRecording().dispose();
      final bytes = await raster(
        (c) => arc.paint(
          c,
          const ui.Offset(230, 230),
          const ui.Offset(290, 240),
          .15,
          rank: 5,
        ),
      );
      for (var y = 0; y < 140; y++) {
        for (var x = 0; x < 140; x++) {
          expect(bytes[(y * 320 + x) * 4 + 3], 0);
        }
      }
      expect(alphaSum(bytes), greaterThan(0));
    },
  );
  test(
    'all directional projectile pixels fit their full culling bounds',
    () async {
      const at = ui.Offset(160, 160);
      for (final element in MageElement.values) {
        for (var direction = 0; direction < 8; direction++) {
          final angle = direction * math.pi / 4;
          final bytes = await raster(
            (c) => MageCombatArt().projectile(
              c,
              at - const ui.Offset(0, 14),
              angle,
              .17,
              element,
              5,
            ),
          );
          for (var i = 3; i < bytes.length; i += 4) {
            if (bytes[i] < 3) continue;
            final x = ((i ~/ 4) % 320).toDouble(),
                y = ((i ~/ 4) ~/ 320).toDouble();
            expect(
              (ui.Offset(x, y) - at).distance,
              lessThan(140),
              reason: '$element facing $direction',
            );
          }
        }
      }
    },
  );
  test(
    'expanded contact bounds contain the final rank debris and arcs',
    () async {
      const at = ui.Offset(160, 180);
      final bounds = MageCombatArt.impactBounds(at, 85);
      for (final element in MageElement.values) {
        for (final phase in [.04, .2, .45, .75, .95]) {
          final bytes = await raster(
            (c) => MageCombatArt().impact(c, at, phase, 85, element, 5),
          );
          for (var i = 3; i < bytes.length; i += 4) {
            if (bytes[i] < 3) continue;
            final pixel = ui.Offset(
              ((i ~/ 4) % 320).toDouble(),
              ((i ~/ 4) ~/ 320).toDouble(),
            );
            expect(bounds.contains(pixel), true, reason: '$element at $phase');
          }
        }
      }
    },
  );
  test(
    'contact animation pauses, expires once and never deals another hit',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      final mob = s.spawnEnemy('goblin', const ui.Offset(6100, 4200))!
        ..life.initial(1000);
      final hp = mob.life.value, energy = s.progress.energy;
      final contact = MageContact(
        s,
        mob.body.center,
        element: MageElement.lightning,
        radius: 85,
        rank: 5,
      );
      contact.update(.05);
      s.pause();
      contact.update(.05);
      expect(contact.age, .05);
      s.resume();
      for (var i = 0; i < 30; i++) {
        contact.update(.05);
      }
      expect(contact.finished, true);
      expect(contact.age, MageContact.duration);
      expect(mob.life.value, hp);
      expect(s.progress.energy, energy);
      expect(s.hero.cooldowns, isEmpty);
    },
  );
  test('contact animation stops when the underlying skill build changes', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    final contact = MageContact(
      s,
      s.hero.body.center,
      element: MageElement.fire,
      radius: 34,
    );
    s.buildRevision++;
    contact.update(.05);
    expect(contact.finished, true);
    expect(contact.age, 0);
  });
  test(
    'offscreen contact still advances while a visible edge remains drawable',
    () {
      final game = _Game(),
          s = inCombatField(Adventure(GameArt()))..start(game);
      addTearDown(s.dispose);
      final contact = _Contact(
        s,
        const ui.Offset(6000, 4200),
        element: MageElement.lightning,
        radius: 85,
      )..gameRef = game;
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      contact.renderTree(canvas);
      expect(contact.draws, 0);
      contact.update(.05);
      expect(contact.age, .05);
      game.camera.visible = const ui.Rect.fromLTWH(5850, 4180, 30, 30);
      contact.renderTree(canvas);
      expect(contact.draws, 1);
      recorder.endRecording().dispose();
    },
  );
  for (final element in ['fire', 'ice', 'lightning']) {
    test(
      '$element contact replaces only visuals and retains one actual projectile hit',
      () {
        final game = TestGame(),
            s = inCombatField(Adventure(GameArt()))..start(game);
        addTearDown(s.dispose);
        s.mobs.clear();
        final mob = s.spawnEnemy('goblin', const ui.Offset(6080, 4200))!
          ..life.initial(1000);
        final bolt = ArcaneBolt(
          s,
          s.hero.body.center,
          0,
          100,
          element: element,
        );
        for (var i = 0; i < 20; i++) {
          bolt.update(.05);
        }
        expect(bolt.resolved, true);
        expect(mob.life.value, 900);
        final contact = game.added.whereType<MageContact>().single;
        expect(contact.element, MageElement.fromStyle(element));
        for (var i = 0; i < 20; i++) {
          contact.update(.05);
          bolt.update(.05);
        }
        expect(mob.life.value, 900);
      },
    );
  }
}
