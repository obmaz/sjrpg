import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class CountingArt extends GameArt {
  int layouts = 0;
  @override
  ui.Paragraph layoutText(
    String value, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    layouts++;
    return super.layoutText(value, size: size, color: color);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late CountingArt art;
  setUp(() {
    art = CountingArt();
    s = Adventure(art)..start(TestGame());
  });
  tearDown(() => s.dispose());
  const color = ui.Color(0xffffedb4), origin = ui.Offset(6000, 4200);

  void verifySeparation() {
    final texts = s.texts.where((t) => !t.isReward).toList();
    expect(texts.length, lessThanOrEqualTo(14));
    for (var i = 0; i < texts.length; i++) {
      for (var j = i + 1; j < texts.length; j++) {
        expect(texts[i].combatBounds.overlaps(texts[j].combatBounds), false);
      }
    }
  }

  test(
    'formatting changes display only, preserving rewards and damage values',
    () {
      final hit = BattleText(s, '12890', origin, color);
      final crit = BattleText(s, '34512', origin, color, critical: true);
      final hurt = BattleText(s, '-1234', origin, color);
      final reward = BattleText(s, '+12890 골드', origin, color);
      expect(hit.displayLabel, '12,890');
      expect(crit.displayLabel, '34,512');
      expect(hurt.displayLabel, '-1,234');
      expect([hit.isReward, crit.isReward, hurt.isReward], everyElement(false));
      expect(hit.label, '12890');
      expect(reward.displayLabel, '+12890 골드');
      expect(reward.isReward, true);
      expect(crit.textSize, greaterThan(hit.textSize));
      for (final text in [hit, crit, hurt, reward]) {
        text.releaseText();
      }
    },
  );
  test('normal and critical damage share the bounded non-overlap budget', () {
    for (var i = 0; i < 50; i++) {
      s.bubble('${12890 + i}', origin, color, critical: i.isEven);
      verifySeparation();
    }
    expect(s.texts.length, lessThanOrEqualTo(14));
    expect(s.texts.where((text) => text.critical), isNotEmpty);
  });
  test('critical fill and title are cached through motion and fading', () {
    final text = BattleText(s, '34512', origin, color, critical: true);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (var frame = 0; frame < 53; frame++) {
      text.render(canvas);
      text.update(1 / 60);
    }
    expect(art.layouts, 2, reason: 'One number and one CRITICAL! title');
    text.releaseText();
    text.releaseText();
    recorder.endRecording().dispose();
  });
  test('dense hits stay individually readable as old numbers float upward', () {
    for (var wave = 0; wave < 5; wave++) {
      for (var i = 0; i < 10; i++) {
        s.bubble(
          i.isEven ? '45' : '-12',
          origin + ui.Offset(i % 3 * 8, 0),
          color,
        );
        verifySeparation();
      }
      for (final text in s.texts) {
        text.update(.08);
      }
      verifySeparation();
    }
    expect(s.texts.every((t) => t.label == '45' || t.label == '-12'), true);
    expect(s.progress.kills, 0);
  });
  test(
    'very large values evict old popups instead of overlapping or growing',
    () {
      for (var i = 0; i < 100; i++) {
        s.bubble('999999999', origin, color);
        verifySeparation();
      }
      for (final text in s.texts) {
        expect((text.position.x - origin.dx).abs(), lessThanOrEqualTo(77));
        expect(origin.dy - text.position.y, lessThanOrEqualTo(155));
      }
    },
  );
  test(
    'a 60Hz popup reuses its layout while opaque and releases safely',
    () async {
      s.bubble('45', origin, color);
      final text = s.texts.single;
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.translate(80, 20);
      for (var frame = 0; frame < 36; frame++) {
        text.render(canvas);
        text.update(1 / 60);
      }
      expect(
        art.layouts,
        1,
        reason: '36 opaque frames need only one text layout',
      );
      for (var frame = 0; frame < 18; frame++) {
        text.render(canvas);
        text.update(1 / 60);
      }
      expect(art.layouts, 1, reason: 'Fading reuses the opaque glyph layout');
      text.releaseText();
      text.releaseText();
      final picture = recorder.endRecording(),
          image = await picture.toImage(160, 80);
      picture.dispose();
      expect(await image.toByteData(), isNotNull);
      image.dispose();
    },
  );
  test(
    'cached text has identical pixels at full opacity and during its fade',
    () async {
      Future<List<int>> pixels(
        String label,
        double remaining,
        bool cached,
      ) async {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.translate(80, 12);
        if (cached) {
          final text = BattleText(s, label, ui.Offset.zero, color)
            ..remaining = remaining;
          text.render(canvas);
          text.releaseText();
        } else {
          art.text(
            canvas,
            label,
            ui.Offset.zero,
            size: label.startsWith('+') ? 13 : 18,
            color: color.withValues(alpha: (remaining / .3).clamp(0, 1)),
          );
        }
        final picture = recorder.endRecording(),
            image = await picture.toImage(160, 60);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final result = data.buffer
            .asUint8List(data.offsetInBytes, data.lengthInBytes)
            .toList();
        image.dispose();
        return result;
      }

      for (final label in ['+8 골드', '레벨 상승']) {
        for (final time in [.9, .2, .05]) {
          expect(
            await pixels(label, time, true),
            await pixels(label, time, false),
          );
        }
      }
    },
  );
}
