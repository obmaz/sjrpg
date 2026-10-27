import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _Camera extends BonfireCamera {
  ui.Rect view = const ui.Rect.fromLTWH(0, 0, 300, 300);
  @override
  ui.Rect get visibleWorldRect => view;
}

class _Game extends TestGame {
  @override
  final _Camera camera = _Camera();
  @override
  bool isVisibleInCamera(PositionComponent component) =>
      camera.view.overlaps(component.toRect());
}

class _Enemy extends HuntEnemy {
  _Enemy(super.session, super.kind, super.at, {super.boss, super.trait});
  int draws = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }
}

class _Prop extends WoodlandProp {
  _Prop(super.session, super.prop);
  int draws = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }
}

Future<Uint8List> _raster(
  GameComponent component,
  ui.Rect view, {
  required bool culled,
}) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  canvas.clipRect(ui.Rect.fromLTWH(0, 0, view.width, view.height));
  canvas.translate(-view.left, -view.top);
  if (culled) {
    component.renderTree(canvas);
  } else {
    canvas.translate(component.position.x, component.position.y);
    component.render(canvas);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(view.width.ceil(), view.height.ceil());
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bytes = Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  image.dispose();
  return bytes;
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

  Adventure session(_Game game, {WorldStage stage = WorldStage.forest}) {
    final s = Adventure(art, stage: stage)..start(game);
    addTearDown(s.dispose);
    return s;
  }

  test(
    'offscreen world actors skip real drawing while enemy time advances',
    () {
      final game = _Game(), s = session(game);
      final enemies = [
        for (var i = 0; i < 40; i++)
          _Enemy(s, 'goblin', ui.Offset(6000 + i * 30, 4200))
            ..gameRef = game
            ..combatReady = true,
      ];
      final props = [
        for (var i = 0; i < 64; i++)
          _Prop(
            s,
            WorldProp(
              ui.Rect.fromLTWH(6000 + i * 30, 4300, 40, 30),
              'tree',
              const ui.Size(100, 160),
            ),
          )..gameRef = game,
      ];
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      for (final component in [...enemies, ...props]) {
        component.renderTree(canvas);
      }
      expect(
        [
          enemies.fold(0, (n, e) => n + e.draws),
          props.fold(0, (n, p) => n + p.draws),
        ],
        [0, 0],
      );
      final enemy = enemies.first..stun = .5;
      final position = enemy.position.clone();
      enemy.update(1 / 30);
      expect(enemy.stun, closeTo(.5 - 1 / 30, .000001));
      expect(enemy.position, position);
      game.camera.view = const ui.Rect.fromLTWH(5800, 4000, 2400, 500);
      for (final component in [...enemies, ...props]) {
        component.renderTree(canvas);
      }
      expect(enemies.fold(0, (n, e) => n + e.draws), 40);
      expect(props.fold(0, (n, p) => n + p.draws), 64);
      recorder.endRecording().dispose();
    },
  );

  test('culled enemies preserve Bonfire visibility-cache refreshes', () {
    final game = _Game(), s = session(game);
    final enemy = _Enemy(s, 'goblin', const ui.Offset(6000, 4200))
      ..gameRef = game;
    expect(enemy.isVisible, false);
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    for (var frame = 0; frame < 6; frame++) {
      enemy.renderTree(canvas);
    }
    game.camera.view = enemy.body.inflate(1);
    expect(enemy.isVisible, true);
    expect(enemy.draws, 0);
    recorder.endRecording().dispose();
  });

  Future<void> expectSameVisiblePixels(
    _Game game,
    GameComponent component,
    ui.Rect view,
  ) async {
    game.camera.view = view;
    final expected = await _raster(component, view, culled: false);
    final actual = await _raster(component, view, culled: true);
    expect(
      [
        for (var i = 3; i < expected.length; i += 4) expected[i],
      ].any((alpha) => alpha > 0),
      true,
      reason: 'the edge fixture must contain visible pixels',
    );
    expect(actual, expected);
  }

  for (final stage in WorldStage.values) {
    test('$stage boss art, recoil and name plate retain their pixels', () async {
      final game = _Game(), s = session(game, stage: stage);
      final boss = _Enemy(s, 'golem', const ui.Offset(6000, 4200), boss: true)
        ..gameRef = game
        ..slow = .5;
      boss.motion.hit(const ui.Offset(30, 0));
      boss.motion.update(.05, distance: 2, bearing: 0);
      boss.attackMotion.strike(EnemyAttackPose.melee, 0);
      for (var direction = 0; direction < 8; direction++) {
        boss.bearing = direction * math.pi / 4;
        boss.motion.facing = boss.bearing;
        await expectSameVisiblePixels(
          game,
          boss,
          const ui.Rect.fromLTWH(5900, 4020, 200, 250),
        );
      }
      // Only the name/status area is onscreen; the collision body is below it.
      await expectSameVisiblePixels(
        game,
        boss,
        const ui.Rect.fromLTWH(5940, 4050, 170, 60),
      );
    });
  }

  test('telegraph edges stay visible beyond the enemy body', () async {
    final game = _Game(), s = session(game);
    final pouncer = _Enemy(s, 'wolf', const ui.Offset(6000, 4200))
      ..gameRef = game
      ..windup = .2;
    pouncer.pounceGoal = pouncer.body.center + const ui.Offset(240, 0);
    await expectSameVisiblePixels(
      game,
      pouncer,
      const ui.Rect.fromLTWH(6230, 4195, 35, 35),
    );
    final gunner = _Enemy(s, 'gunner', const ui.Offset(6000, 4200))
      ..gameRef = game
      ..windup = .001
      ..bearing = 0;
    await expectSameVisiblePixels(
      game,
      gunner,
      const ui.Rect.fromLTWH(6240, 4200, 40, 25),
    );
    final troll = _Enemy(s, 'troll', const ui.Offset(6000, 4200))
      ..gameRef = game
      ..windup = .2
      ..bearing = 0;
    await expectSameVisiblePixels(
      game,
      troll,
      const ui.Rect.fromLTWH(6115, 4200, 25, 30),
    );
    final elite = _Enemy(
      s,
      'goblin',
      const ui.Offset(6000, 4200),
      trait: EnemyTrait.armored,
    )..gameRef = game;
    await expectSameVisiblePixels(
      game,
      elite,
      const ui.Rect.fromLTWH(5960, 4140, 90, 30),
    );
  });

  for (final kind in ['tree', 'rock', 'cactus', 'ruin-0', 'city-0', 'relay']) {
    test('$kind crown remains visible above an offscreen prop body', () async {
      final game = _Game(), s = session(game);
      final prop = _Prop(
        s,
        WorldProp(
          const ui.Rect.fromLTWH(6000, 4200, 50, 40),
          kind,
          const ui.Size(140, 300),
        ),
      )..gameRef = game;
      await expectSameVisiblePixels(
        game,
        prop,
        const ui.Rect.fromLTWH(5900, 3950, 250, 150),
      );
    });
  }
}
