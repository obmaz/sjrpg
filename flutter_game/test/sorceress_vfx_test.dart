import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/sorceress_vfx.dart';

const _projectiles = {
  'iceBolt',
  'iceBlast',
  'glacialSpike',
  'frozenOrb',
  'chargedBolt',
  'firebolt',
  'fireball',
};
const _buffs = {
  'frozenArmor',
  'shiverArmor',
  'chillingArmor',
  'coldMastery',
  'energyShield',
  'lightningMastery',
  'warmth',
  'enchant',
  'fireMastery',
};
void _pose(
  ui.Canvas canvas,
  String id,
  ui.Offset center,
  double phase, {
  int rank = 9,
}) {
  if (_projectiles.contains(id)) {
    SorceressVfx.projectile(
      canvas,
      id,
      center,
      bearing: -.35,
      time: phase,
      rank: rank,
      radius: 13,
      seed: 3,
    );
  } else if (_buffs.contains(id)) {
    SorceressVfx.buff(canvas, id, center, time: phase, rank: rank, radius: 29);
  } else if (id == 'lightning' || id == 'chainLightning') {
    SorceressVfx.beam(
      canvas,
      id,
      [
        center + const ui.Offset(-58, 10),
        center + const ui.Offset(4, -12),
        center + const ui.Offset(60, 8),
      ],
      time: phase,
      rank: rank,
    );
  } else {
    SorceressVfx.ground(
      canvas,
      id,
      center,
      progress: phase,
      time: phase,
      rank: rank,
      radius: id == 'meteor' ? 32 : 43,
      bearing: .1,
      seed: 3,
    );
  }
}

Future<Uint8List> _pixels(
  void Function(ui.Canvas) paint, {
  int side = 256,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording(),
      image = await picture.toImage(side, side);
  picture.dispose();
  try {
    return Uint8List.fromList(
      (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
  }
}

int _ink(Uint8List bytes) {
  var result = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] > 0) result++;
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  test('all thirty skills have distinct moving bounded native poses', () async {
    expect(SorceressVfx.skills.length, 30);
    expect(SorceressVfx.skills.toSet().length, 30);
    for (final id in SorceressVfx.skills) {
      final frames = <Uint8List>[];
      for (final phase in [0.0, .3, .7]) {
        final frame = await _pixels(
          (canvas) => _pose(canvas, id, const ui.Offset(180, 180), phase),
          side: 360,
        );
        expect(
          _ink(frame),
          greaterThan(20),
          reason: '$id $phase must remain visible',
        );
        // A bounded effect must not paint any edge of its 360px preview.
        for (var i = 0; i < 360; i++) {
          expect(
            frame[(i * 360) * 4 + 3] +
                frame[(i * 360 + 359) * 4 + 3] +
                frame[i * 4 + 3] +
                frame[(359 * 360 + i) * 4 + 3],
            0,
            reason: '$id exceeds its preview bounds',
          );
        }
        frames.add(frame);
      }
      expect(
        listEquals(frames[0], frames[1]),
        false,
        reason: '$id must animate at .3s',
      );
      expect(
        listEquals(frames[1], frames[2]),
        false,
        reason: '$id must animate at .7s',
      );
    }
  });
  test(
    'sustained flames shards and hydra animate internally at a fixed location',
    () async {
      for (final id in [
        'inferno',
        'blaze',
        'firewall',
        'blizzard',
        'frozenOrb',
        'hydra',
      ]) {
        final frames = <Uint8List>[];
        for (final time in [0.0, .3, .7]) {
          frames.add(
            await _pixels(
              (canvas) => SorceressVfx.ground(
                canvas,
                id,
                const ui.Offset(128, 128),
                progress: .2,
                time: time,
                radius: 43,
                rank: 9,
              ),
            ),
          );
        }
        expect(
          listEquals(frames[0], frames[1]),
          false,
          reason: '$id is a static moved picture',
        );
        expect(
          listEquals(frames[1], frames[2]),
          false,
          reason: '$id internal motion stopped',
        );
      }
    },
  );
  test(
    'ranks above the skill cap preserve the bounded visual budget',
    () async {
      final capped = await _pixels(
        (canvas) => SorceressVfx.ground(
          canvas,
          'blizzard',
          const ui.Offset(128, 128),
          time: .3,
          radius: 43,
          rank: 20,
        ),
      );
      final extreme = await _pixels(
        (canvas) => SorceressVfx.ground(
          canvas,
          'blizzard',
          const ui.Offset(128, 128),
          time: .3,
          radius: 43,
          rank: 1000000,
        ),
      );
      expect(listEquals(capped, extreme), true);
    },
  );
  test(
    'expired and invalid input produces no paint or canvas transform changes',
    () async {
      final bytes = await _pixels((canvas) {
        for (final id in SorceressVfx.skills) {
          SorceressVfx.projectile(
            canvas,
            id,
            const ui.Offset(128, 128),
            progress: 1,
          );
          SorceressVfx.cast(canvas, id, const ui.Offset(128, 128), progress: 1);
          SorceressVfx.impact(
            canvas,
            id,
            const ui.Offset(128, 128),
            progress: 1,
          );
          SorceressVfx.ground(
            canvas,
            id,
            const ui.Offset(128, 128),
            progress: 1,
          );
          SorceressVfx.buff(canvas, id, const ui.Offset(128, 128), time: -1);
          SorceressVfx.beam(canvas, id, [
            const ui.Offset(20, 20),
            const ui.Offset(80, 80),
          ], progress: 1);
        }
        SorceressVfx.projectile(
          canvas,
          'fireball',
          const ui.Offset(double.nan, 0),
        );
        SorceressVfx.ground(
          canvas,
          'inferno',
          const ui.Offset(128, 128),
          radius: double.infinity,
        );
      });
      expect(_ink(bytes), 0);
    },
  );
  test('paint helpers preserve caller transform and clipping', () async {
    await _pixels((canvas) {
      canvas.translate(18, 25);
      canvas.rotate(.2);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 190, 190));
      final matrix = List<double>.of(canvas.getTransform()),
          clip = canvas.getLocalClipBounds();
      for (final id in SorceressVfx.skills) {
        _pose(canvas, id, const ui.Offset(90, 90), .3);
        SorceressVfx.cast(canvas, id, const ui.Offset(90, 90), progress: .3);
        SorceressVfx.impact(canvas, id, const ui.Offset(90, 90), progress: .3);
        expect(listEquals(canvas.getTransform(), matrix), true, reason: id);
        expect(canvas.getLocalClipBounds(), clip, reason: id);
      }
    });
  });
  test(
    'armor variants stay distinct and preserve a transparent hero center',
    () async {
      final frames = <Uint8List>[];
      for (final id in [
        'frozenArmor',
        'shiverArmor',
        'chillingArmor',
        'energyShield',
      ]) {
        final bytes = await _pixels(
          (canvas) => SorceressVfx.buff(
            canvas,
            id,
            const ui.Offset(128, 128),
            time: .3,
          ),
        );
        for (var y = 122; y < 134; y++) {
          for (var x = 122; x < 134; x++) {
            expect(
              bytes[(y * 256 + x) * 4 + 3],
              0,
              reason: '$id obscures the hero',
            );
          }
        }
        frames.add(bytes);
      }
      for (var i = 0; i < frames.length; i++) {
        for (var j = i + 1; j < frames.length; j++) {
          expect(listEquals(frames[i], frames[j]), false);
        }
      }
      final heads = SorceressVfx.hydraHeads(
        const ui.Offset(128, 128),
        time: .3,
        radius: 43,
      );
      expect(heads.length, 3);
      expect(heads.toSet().length, 3);
    },
  );
  test(
    'every school retains bright readable detail on a dark dungeon floor',
    () async {
      for (final id in SorceressVfx.skills) {
        final bytes = await _pixels((canvas) {
          canvas.drawColor(const ui.Color(0xff151c29), ui.BlendMode.src);
          _pose(canvas, id, const ui.Offset(128, 128), .3);
        });
        var contrast = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if ((bytes[i] - 21).abs() +
                  (bytes[i + 1] - 28).abs() +
                  (bytes[i + 2] - 41).abs() >
              140) {
            contrast++;
          }
        }
        expect(
          contrast,
          greaterThan(12),
          reason: '$id is lost against a dark floor',
        );
      }
    },
  );
  test(
    'native day and night contact sheets capture independent animation poses',
    () async {
      final directory = Platform.environment['SJRPG_SORCERESS_VFX_PROOF_DIR'];
      if (directory == null) return;
      Directory(directory).createSync(recursive: true);
      for (final dark in [false, true]) {
        for (final phase in [0.0, .3, .7]) {
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          canvas.drawColor(
            dark ? const ui.Color(0xff151c29) : const ui.Color(0xff63724d),
            ui.BlendMode.src,
          );
          for (var i = 0; i < SorceressVfx.skills.length; i++) {
            final origin = ui.Offset(i % 6 * 200.0, i ~/ 6 * 180.0);
            canvas.save();
            canvas.clipRect(origin & const ui.Size(200, 180));
            _pose(
              canvas,
              SorceressVfx.skills[i],
              origin + const ui.Offset(100, 108),
              phase,
            );
            final label =
                (ui.ParagraphBuilder(
                        ui.ParagraphStyle(fontFamily: 'Guardian', fontSize: 12),
                      )
                      ..pushStyle(
                        ui.TextStyle(color: const ui.Color(0xffeee6d3)),
                      )
                      ..addText(SorceressVfx.skills[i]))
                    .build()
                  ..layout(const ui.ParagraphConstraints(width: 190));
            canvas.drawParagraph(label, origin + const ui.Offset(8, 8));
            label.dispose();
            canvas.restore();
          }
          final picture = recorder.endRecording(),
              image = await picture.toImage(1200, 900);
          picture.dispose();
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$directory/${dark ? 'night' : 'day'}-$phase.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        }
      }
    },
  );
}
