import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_combat.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/physical_aim_preview.dart';
import 'package:guardian_new/skill_aim.dart';

import 'support/test_game.dart';

class _PoseArt extends GameArt {
  int? pose;
  double? angle;
  bool? attacking;
  @override
  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    bool moving = false,
    int comboPose = 0,
    double? actionProgress,
    double? enemyAttackProgress,
    Object? bossPose,
    Object? walkPose,
    Object? mountPose,
    double opacity = 1,
    double flash = 0,
  }) {
    pose = comboPose;
    this.angle = angle;
    attacking = attack;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async => art = await GameArt.load());
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });

  final games = Expando<TestGame>();
  Adventure session(GameArt art, String skill) {
    final game = TestGame();
    final s = inCombatField(Adventure(art))..start(game);
    games[s] = game;
    addTearDown(s.dispose);
    s.mobs.clear();
    s.progress.level = 40;
    s.progress.ranks[skill] = 1;
    expect(s.progress.selectSkill(skill), true);
    s.progress.energy = s.progress.maxEnergy;
    s.hero.bearing = 0;
    return s;
  }

  Future<Uint8List> raster(
    void Function(ui.Canvas) paint, [
    String? name,
  ]) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(512, 512);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    picture.dispose();
    final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = Uint8List.fromList(raw.buffer.asUint8List());
    final directory = Platform.environment['PHYSICAL_AIM_PROOF_DIR'];
    if (directory != null && name != null) {
      await Directory(directory).create(recursive: true);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$directory/$name.png').writeAsBytes(png.buffer.asUint8List());
    }
    image.dispose();
    return result;
  }

  int alphaAt(Uint8List pixels, ui.Offset point) =>
      pixels[((point.dy + 512).round() * 1024 + (point.dx + 512).round()) * 4 +
          3];

  test(
    'held leap attack stays uncommitted and releases its weapon pose in the manual direction',
    () {
      final poseArt = _PoseArt(), s = session(poseArt, 'leapAttack');
      final energy = s.progress.energy;
      s.hero.beginAim(0);
      s.hero.moveAim(const ui.Offset(0, -40));
      expect(s.hero.aim, isNotNull);
      expect(s.hero.barbarianCombat.airborne, false);
      expect(s.progress.energy, energy);
      s.hero.finishAim(false);
      expect(s.hero.barbarianCombat.airborne, true);
      final recorder = ui.PictureRecorder();
      s.hero.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
      expect(poseArt.attacking, true);
      expect(poseArt.pose, 1);
      expect(poseArt.angle, closeTo(-math.pi / 2, .00001));
    },
  );

  for (final skill in ['leap', 'leapAttack', 'doubleThrow']) {
    test(
      '$skill native aim pixels are independent of unrelated Warcry ranks',
      () async {
        final s = session(art, skill);
        s.hero.beginAim(0);
        s.hero.moveAim(const ui.Offset(50, 0));
        void paint(ui.Canvas canvas) {
          canvas.drawColor(const ui.Color(0xff314436), ui.BlendMode.src);
          s.hero.render(canvas);
        }

        final before = await raster(paint, 'aim-$skill');
        s.progress.ranks['warcry'] = 20;
        expect(await raster(paint), orderedEquals(before));
      },
    );
  }

  test(
    'double throw preview and live projectiles agree on spread, direction and finite range',
    () async {
      final s = session(art, 'doubleThrow'), skill = s.progress.skillAt(0)!;
      final origin = s.hero.body.center, range = s.progress.skillRange(skill);
      final points = [
        const ui.Offset(120, 0),
        const ui.Offset(200, 80),
        const ui.Offset(-80, 0),
        ui.Offset(range + 45, 0),
      ];
      final enemies = [
        for (final point in points)
          s.spawnEnemy('goblin', origin + point - const ui.Offset(12, 11))!
            ..life.initial(500),
      ];
      final aim = SkillAim(0, 'doubleThrow', 0)..delta = const ui.Offset(50, 0);
      final bytes = await raster(
        (c) => paintBarbarianAimPreview(c, ui.Offset.zero, aim, range: range),
        'double-throw-range',
      );
      final firstLine = ui.Offset(
        math.cos(barbarianDoubleThrowHalfSpread) * 120,
        math.sin(barbarianDoubleThrowHalfSpread) * 120,
      );
      expect(alphaAt(bytes, firstLine), greaterThan(0));
      expect(alphaAt(bytes, const ui.Offset(100, 80)), 0);
      expect(alphaAt(bytes, const ui.Offset(-80, 0)), 0);
      expect(alphaAt(bytes, ui.Offset(range + 20, 0)), 0);
      s.hero.beginAim(0);
      s.hero.moveAim(const ui.Offset(50, 0));
      s.hero.finishAim(false);
      for (var tick = 0; tick < 24; tick++) {
        s.hero.update(.05);
        for (final axe
            in games[s]!.added.whereType<BarbarianThrownAxe>().toList()) {
          axe.update(.05);
        }
      }
      expect(enemies.first.life.value, lessThan(500));
      for (final enemy in enemies.skip(1)) {
        expect(enemy.life.value, 500);
      }
    },
  );

  test(
    'invalid leap landing is red and never draws an eligible footprint',
    () async {
      final aim = SkillAim(0, 'leap', 0)..delta = const ui.Offset(40, 0);
      final bytes = await raster(
        (c) => paintBarbarianAimPreview(c, ui.Offset.zero, aim, range: 300),
        'blocked-leap',
      );
      final distance = math.min(300.0, aim.distance),
          at = (512 * 1024 + (512 + distance).round()) * 4;
      expect(bytes[at], greaterThan(bytes[at + 1]));
      expect(alphaAt(bytes, ui.Offset(distance + 14, 12)), 0);
      final valid = await raster(
        (c) => paintBarbarianAimPreview(
          c,
          ui.Offset.zero,
          aim,
          range: 300,
          landing: const ui.Offset(180, 0),
        ),
      );
      expect(alphaAt(valid, const ui.Offset(166, -12)), greaterThan(0));
      expect(alphaAt(valid, const ui.Offset(194, 12)), greaterThan(0));
      expect(alphaAt(valid, const ui.Offset(180, 40)), 0);
    },
  );

  test(
    'cancelling a double throw keeps resources and creates no projectiles',
    () async {
      final s = session(art, 'doubleThrow');
      s.hero.beginAim(0);
      s.hero.moveAim(const ui.Offset(160, 0));
      final aim = s.hero.aim!, energy = s.progress.energy;
      final bytes = await raster(
        (c) => paintBarbarianAimPreview(c, ui.Offset.zero, aim, range: 420),
      );
      final at = ((512 + 2) * 1024 + 572) * 4;
      expect(bytes[at], greaterThan(bytes[at + 1]));
      s.hero.finishAim(false);
      expect(s.progress.energy, energy);
      expect(s.hero.cooldowns['doubleThrow'], isNull);
      expect(games[s]!.added.whereType<BarbarianThrownAxe>(), isEmpty);
    },
  );

  test(
    'undragged leap guide follows the same current facing as release',
    () async {
      final s = session(art, 'leap');
      s.hero.beginAim(0);
      s.hero.bearing = math.pi;
      final def = s.progress.skillAt(0)!, before = s.hero.body.topLeft;
      final landing = s.hero.barbarianCombat.previewLanding(
        def,
        aim: s.hero.aim,
      );
      expect(landing, isNotNull);
      expect(landing!.dx, lessThan(before.dx));
      final bytes = await raster(s.hero.render);
      final origin =
          s.hero.body.center - ui.Offset(s.hero.position.x, s.hero.position.y);
      expect(alphaAt(bytes, origin + const ui.Offset(-60, 0)), greaterThan(0));
      expect(alphaAt(bytes, origin + const ui.Offset(60, 0)), 0);
      s.hero.finishAim(false);
      expect(s.hero.barbarianCombat.airborne, true);
      s.hero.update(.05);
      expect(s.hero.position.x, lessThan(before.dx));
    },
  );
}
