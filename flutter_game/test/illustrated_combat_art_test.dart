import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/effect_atlas.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/illustrated_combat_art.dart';

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
  late ui.Image image;
  late EffectAtlas atlas;
  setUpAll(() async {
    final codec = await ui.instantiateImageCodec(
      await File('art/combat-illustrations.webp').readAsBytes(),
    );
    image = (await codec.getNextFrame()).image;
    codec.dispose();
    atlas = EffectAtlas({IllustratedCombatArt.imageKey: image});
  });
  tearDownAll(() => image.dispose());

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
      final art = GameArt()..images[IllustratedCombatArt.imageKey] = image;
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
      clean.image.dispose();
      after.image.dispose();
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
