import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/skill_tree.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/skills_panel.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameArt? artwork;
  Future<GameArt> art(WidgetTester tester) async =>
      artwork ??= (await tester.runAsync(() async {
        final font = FontLoader('Guardian')
          ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await Future.wait([font.load(), icons.load()]);
        final result = await GameArt.loadMenu();
        await result.ensureStage(
          WorldStage.forest,
          heroClass: HeroClass.warrior,
        );
        return result;
      }))!;
  tearDownAll(() => artwork?.dispose());
  Future<void> proof(WidgetTester tester, String name) async {
    final directory = Platform.environment['SJRPG_TREE_PROOF_DIR'];
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('tree-proof')),
    );
    await tester.runAsync(() async {
      Directory(directory).createSync(recursive: true);
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$directory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget app(Widget child) => MaterialApp(
    theme: ThemeData(fontFamily: 'Guardian'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const ValueKey('tree-proof'),
      child: Scaffold(body: child),
    ),
  );

  for (final hero in HeroClass.values) {
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets('$hero tabs fit the complete viewport at $size text1.3', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(await art(tester), heroClass: hero)
          ..start(TestGame());
        s.pause();
        s.progress.level = 30;
        s.progress.skillPoints = 60;
        addTearDown(s.dispose);
        await tester.pumpWidget(app(SkillsPanel(session: s, onClose: () {})));
        await tester.pumpAndSettle();
        final footer = find.bySemanticsLabel('모험 계속하기'),
            footerRect = tester.getRect(footer);
        final tree = find.byType(SkillTree), treeRect = tester.getRect(tree);
        for (
          var school = 0;
          school < skillTreeSchoolLabels(s.progress).length;
          school++
        ) {
          final tab = find.byKey(ValueKey('skill-school-tab-$school'));
          expect(tester.getRect(tab).height, greaterThanOrEqualTo(44));
          expect(tester.getRect(tab).width, greaterThanOrEqualTo(44));
          await tester.tap(tab);
          await tester.pumpAndSettle();
          final geometry = SkillSchoolLayout(
            s.progress,
            school,
            treeRect.width - 18,
            dense: treeRect.height < 180,
            textScale: 1.3,
          );
          for (final skill in geometry.skills) {
            final rect = tester.getRect(
              find.byKey(ValueKey('skill-node-${skill.id}')),
            );
            expect(rect.left, greaterThanOrEqualTo(treeRect.left));
            expect(rect.right, lessThanOrEqualTo(treeRect.right));
          }
          expect(
            find.byKey(const ValueKey('skill-tree-horizontal')),
            findsNothing,
          );
          await proof(
            tester,
            '${hero.name}-${size.width.toInt()}-school$school-top',
          );
          final last = geometry.rects.entries.reduce(
            (a, b) => a.value.top > b.value.top ? a : b,
          );
          await Scrollable.ensureVisible(
            tester.element(find.byKey(ValueKey('skill-node-${last.key}'))),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(footer), footerRect);
          expect(footerRect.bottom, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), null);
          await proof(
            tester,
            '${hero.name}-${size.width.toInt()}-school$school-bottom',
          );
        }
      });
    }
    testWidgets(
      '$hero complete selected school has no partial neighboring panel',
      (tester) async {
        final s = Adventure(await art(tester), heroClass: hero)
          ..start(TestGame());
        s.pause();
        s.progress.level = 30;
        addTearDown(s.dispose);
        final geometry = SkillSchoolLayout(
          s.progress,
          0,
          372,
          dense: false,
          textScale: 1.3,
        );
        tester.view.physicalSize = Size(390, geometry.height + 68);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          app(
            SkillTree(
              session: s,
              controller: controller,
              focused: null,
              onFocus: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (
          var school = 0;
          school < skillTreeSchoolLabels(s.progress).length;
          school++
        ) {
          await tester.tap(find.byKey(ValueKey('skill-school-tab-$school')));
          await tester.pumpAndSettle();
          expect(controller.position.maxScrollExtent, 0);
          expect(tester.takeException(), null);
          await proof(tester, '${hero.name}-full-school$school');
        }
      },
    );
  }
}
