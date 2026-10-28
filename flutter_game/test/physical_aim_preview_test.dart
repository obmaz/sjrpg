import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
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
    Object? bossPose,
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

  Adventure session(GameArt art, String skill) {
    final s = inCombatField(Adventure(art))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.progress.gainXp(8000);
    s.progress.ranks[skill] = 1;
    s.progress.selectSkill(skill);
    s.progress.energy = s.progress.maxEnergy;
    s.hero.bearing = 0;
    return s;
  }

  Future<Uint8List> raster(
    void Function(ui.Canvas) paint, [
    String? name,
  ]) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(256, 256);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
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
      pixels[((point.dy + 256).round() * 512 + (point.dx + 256).round()) * 4 +
          3];

  test('held heavy attack uses its raised weapon pose and manual facing', () {
    final poseArt = _PoseArt(), s = session(poseArt, 'crushingBlow');
    s.hero.strikePose = 0;
    s.hero.beginAim(0);
    s.hero.moveAim(const ui.Offset(0, -40));
    final recorder = ui.PictureRecorder();
    s.hero.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
    expect(poseArt.attacking, true);
    expect(poseArt.pose, 2);
    expect(poseArt.angle, closeTo(-math.pi / 2, .00001));
    expect(
      s.hero.heavyWindup,
      0,
      reason: 'holding has not committed the skill',
    );
  });

  for (final skill in ['crushingBlow', 'charge']) {
    test(
      '$skill native aim pixels do not depend on seismic slam rank',
      () async {
        final s = session(art, skill);
        s.hero.beginAim(0);
        s.hero.moveAim(const ui.Offset(50, 0));
        void paint(ui.Canvas canvas) {
          canvas.drawColor(const ui.Color(0xff314436), ui.BlendMode.src);
          s.hero.render(canvas);
        }

        final before = await raster(paint, 'aim-$skill');
        s.progress.ranks['seismicSlam'] = 5;
        expect(await raster(paint), orderedEquals(before));
      },
    );
  }

  test(
    'heavy preview contains exactly the tested front cone hit positions',
    () async {
      final s = session(art, 'crushingBlow');
      final center = s.hero.body.center;
      final points = [
        const ui.Offset(120, 50),
        const ui.Offset(200, 0),
        const ui.Offset(-80, 0),
        const ui.Offset(30, 110),
      ];
      final enemies = [
        for (final point in points)
          s.spawnEnemy('goblin', center + point - const ui.Offset(12, 11))!
            ..life.initial(500),
      ];
      final aim = SkillAim(0, 'crushingBlow', 0)
        ..delta = const ui.Offset(50, 0);
      final pixels = await raster(
        (canvas) => paintPhysicalAimPreview(canvas, ui.Offset.zero, aim),
      );
      final expected = [true, false, false, false];
      for (var i = 0; i < points.length; i++) {
        expect(
          alphaAt(pixels, enemies[i].body.center - center) > 0,
          expected[i],
        );
      }
      s.hero.beginAim(0);
      s.hero.moveAim(const ui.Offset(50, 0));
      s.hero.finishAim(false);
      final windup = s.hero.heavyWindup;
      expect(windup, greaterThan(0));
      for (var i = 0; i < math.max(0, (windup / .05).ceil() - 1); i++) {
        s.hero.update(.05);
      }
      expect(s.hero.heavyWindup, greaterThan(0));
      expect(enemies.every((enemy) => enemy.life.value == 500), true);
      final remaining = s.hero.heavyWindup;
      for (
        var i = 0;
        i < (remaining / .05).ceil() + 1 && s.hero.heavyWindup > 0;
        i++
      ) {
        s.hero.update(.05);
      }
      expect(s.hero.heavyWindup, 0);
      for (var i = 0; i < enemies.length; i++) {
        expect(enemies[i].life.value < 500, expected[i]);
      }
    },
  );

  test(
    'charge shows direction without a remote damage circle and cancellation stays red',
    () async {
      final s = session(art, 'charge');
      s.hero.beginAim(0);
      s.hero.moveAim(const ui.Offset(50, 0));
      final aim = s.hero.aim!;
      final pixels = await raster(
        (canvas) => paintPhysicalAimPreview(canvas, ui.Offset.zero, aim),
      );
      expect(alphaAt(pixels, const ui.Offset(60, 0)), greaterThan(0));
      expect(alphaAt(pixels, const ui.Offset(100, 80)), 0);
      final energy = s.progress.energy;
      s.hero.moveAim(const ui.Offset(160, 0));
      final cancelled = await raster(
        (canvas) => paintPhysicalAimPreview(canvas, ui.Offset.zero, aim),
      );
      final at = (256 * 512 + 316) * 4;
      expect(cancelled[at], greaterThan(cancelled[at + 1]));
      s.hero.finishAim(false);
      expect(s.progress.energy, energy);
      expect(s.hero.chargeTime, 0);
      expect(s.hero.cooldowns['charge'], isNull);
    },
  );

  test('undragged charge arrow follows the facing used on release', () async {
    final s = session(art, 'charge');
    s.hero.beginAim(0);
    s.hero.bearing = math.pi;
    final pixels = await raster(s.hero.render);
    final origin =
        s.hero.body.center - ui.Offset(s.hero.position.x, s.hero.position.y);
    expect(alphaAt(pixels, origin + const ui.Offset(-60, 0)), greaterThan(0));
    expect(alphaAt(pixels, origin + const ui.Offset(60, 0)), 0);
    s.hero.finishAim(false);
    expect(s.hero.chargeAngle, math.pi);
    expect(s.hero.chargeTime, greaterThan(0));
  });
}
