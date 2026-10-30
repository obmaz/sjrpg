import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/class_selection.dart';
import 'package:guardian_new/entry_loading.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/landscape_entry.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/stage_content.dart';
import 'package:guardian_new/title_screen.dart';

import 'support/test_game.dart';

class _TrackingBundle extends CachingAssetBundle {
  final reads = <String>[];
  String? failure;
  @override
  Future<ByteData> load(String key) async {
    reads.add(key);
    if (failure == '*' || failure == key) throw StateError('asset unavailable');
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameArt? loaded;
  Future<GameArt> artwork(WidgetTester tester) async =>
      loaded ??= (await tester.runAsync(() async {
        await (FontLoader(
              'Guardian',
            )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        return GameArt.loadMenu();
      }))!;
  tearDownAll(() => loaded?.dispose());

  Future<void> proof(WidgetTester tester, String name) async {
    final directory = Platform.environment['SJRPG_ENTRY_PROOF_DIR'];
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('entry-proof')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(directory).createSync(recursive: true);
        File(
          '$directory/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<void> show(
    WidgetTester tester,
    Size size,
    double scale,
    Widget child, {
    EdgeInsets safeInsets = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Guardian'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: safeInsets,
            viewPadding: safeInsets,
          ),
          child: child!,
        ),
        home: RepaintBoundary(key: const ValueKey('entry-proof'), child: child),
      ),
    );
  }

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'generated class cards and actual actions fit $size at $scale',
        (tester) async {
          final art = await artwork(tester);
          HeroClass? began;
          final semantics = tester.ensureSemantics();
          await show(
            tester,
            size,
            scale,
            ClassSelection(art: art, onBegin: (hero) => began = hero),
          );
          await tester.pumpAndSettle();
          expect(
            find.image(
              const AssetImage('assets/images/hero-helmeted-portrait.webp'),
            ),
            findsOneWidget,
            reason: 'the selected warrior identity appears on the class card',
          );
          final warrior = find.bySemanticsLabel('전사 선택');
          final mage = find.bySemanticsLabel('마법사 선택');
          for (final card in [warrior, mage]) {
            expect(tester.getSize(card).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(card).height, greaterThanOrEqualTo(44));
          }
          expect(find.byType(Scrollable), findsNothing);
          await proof(
            tester,
            'classes-warrior-${size.width.toInt()}x${size.height.toInt()}-$scale',
          );
          await tester.ensureVisible(mage);
          await tester.tapAt(
            tester.getRect(mage).bottomRight - const Offset(12, 12),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<Semantics>(mage).properties.selected, true);
          final start = find.bySemanticsLabel('마법사로 모험 시작');
          await tester.ensureVisible(start);
          await proof(
            tester,
            'classes-${size.width.toInt()}x${size.height.toInt()}-$scale',
          );
          final startAction = start;
          final startBounds = tester.getRect(startAction);
          await tester.tapAt(
            Offset(startBounds.left + 16, startBounds.center.dy),
          );
          expect(began, HeroClass.mage);
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel('모험 이어하기'), findsNothing);
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets('continue and new character stay separate at $size', (
      tester,
    ) async {
      final art = await artwork(tester);
      var continued = false;
      HeroClass? began;
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        size,
        1.3,
        ClassSelection(
          art: art,
          onBegin: (hero) => began = hero,
          onContinue: () => continued = true,
          continueSummary: '제4-2장 · 폭풍의 외곽 · Lv.18 마법사',
        ),
      );
      await tester.pumpAndSettle();
      final resume = find.bySemanticsLabel('모험 이어하기');
      await tester.ensureVisible(resume);
      final resumeBounds = tester.getRect(resume);
      await tester.tapAt(
        Offset(resumeBounds.right - 16, resumeBounds.center.dy),
      );
      expect(continued, true);
      expect(began, isNull);
      final fresh = find.bySemanticsLabel('전사로 새 모험');
      await tester.ensureVisible(fresh);
      await tester.pumpAndSettle();
      final action = fresh;
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(size.height));
      await proof(
        tester,
        'continue-${size.width.toInt()}x${size.height.toInt()}',
      );
      await tester.tap(fresh);
      expect(began, HeroClass.warrior);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('themed loader fits safe mobile area $size with large text', (
      tester,
    ) async {
      await artwork(tester);
      await show(
        tester,
        size,
        1.3,
        const EntryLoading(),
        safeInsets: const EdgeInsets.symmetric(vertical: 24),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final status = tester.getRect(find.text('모험의 풍경을 불러오고 있어요'));
      expect(status.top, greaterThanOrEqualTo(24));
      expect(status.bottom, lessThanOrEqualTo(size.height - 24));
      await proof(
        tester,
        'loading-safe-${size.width.toInt()}x${size.height.toInt()}-1.3',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('prepared-art overlay fits safe mobile area $size', (
      tester,
    ) async {
      final art = await artwork(tester);
      await show(
        tester,
        size,
        1.3,
        Scaffold(
          body: SafeArea(
            child: Center(child: EntryPreparationPanel(art: art)),
          ),
        ),
        safeInsets: const EdgeInsets.symmetric(vertical: 24),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final bounds = tester.getRect(find.byType(EntryPreparationPanel));
      expect(bounds.top, greaterThanOrEqualTo(24));
      expect(bounds.bottom, lessThanOrEqualTo(size.height - 24));
      await proof(
        tester,
        'preparing-safe-${size.width.toInt()}x${size.height.toInt()}-1.3',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'prepared overlay sibling gets Material typography outside the game Scaffold',
    (tester) async {
      final art = await artwork(tester);
      await show(
        tester,
        const Size(390, 844),
        1.3,
        Stack(
          fit: StackFit.expand,
          children: [
            const Scaffold(body: ColoredBox(color: Color(0xff102f2d))),
            Positioned.fill(
              child: Center(child: EntryPreparationPanel(art: art)),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(EntryPreparationPanel),
          matching: find.byType(RichText),
        ),
      );
      final style = paragraph.text.style!;
      expect(
        style.decoration?.contains(TextDecoration.underline) ?? false,
        isFalse,
      );
      expect(style.fontFamily, 'Guardian');
      expect(tester.takeException(), isNull);
      await proof(tester, 'preparing-actual-sibling-no-underline');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('prepared-art test fallback needs no extra network artwork', (
    tester,
  ) async {
    await show(
      tester,
      const Size(320, 420),
      1.3,
      Scaffold(
        body: Center(child: EntryPreparationPanel(art: GameArt())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final heroClass in HeroClass.values) {
    testWidgets('male ${heroClass.name} HUD uses the class portrait identity', (
      tester,
    ) async {
      final art = await artwork(tester);
      final session = Adventure(art, heroClass: heroClass)..start(TestGame());
      try {
        await show(
          tester,
          const Size(390, 160),
          1,
          Scaffold(body: GameHud(session)),
        );
        // The live resource vessel intentionally keeps a presentation ticker.
        await tester.pump(const Duration(milliseconds: 100));
        await proof(tester, 'male-hud-${heroClass.name}');
        expect(tester.takeException(), isNull);
        expect(art.images.keys, isNot(contains('actors-mage')));
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        session.dispose();
      }
    });
  }

  testWidgets(
    'continue stays visible for unreadable saves and refreshes on app return',
    (tester) async {
      final art = await artwork(tester);
      String? stored = '{"unreadable":true}';
      var writes = 0;
      await show(
        tester,
        const Size(390, 844),
        1,
        EntryPage(
          loadArt: () async => art,
          readCheckpoint: () => stored,
          writeCheckpoint: (value) {
            writes++;
            stored = value;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      EntryHotspot resume() => tester.widget<EntryHotspot>(
        find.byKey(const ValueKey('title-continue')),
      );
      expect(resume().onTap, isNull);
      expect(find.textContaining('저장된 모험을 불러올 수 없습니다'), findsOneWidget);
      expect(writes, 0);
      expect(stored, '{"unreadable":true}');
      final session = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      addTearDown(session.dispose);
      stored = GameCheckpoint.capture(session)!.encode();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(resume().onTap, isNotNull);
      expect(find.textContaining('Lv.1 마법사'), findsOneWidget);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'initial entry uses a neutral background before menu art completes',
    (tester) async {
      final art = await artwork(tester), ready = Completer<GameArt>();
      await show(
        tester,
        const Size(390, 844),
        1.3,
        EntryPage(loadArt: () => ready.future, readCheckpoint: () => null),
      );
      await tester.pump();
      expect(find.byType(EntryLoading), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is ResizeImage,
        ),
        findsNothing,
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await proof(tester, 'loading-390x844');
      ready.complete(art);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(TitleScreen), findsOneWidget);
      expect(find.byType(EntryLoading), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'menu uses small generated images and preserves transactional future preparation',
    () async {
      final bundle = _TrackingBundle();
      final art = await GameArt.loadMenu(bundle: bundle);
      addTearDown(art.dispose);
      expect(
        art.images.keys,
        unorderedEquals(['entry-scene', 'class-selection', 'entry-ui']),
      );
      expect(
        (art.images['entry-scene']!.width, art.images['entry-scene']!.height),
        (1024, 576),
      );
      expect(
        (
          art.images['class-selection']!.width,
          art.images['class-selection']!.height,
        ),
        (1024, 683),
      );
      final bytes = art.images.values.fold(
        0,
        (n, image) => n + image.width * image.height * 4,
      );
      expect(bytes, lessThan(10 * 1024 * 1024));
      expect(bundle.reads, isNot(contains('assets/images/actors-hero.webp')));
      expect(bundle.reads, isNot(contains('assets/images/actors-mage.png')));
      final original = Map<String, ui.Image>.of(art.images);
      bundle.failure = 'assets/images/world-desert.webp';
      await expectLater(
        art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior),
        throwsStateError,
      );
      expect(art.images.keys, unorderedEquals(original.keys));
      for (final entry in original.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
      bundle.failure = null;
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images['actors-hero'], isNotNull);
      expect(art.images['settlement-forest'], isNotNull);
      expect(art.images['village-blended'], isNull);
      final reads = bundle.reads.length;
      bundle.failure = '*';
      await art.ensureStage(WorldStage.future, heroClass: HeroClass.mage);
      expect(
        bundle.reads.length,
        reads,
        reason: 'future stage sources were retained before play',
      );
      for (final entry in original.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
    },
  );
}
