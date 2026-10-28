import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/effect_atlas.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/illustrated_combat_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_combat.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

Future<({ui.Image image, Uint8List pixels})> _render(
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (image: image, pixels: Uint8List.fromList(data.buffer.asUint8List()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image image, actionImage;
  late EffectAtlas atlas;
  setUpAll(() async {
    final codec = await ui.instantiateImageCodec(
      await File('art/combat-illustrations.webp').readAsBytes(),
    );
    image = (await codec.getNextFrame()).image;
    codec.dispose();
    atlas = EffectAtlas({IllustratedCombatArt.imageKey: image});
    final actions = await ui.instantiateImageCodec(
      await File('art/combat-actions.webp').readAsBytes(),
    );
    actionImage = (await actions.getNextFrame()).image;
    actions.dispose();
  });
  tearDownAll(() {
    image.dispose();
    actionImage.dispose();
  });

  test(
    'all16 generated cells have real transparent gutters within4MiB',
    () async {
      expect(image.width, 1024);
      expect(image.height, 1024);
      expect(image.width * image.height * 4, 4 * 1024 * 1024);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var tile = 0; tile < 16; tile++) {
        var visible = 0;
        for (var y = 0; y < 256; y++) {
          for (var x = 0; x < 256; x++) {
            final alpha =
                bytes[((tile ~/ 4 * 256 + y) * 1024 + tile % 4 * 256 + x) * 4 +
                    3];
            if (x < 32 || y < 32 || x >= 224 || y >= 224) {
              expect(alpha, 0, reason: 'neighbour cells must never bleed');
            } else if (alpha > 20) {
              visible++;
            }
          }
        }
        expect(visible, greaterThan(1000));
      }
    },
  );

  test(
    'three families change shape across time and leave the torso visible',
    () async {
      final proof = Platform.environment['ILLUSTRATED_COMBAT_PROOF'];
      if (proof != null) await Directory(proof).create(recursive: true);
      for (final family in CombatIllustration.values) {
        final hashes = <int>{};
        for (final t in [.12, .38, .68, .9]) {
          final result = await _render((canvas) {
            expect(
              IllustratedCombatArt.sequence(
                atlas,
                canvas,
                family,
                const ui.Offset(128, 140),
                progress: t,
                radius: 84,
                protectBody: true,
              ),
              true,
            );
          });
          try {
            expect(result.pixels.where((v) => v > 0).length, greaterThan(200));
            hashes.add(Object.hashAll(result.pixels));
            for (var y = 96; y < 125; y++) {
              for (var x = 120; x < 136; x++) {
                expect(result.pixels[(y * 256 + x) * 4 + 3], 0);
              }
            }
            if (proof != null) {
              final png = await result.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$proof/${family.name}-$t.png',
              ).writeAsBytes(png!.buffer.asUint8List());
            }
          } finally {
            result.image.dispose();
          }
        }
        expect(hashes.length, 4);
      }
    },
  );

  test(
    'a steel effect cannot desaturate the next generated sprint icon',
    () async {
      final art = GameArt()
        ..images[IllustratedCombatArt.imageKey] = image
        ..images[ActionIllustrationPainter.imageKey] = actionImage;
      final clean = await _render(
        (c) => EffectIconPainter(
          art,
          34,
          framed: false,
        ).paint(c, const ui.Size(96, 96)),
      );
      final after = await _render((c) {
        IllustratedCombatArt.sequence(
          art.effects,
          c,
          CombatIllustration.blade,
          const ui.Offset(-1000, -1000),
          progress: .4,
          steel: true,
        );
        EffectIconPainter(
          art,
          34,
          framed: false,
        ).paint(c, const ui.Size(96, 96));
      });
      expect(after.pixels, clean.pixels);
      expect(after.pixels.where((v) => v > 0).length, greaterThan(1500));
      final fist = await _render(
        (c) => ActionIllustrationPainter(
          art,
          fist: true,
        ).paint(c, const ui.Size(96, 96)),
      );
      expect(fist.pixels.where((v) => v > 0).length, greaterThan(1500));
      expect(fist.pixels, isNot(clean.pixels));
      expect(actionImage.width * actionImage.height * 4, 524288);
      fist.image.dispose();
      clean.image.dispose();
      after.image.dispose();
    },
  );

  test(
    'actual Nova and Frost Nova enrich the full wave, preserving the torso',
    () async {
      for (final id in ['nova', 'frostNova']) {
        final art = GameArt(), game = TestGame();
        final s = inCombatField(Adventure(art, heroClass: HeroClass.mage))
          ..start(game);
        addTearDown(s.dispose);
        s.progress.level = 100;
        s.progress.skillPoints = 1000;
        trainSkill(s.progress, id, 5);
        expect(s.progress.selectSkill(id), true);
        s.progress.energy = s.progress.maxEnergy;
        s.hero.skill();
        final wave = game.added.whereType<SorceressFlash>().firstWhere(
          (v) => v.mode == 'ground',
        );
        for (var i = 0; i < 3; i++) {
          wave.update(.05);
        }
        Future<({ui.Image image, Uint8List pixels})> draw() => _render((c) {
          c.translate(128, 140);
          wave.render(c);
        });
        final before = await draw();
        art.images[IllustratedCombatArt.imageKey] = image;
        final after = await draw();
        try {
          int outside(Uint8List bytes) {
            var count = 0;
            for (var y = 0; y < 256; y++) {
              for (var x = 0; x < 256; x++) {
                if ((x - 128) * (x - 128) + (y - 140) * (y - 140) > 60 * 60 &&
                    bytes[(y * 256 + x) * 4 + 3] > 20) {
                  count++;
                }
              }
            }
            return count;
          }

          expect(
            outside(after.pixels),
            greaterThan(outside(before.pixels) + 800),
            reason: id,
          );
          for (var y = 90; y < 120; y++) {
            for (var x = 124; x < 132; x++) {
              final index = (y * 256 + x) * 4;
              expect(
                after.pixels.sublist(index, index + 4),
                before.pixels.sublist(index, index + 4),
              );
            }
          }
        } finally {
          before.image.dispose();
          after.image.dispose();
          art.images.clear();
        }
      }
    },
  );

  test(
    'missing art and invalid clocks have a safe procedural fallback',
    () async {
      final result = await _render((c) {
        for (final t in [double.nan, -1.0, 1.0, double.infinity]) {
          expect(
            IllustratedCombatArt.sequence(
              atlas,
              c,
              CombatIllustration.blade,
              ui.Offset.zero,
              progress: t,
            ),
            false,
          );
        }
        expect(
          IllustratedCombatArt.sequence(
            EffectAtlas({}),
            c,
            CombatIllustration.blade,
            ui.Offset.zero,
            progress: .3,
          ),
          false,
        );
      });
      expect(result.pixels.every((v) => v == 0), true);
      result.image.dispose();
    },
  );
}
