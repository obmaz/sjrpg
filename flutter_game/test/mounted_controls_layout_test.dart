import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/mount_merchant.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'mounted skills replace foot controls and fit both orientations',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final art = await t.runAsync(GameArt.load);
      expect(art, isNotNull);
      await t.pumpWidget(
        MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!,
          ),
          home: GamePage(art: art!, onRestart: () {}),
        ),
      );
      for (var i = 0; i < 160; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      final s =
          (t.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
                  as Guardian)
              .session;
      expect(s.ready, true);
      s.progress.level = 30;
      s.progress.skillPoints = 400;
      for (var i = 0; i < 30; i++) {
        for (final skill in s.progress.skills) {
          if (s.progress.rank(skill.id) < 5) s.progress.learn(skill);
        }
      }
      withOwnedMounts(s);
      for (final type in ['horse', 'bicycle', 'motor', 'boat']) {
        final mount = s.mounts.firstWhere((m) => m.def.artKey == type);
        s.riding = mount;
        s.hero.resizeBody(mount.def.bodySize, mount.at);
        s.hero.lastClearPosition = s.hero.position.toOffset();
        s.refresh();
        for (final size in [
          const Size(320, 420),
          const Size(390, 844),
          const Size(844, 390),
          const Size(667, 375),
          const Size(300, 450),
        ]) {
          t.view.physicalSize = size;
          await t.pump(const Duration(milliseconds: 16));
          final buttons = t
              .widgetList<ActionButton>(find.byType(ActionButton))
              .toList();
          expect(
            buttons.where(
              (b) => s.progress.skills.any((d) => d.name == b.semanticLabel),
            ),
            isEmpty,
            reason: 'foot skills are reached after dismount',
          );
          final mountSkill = buttons
              .where((b) => b.semanticLabel.startsWith('탈것 스킬'))
              .toList();
          expect(mountSkill.length, type == 'motor' ? 0 : 1);
          expect(buttons.where((b) => b.semanticLabel == '회피'), isEmpty);
          final primary = buttons.singleWhere((b) => b.semanticLabel == '공격');
          expect(primary.onHold == null, type == 'motor');
          if (type == 'motor') {
            expect(primary.artwork, isNotNull);
            expect(find.byType(MountSkillBadge), findsOneWidget);
          }
          final bounds = <Rect>[];
          for (final finder in [
            find.byType(ActionButton),
            find.byType(GameStick),
            find.byType(MenuButton),
          ]) {
            for (final element in finder.evaluate()) {
              final r = t.getRect(find.byWidget(element.widget));
              expect(r.left, greaterThanOrEqualTo(0), reason: '$type $size');
              expect(r.top, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(size.width));
              expect(r.bottom, lessThanOrEqualTo(size.height));
              bounds.add(r);
            }
          }
          for (var a = 0; a < bounds.length; a++) {
            for (var b = a + 1; b < bounds.length; b++) {
              expect(
                bounds[a].deflate(1).overlaps(bounds[b].deflate(1)),
                false,
                reason: '$type $size ${bounds[a]} overlaps ${bounds[b]}',
              );
            }
          }
          expect(t.takeException(), null);
        }
      }
      await t.pumpWidget(const SizedBox.shrink());
      art.dispose();
    },
  );
}
