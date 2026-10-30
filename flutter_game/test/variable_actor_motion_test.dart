import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

Map<String, dynamic> record(
  int count, {
  Map<String, dynamic>? motion,
  int groups = 1,
}) => {
  'frames': [
    for (var i = 0; i < count; i++) [i * 8, 0, 8, 12],
  ],
  'feet': [
    for (var i = 0; i < count; i++) [i * 8 + 3, 11],
  ],
  'sizes': [
    for (var i = 0; i < groups; i++) [8, 12],
  ],
  'motion': motion,
};
Map<String, dynamic> clip(int phases, String layout) => {
  'directions': 16,
  'runFrames': phases,
  'idleOffset': 0,
  'runOffset': 16,
  'layout': layout,
};
ui.Color color(int index) =>
    ui.Color.fromARGB(255, index, 255 - index, index * 53 % 256);
Future<ui.Image> sheet(int count) async {
  final recorder = ui.PictureRecorder();
  // One asymmetric cell for each true source slot; neighbors cannot look equal.
  final c = ui.Canvas(recorder);
  for (var i = 0; i < count; i++) {
    c.drawRect(
      ui.Rect.fromLTWH(i * 8.0, 0, 8, 12),
      ui.Paint()..color = color(i),
    );
    c.drawRect(
      ui.Rect.fromLTWH(i * 8.0, 0, 1, 12),
      ui.Paint()..color = const ui.Color(0xffff0000),
    );
  }
  final p = recorder.endRecording();
  final image = await p.toImage(count * 8, 12);
  p.dispose();
  return image;
}

Future<List<int>> raster(
  GameArt art,
  String key,
  double angle,
  int phase, {
  bool moving = false,
  bool attack = false,
  int comboPose = 0,
}) async {
  final recorder = ui.PictureRecorder();
  art.actor(
    ui.Canvas(recorder),
    key,
    const ui.Offset(5, 15),
    angle,
    phase,
    12,
    moving: moving,
    attack: attack,
    comboPose: comboPose,
  );
  final p = recorder.endRecording(), image = await recorderImage(p);
  p.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bytes = List<int>.of(data.buffer.asUint8List());
  image.dispose();
  return bytes;
}

Future<ui.Image> recorderImage(ui.Picture picture) => picture.toImage(16, 20);
void expectSlot(List<int> bytes, int index) {
  final sample = (7 * 16 + 5) * 4;
  final c = color(index);
  expect(bytes.sublist(sample, sample + 4), [
    (c.r * 255).round(),
    (c.g * 255).round(),
    (c.b * 255).round(),
    255,
  ]);
  // The source's asymmetric red marker stays left of the foot anchor at
  // the character and creature presentation scales.
  final leftMarkers =
      [
        for (var x = 0; x < 5; x++)
          bytes.sublist((7 * 16 + x) * 4, (7 * 16 + x) * 4 + 4),
      ].where(
        (edge) =>
            edge[3] == 255 &&
            edge[0] > (c.r * 255).round() + 10 &&
            edge[1] < (c.g * 255).round(),
      );
  expect(
    leftMarkers,
    isNotEmpty,
    reason: 'real direction frames must not mirror their asymmetric marker',
  );
}

class VariableArt extends GameArt {
  int phaseCount = 8;
  int? seenPhase;
  bool? seenMoving;
  @override
  int runFrameCount(String key) => phaseCount;
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
    Object? walkPose,
    Object? mountPose,
    double opacity = 1,
    double flash = 0,
  }) {
    if (key == 'hero') {
      seenPhase = phase;
      seenMoving = moving;
    }
  }
}

Future<List<int>> rasterRoll(
  GameArt art,
  double angle,
  int phase,
  bool mage,
) async {
  final recorder = ui.PictureRecorder();
  art.roll(
    ui.Canvas(recorder),
    const ui.Offset(50, 70),
    angle,
    phase,
    mage: mage,
  );
  final picture = recorder.endRecording(),
      image = await picture.toImage(100, 100);
  picture.dispose();
  final bytes = List<int>.of(
    (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List(),
  );
  image.dispose();
  return bytes;
}

ui.Rect alphaBounds(List<int> bytes) {
  var left = 100, top = 100, right = 0, bottom = 0;
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 100; x++) {
      if (bytes[(y * 100 + x) * 4 + 3] == 0) continue;
      left = math.min(left, x);
      right = math.max(right, x + 1);
      top = math.min(top, y);
      bottom = math.max(bottom, y + 1);
    }
  }
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final phases in [4, 6, 8]) {
    for (final layout in ['phase-major', 'direction-major']) {
      test(
        '$phases true phases×16 directions plus separate idle raster:$layout',
        () async {
          final total = 16 + 16 * phases,
              image = await sheet(total),
              art = GameArt();
          addTearDown(image.dispose);
          art.actors = {'hero': record(total, motion: clip(phases, layout))};
          art.images['actors-hero'] = image;
          expect(art.runFrameCount('hero'), phases);
          for (var d = 0; d < 16; d++) {
            final angle = math.pi / 2 + d * math.pi * 2 / 16;
            expect(facingFrame(angle, 16), d);
            expectSlot(await raster(art, 'hero', angle, phases + 2), d);
            for (var phase = 0; phase < phases; phase++) {
              final index =
                  16 +
                  (layout == 'phase-major'
                      ? phase * 16 + d
                      : d * phases + phase);
              expectSlot(
                await raster(art, 'hero', angle, phase + phases, moving: true),
                index,
              );
            }
          }
        },
      );
    }
  }
  test(
    'old hero/mage, grouped villagers, new enemies, mounts and swords retain correct two-pose mapping',
    () async {
      final image = await sheet(64), art = GameArt();
      addTearDown(image.dispose);
      art.actors = {
        for (final key in [
          'hero',
          'mage',
          'hero-attack',
          'hero-backhand',
          'hero-cleave',
        ])
          key: record(32),
        'villagers': record(64, groups: 4),
        'cinematic-skeleton': record(16),
        'horse': record(16),
      };
      art.images.addAll({
        for (final key in art.actors.keys) 'actors-$key': image,
      });
      expect(art.runFrameCount('hero'), 2);
      for (var d = 0; d < 16; d++) {
        for (var phase = 0; phase < 2; phase++) {
          final angle = math.pi / 2 + d * math.pi * 2 / 16;
          expectSlot(
            await raster(art, 'hero', angle, phase + 4, moving: true),
            phase * 16 + d,
          );
          expectSlot(
            await raster(art, 'mage', angle, phase + 4),
            phase * 16 + d,
          );
          for (var combo = 0; combo < 3; combo++) {
            expectSlot(
              await raster(
                art,
                'hero',
                angle,
                phase,
                attack: true,
                comboPose: combo,
              ),
              phase * 16 + d,
            );
          }
        }
      }
      for (var d = 0; d < 8; d++) {
        for (var phase = 0; phase < 2; phase++) {
          final angle = math.pi / 2 + d * math.pi * 2 / 8;
          expectSlot(
            await raster(art, 'villager', angle, phase),
            8 + d + phase * 32,
          );
          expectSlot(
            await raster(art, 'skeleton', angle, phase),
            d * 2 + phase,
          );
          expectSlot(await raster(art, 'horse', angle, phase), d * 2 + phase);
        }
      }
    },
  );
  test(
    'an opt-in run atlas still uses the separate original attack clips',
    () async {
      final image = await sheet(144), art = GameArt();
      addTearDown(image.dispose);
      art.actors = {
        'hero': record(144, motion: clip(8, 'phase-major')),
        for (final name in ['hero-attack', 'hero-backhand', 'hero-cleave'])
          name: record(32),
      };
      art.images.addAll({
        for (final key in art.actors.keys) 'actors-$key': image,
      });
      for (var direction = 0; direction < 16; direction++) {
        final angle = math.pi / 2 + direction * math.pi * 2 / 16;
        for (var pose = 0; pose < 3; pose++) {
          expectSlot(
            await raster(
              art,
              'hero',
              angle,
              1,
              moving: true,
              attack: true,
              comboPose: pose,
            ),
            16 + direction,
          );
        }
      }
    },
  );
  test('an eight-phase gait never walks in place against a blocked body', () {
    final art = VariableArt(),
        s = inCombatField(Adventure(art))..start(TestGame());
    addTearDown(s.dispose);
    s.hero.runMotion.advance(49);
    final size = s.hero.body.size;
    final tree = s.world.props.firstWhere(
      (p) =>
          p.kind == 'tree' &&
          !s.world.blocked(
            ui.Rect.fromLTWH(
              p.body.left - size.width,
              p.body.center.dy - size.height / 2,
              size.width,
              size.height,
            ),
          ),
    );
    s.hero.position.setValues(
      tree.body.left - size.width,
      tree.body.center.dy - size.height / 2,
    );
    final before = s.hero.runMotion.cycle;
    s.hero.moveRight();
    s.hero.update(1 / 144);
    final recorder = ui.PictureRecorder();
    s.hero.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
    expect(s.hero.runMotion.cycle, closeTo(before, .000001));
    expect(art.seenMoving, false);
    expect(art.seenPhase, 0);
  });
  for (final projected in [false, true]) {
    test(
      'roll8×4×2classes preserves selected origin mode:$projected',
      () async {
        final image = await sheet(64), art = GameArt();
        addTearDown(image.dispose);
        final r = record(64, groups: 2)
          ..['sizes'] = [
            [8, 43],
            [8, 43],
          ]
          ..['feet'] = [
            for (var i = 0; i < 64; i++) [i * 8 + 3, 16],
          ];
        if (projected) r['anchorMode'] = 'projected-origin';
        art.actors = {'roll': r};
        art.images['actors-roll'] = image;
        for (final mage in [false, true]) {
          for (var direction = 0; direction < 8; direction++) {
            final angle = math.pi / 2 + direction * math.pi * 2 / 8;
            for (var phase = 0; phase < 4; phase++) {
              final bytes = await rasterRoll(art, angle, phase, mage);
              final bounds = alphaBounds(bytes);
              expect(bounds.width, inInclusiveRange(8, 12));
              expect(bounds.height, inInclusiveRange(9, 13));
              expect(bounds.center.dx, closeTo(50, 1.5));
              expect(
                bounds.bottom,
                projected ? inInclusiveRange(66, 68) : 70,
                reason: 'the ground anchor stays fixed as the art shrinks',
              );
              expect(bytes[(70 * 100 + 50) * 4 + 3], 0);
              if (!projected) {
                expect(bytes[(69 * 100 + 50) * 4 + 3], 255);
              }
              final sample =
                  ((bounds.top.toInt() + 3) * 100 + bounds.left.toInt() + 3) *
                  4;
              final expected = color((mage ? 32 : 0) + phase * 8 + direction);
              expect(bytes.sublist(sample, sample + 4), [
                (expected.r * 255).round(),
                (expected.g * 255).round(),
                (expected.b * 255).round(),
                255,
              ]);
            }
          }
        }
      },
    );
  }
  test(
    'projected-origin metadata fails closed without real finite unmirrored anchors',
    () {
      final r = record(64, groups: 2)..['anchorMode'] = 'projected-origin';
      expect(ActorAtlas.fromJson(r).projectedOrigin, true);
      expect(
        () => ActorAtlas.fromJson({...r, 'feet': null}),
        throwsFormatException,
      );
      expect(
        () => ActorAtlas.fromJson({
          ...r,
          'feet': [
            [3, 16],
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => ActorAtlas.fromJson({...r, 'anchorMode': 'guess'}),
        throwsFormatException,
      );
      final mirrors = List<bool>.filled(64, false)..[0] = true;
      expect(
        () => ActorAtlas.fromJson({...r, 'mirrors': mirrors}),
        throwsFormatException,
      );
      final feet = List<List<num>>.from(r['feet'] as List)
        ..[0] = [double.infinity, 16];
      expect(
        () => ActorAtlas.fromJson({...r, 'feet': feet}),
        throwsFormatException,
      );
    },
  );
  test(
    'metadata rejects incomplete, overlapped, mirrored or aliased fake movement',
    () {
      final base = record(144, motion: clip(8, 'phase-major'));
      for (final motion in [
        clip(3, 'phase-major'),
        {...clip(8, 'phase-major'), 'idleOffset': 16},
        {...clip(8, 'phase-major'), 'runOffset': 140},
        {...clip(8, 'phase-major'), 'directions': 8},
        clip(8, 'unknown'),
      ]) {
        expect(
          () => ActorAtlas.fromJson({...base, 'motion': motion}),
          throwsFormatException,
        );
      }
      final mirrors = List<bool>.filled(144, false)..[27] = true;
      expect(
        () => ActorAtlas.fromJson({...base, 'mirrors': mirrors}),
        throwsFormatException,
      );
      final frames = List<List<int>>.from(base['frames'] as List)
        ..[17] = [128, 0, 8, 12];
      expect(
        () => ActorAtlas.fromJson({...base, 'frames': frames}),
        throwsFormatException,
      );
    },
  );
  test(
    'opt-in references and source rectangles fail closed without changing legacy parsing',
    () {
      final r = record(144, motion: clip(8, 'phase-major'));
      expect(
        () => ActorAtlas.fromJson({...r, 'sizes': []}),
        throwsFormatException,
      );
      expect(
        () => ActorAtlas.fromJson({
          'frames': [],
          'feet': [],
          'sizes': [],
          'anchorMode': 'projected-origin',
        }),
        throwsFormatException,
      );
      for (final height in [0, -1, double.nan, double.infinity]) {
        expect(
          () => ActorAtlas.fromJson({
            ...r,
            'sizes': [
              [8, height],
            ],
          }),
          throwsFormatException,
        );
      }
      for (final bad in [
        <num>[0, 0, 0, 12],
        <num>[0, 0, 8, -1],
        <num>[double.nan, 0, 8, 12],
        <num>[0, 0, double.infinity, 12],
        <num>[-1, 0, 8, 12],
      ]) {
        final frames = List<List<num>>.from(r['frames'] as List)..[0] = bad;
        expect(
          () => ActorAtlas.fromJson({...r, 'frames': frames}),
          throwsFormatException,
        );
      }
      expect(
        () => ActorAtlas.fromJson({...r, 'feet': null}),
        throwsFormatException,
      );
      for (final offset in [145, 9223372036854775807]) {
        expect(
          () => ActorAtlas.fromJson({
            ...r,
            'motion': {...clip(8, 'phase-major'), 'runOffset': offset},
          }),
          throwsFormatException,
        );
        expect(
          () => ActorAtlas.fromJson({
            ...r,
            'motion': {...clip(8, 'phase-major'), 'idleOffset': offset},
          }),
          throwsFormatException,
        );
      }
      final legacy = record(32)
        ..['sizes'] = [
          [8, 0],
        ];
      expect(
        ActorAtlas.fromJson(legacy).motion,
        isNull,
        reason: 'strict rules apply only to opted-in metadata',
      );
    },
  );
  test(
    'phaseFor subdivides the unchanged84-unit cycle without advancing or fabricating distance',
    () {
      final motion = RunMotion();
      for (var phase = 0; phase < 8; phase++) {
        motion.cycle = (phase + .1) / 8;
        expect(motion.phaseFor(8), phase);
        expect(motion.phase, phase ~/ 4);
      }
      expect(() => motion.phaseFor(0), throwsArgumentError);
      motion.cycle = 0;
      motion.advance(84);
      expect(motion.phaseFor(8), 0);
      motion.advance(double.nan);
      motion.advance(0);
      expect(motion.cycle, 0);
    },
  );
  for (final hz in [30, 60, 120, 144]) {
    test(
      'actual$hz Hz movement renders all8 phases then uses separate idle intent',
      () {
        final art = VariableArt(),
            s = inCombatField(Adventure(art))..start(TestGame());
        addTearDown(s.dispose);
        final phases = <int>{};
        final start = s.hero.position.clone();
        // Observe more than one physical gait cycle at the current normal
        // movement speed, rather than relying on the former270px/s fixture.
        final duration =
            RunMotion.strideLength / CombatBalance.normalMoveSpeed * 1.25;
        for (var i = 0; i < (hz * duration).ceil(); i++) {
          s.hero.moveRight();
          s.hero.update(1 / hz);
          final r = ui.PictureRecorder();
          s.hero.render(ui.Canvas(r));
          r.endRecording().dispose();
          if (s.hero.movingThisFrame) phases.add(art.seenPhase!);
        }
        expect(phases, {0, 1, 2, 3, 4, 5, 6, 7});
        expect(
          (s.hero.position - start).length,
          greaterThanOrEqualTo(RunMotion.strideLength),
        );
        expect(
          s.hero.runMotion.cycle,
          closeTo(
            (s.hero.position - start).length / RunMotion.strideLength % 1,
            .0001,
          ),
        );
        s.hero.stop();
        s.hero.update(1 / hz);
        final r = ui.PictureRecorder();
        s.hero.render(ui.Canvas(r));
        r.endRecording().dispose();
        expect(art.seenMoving, false);
        expect(art.seenPhase, 0);
        final cycle = s.hero.runMotion.cycle;
        s.pause();
        s.hero.update(.05);
        expect(s.hero.runMotion.cycle, cycle);
      },
    );
  }
}
