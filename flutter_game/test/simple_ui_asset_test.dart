import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/cinematic_icon_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'twelve generated controls are distinct, contained and available in gameplay',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images.containsKey('fx-steel-whirlwind'), false);
      expect(art.images.containsKey('fx-warcry'), false);
      final glyphs = art.images[CinematicIconArt.imageKey];
      expect(glyphs, isNotNull);
      final unique = <String>{};
      for (var i = 0; i < 12; i++) {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        expect(
          CinematicIconArt.draw(
            canvas,
            art,
            i,
            const ui.Rect.fromLTWH(8, 8, 48, 48),
          ),
          true,
        );
        final picture = recorder.endRecording(),
            image = picture.toImageSync(64, 64);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        unique.add(base64Encode(bytes));
        var visible = 0;
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final alpha = bytes[(y * 64 + x) * 4 + 3];
            if (alpha > 0) {
              visible++;
              expect(x, inInclusiveRange(8, 55));
              expect(y, inInclusiveRange(8, 55));
            }
          }
        }
        expect(visible, greaterThan(120));
        image.dispose();
        picture.dispose();
      }
      expect(unique.length, 12);
    },
  );
  test(
    'skill duration and regeneration labels use real seconds without altering rank values',
    () {
      const seconds = SkillPreviewValue('대기', 12, 6, suffix: '초', digits: 1);
      const recovery = SkillPreviewValue('회복', 2, 3, suffix: '/초', digits: 1);
      const speed = SkillPreviewValue('속도', 135, 270, suffix: '걸음/초');
      expect(seconds.current, 12);
      expect(seconds.format(seconds.current), '10.0초');
      expect(recovery.format(recovery.current), '2.4/초');
      expect(speed.format(speed.current), '4걸음/초');
    },
  );
  test(
    'a cottage fades behind the hero while its front and side remain solid-looking',
    () {
      final s = Adventure(GameArt());
      addTearDown(s.dispose);
      final p = WorldProp(
        const ui.Rect.fromLTWH(4000, 4000, 180, 100),
        'village-cottage',
        const ui.Size(240, 280),
      );
      final prop = WoodlandProp(s, p);
      s.hero.position.setValues(p.body.center.dx - 14, p.body.bottom - 80 - 24);
      expect(prop.occludesHero, true);
      s.hero.position.y = p.body.bottom + 5;
      expect(prop.occludesHero, false);
      s.hero.position.setValues(p.body.right + 200, p.body.top);
      expect(prop.occludesHero, false);
    },
  );
}
