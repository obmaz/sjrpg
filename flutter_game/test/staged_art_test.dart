import 'dart:async';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/entry_loading.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/title_screen.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _TrackingBundle extends CachingAssetBundle {
  final reads = <String>[];
  String? failure;
  String? delayed;
  String? corrupt;
  Completer<void>? gate;

  @override
  Future<ByteData> load(String key) async {
    reads.add(key);
    if (key == delayed) await gate?.future;
    if (failure == '*' || key == failure) {
      throw StateError('An asset is temporarily unavailable');
    }
    final data = await rootBundle.load(key);
    if (key == corrupt) {
      final damaged = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      )..fillRange(0, 32, 0);
      return ByteData.sublistView(damaged);
    }
    return data;
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 800; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (ready()) return;
  }
  fail('The requested scene did not become ready');
}

Adventure _session(WidgetTester tester) =>
    (tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
            as Guardian)
        .session;

GameCheckpoint _savedForest() {
  final session = Adventure(GameArt())..start(TestGame());
  try {
    session.cleansedSites.addAll(session.world.sites.map((site) => site.id));
    session.progress.bossDefeated = true;
    return GameCheckpoint.capture(session)!;
  } finally {
    session.dispose();
  }
}

GameCheckpoint _savedFutureWithTroll() {
  final session = Adventure(GameArt(), stage: WorldStage.future)
    ..start(TestGame());
  try {
    inCombatField(session);
    expect(session.spawnEnemy('troll', session.hero.body.center), isNotNull);
    return GameCheckpoint.capture(session)!;
  } finally {
    session.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'async death retry cleanses poison only after normal continue and retains off-biome enemy power',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = Adventure(GameArt(), stage: WorldStage.future)
        ..start(TestGame());
      inCombatField(source);
      final enemy = source.spawnEnemy(
        'troll',
        source.hero.body.center + const Offset(350, 0),
        tier: EnemyTier.unique,
        trait: EnemyTrait.armored,
      )!;
      enemy.life.update(enemy.life.max * .4);
      enemy.wardPhase = 5.5;
      final expectedPower = enemy.power.toSave();
      final expectedHealth = enemy.life.value;
      source.afflictions.apply(PlayerStatus.poison, potency: 1.4);
      source.afflictions.poisonTick = .05;
      source.progress.hp = .1;
      source.syncLife();
      final checkpoint = GameCheckpoint.capture(source)!;
      final inventory = checkpoint.progress.inventory
          .map((g) => g.toSave())
          .toList();
      source.dispose();
      var stored = checkpoint.encode();
      final savedPoison = <double>[];
      final bundle = _TrackingBundle();
      final art = (await tester.runAsync(
        () => GameArt.loadMenu(bundle: bundle),
      ))!;
      addTearDown(art.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => stored,
            writeCheckpoint: (value) {
              stored = value;
              final saved = GameCheckpoint.decode(value)!;
              savedPoison.add(
                (saved.data['afflictions']['poison'] as num).toDouble(),
              );
              return true;
            },
          ),
        ),
      );
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).defeated,
      );
      final fallen = _session(tester);
      final survivor = fallen.mobs.singleWhere((mob) => mob.kind == 'troll');
      expect(survivor.isUnique, isTrue);
      expect(survivor.power.toSave(), expectedPower);
      expect(survivor.life.value, expectedHealth);
      expect(art.images['actors-walk-troll'], isNotNull);
      expect(savedPoison, isNotEmpty);
      expect(
        savedPoison.first,
        greaterThan(0),
        reason: 'normal continue must preserve poison',
      );
      final paidInventory = fallen.progress.inventory
          .map((g) => g.toSave())
          .toList();
      expect(paidInventory.length, inventory.length - 1);
      final reads = bundle.reads.length;
      bundle.failure = '*';
      await tester.tap(find.text('체크포인트 재도전'));
      await _until(
        tester,
        () => !identical(_session(tester), fallen) && _session(tester).ready,
      );
      final revived = _session(tester);
      revived.pause();
      expect(revived.defeated, isFalse);
      expect(revived.afflictions.active, isEmpty);
      expect(revived.progress.hp, greaterThan(0));
      expect(
        revived.progress.inventory.map((g) => g.toSave()).toList(),
        paidInventory,
      );
      // Death now returns to camp; field survivors stay dormant at that distance.
      expect(revived.hero.revivalProtection, greaterThan(0));
      inCombatField(revived);
      revived.wakeEnemies();
      await _until(
        tester,
        () => revived.mobs.any((mob) => mob.kind == 'troll'),
      );
      final enemyAgain = revived.mobs.singleWhere((mob) => mob.kind == 'troll');
      expect(enemyAgain.isUnique, isTrue);
      expect(enemyAgain.power.toSave(), expectedPower);
      expect(enemyAgain.life.value, expectedHealth);
      expect(
        savedPoison.last,
        0,
        reason: 'only explicit death retry cleanses its new snapshot',
      );
      expect(
        bundle.reads.length,
        reads,
        reason: 'retry must reuse already prepared artwork',
      );
      expect(checkpoint.data['afflictions']['poison'], 3.6);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'a saved enemy outside the stage population is ready and later visits reuse images',
    () async {
      final bundle = _TrackingBundle();
      final art = await GameArt.loadMenu(bundle: bundle);
      addTearDown(art.dispose);
      final menuImages = Map<String, ui.Image>.of(art.images);
      await art.ensureStage(
        WorldStage.future,
        heroClass: HeroClass.mage,
        enemyKinds: ['troll'],
      );
      final image = art.images['actors-walk-troll']!;
      final recorder = ui.PictureRecorder();
      art.actor(
        ui.Canvas(recorder),
        'troll',
        const ui.Offset(80, 110),
        1,
        0,
        90,
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(160, 130);
      picture.dispose();
      final rgba = (await rendered.toByteData())!.buffer.asUint8List();
      rendered.dispose();
      expect(rgba.any((value) => value != 0), isTrue);
      final reads = bundle.reads.length;
      await art.ensureStage(
        WorldStage.future,
        heroClass: HeroClass.mage,
        enemyKinds: ['troll'],
      );
      expect(bundle.reads.length, reads);
      expect(art.images['actors-walk-troll'], same(image));
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images['actors-walk-troll'], same(image));
      expect(bundle.reads.length, reads);
      for (final entry in menuImages.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
    },
  );

  testWidgets(
    'actual entry keeps the menu usable after a failed start and waits before making a session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bundle = _TrackingBundle();
      final art = (await tester.runAsync(
        () => GameArt.loadMenu(bundle: bundle),
      ))!;
      addTearDown(art.dispose);
      final menuImages = Map<String, ui.Image>.of(art.images);
      await tester.pumpWidget(
        MaterialApp(home: EntryPage(loadArt: () async => art)),
      );
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('title-start')));
      await tester.pumpAndSettle();
      expect(find.byType(GamePage), findsNothing);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/select-scene.png'),
          tester.element(find.byKey(const ValueKey('select-start'))),
        ),
      );
      await tester.pump();
      final scene = find.descendant(
        of: find.image(const AssetImage('assets/images/select-scene.png')),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(scene).image, isNotNull);
      expect(
        bundle.reads.where((name) => name.contains('actors-walk-cyber')),
        isEmpty,
      );
      bundle.delayed = 'assets/images/actors-walk-goblin.webp';
      bundle.failure = bundle.delayed;
      bundle.gate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('select-start')));
      await tester.pump();
      expect(find.byType(GamePage), findsNothing);
      expect(find.byType(EntryPreparationPanel), findsOneWidget);
      bundle.gate!.complete();
      await _until(
        tester,
        () => find.byType(EntryPreparationPanel).evaluate().isEmpty,
      );
      expect(find.byType(GamePage), findsNothing);
      expect(art.materials, isEmpty);
      expect(art.images.keys, unorderedEquals(menuImages.keys));
      for (final entry in menuImages.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
      bundle.failure = null;
      bundle.delayed = null;
      await tester.tap(find.byKey(const ValueKey('select-start')));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).ready,
      );
      expect(_session(tester).world.stage, WorldStage.forest);
      for (final retired in [
        'fx-steel-whirlwind',
        'fx-warcry',
        'village-scene',
        'village-gardens',
        'village-cottage',
        'blacksmith-forge',
      ]) {
        expect(
          bundle.reads,
          isNot(contains('assets/images/$retired.webp')),
          reason: 'staged play does not fetch retired diagnostic artwork',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'continuing prepares an accepted saved enemy before creating its scene',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bundle = _TrackingBundle();
      final art = (await tester.runAsync(
        () => GameArt.loadMenu(bundle: bundle),
      ))!;
      addTearDown(art.dispose);
      final saved = _savedFutureWithTroll().encode();
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => saved,
            writeCheckpoint: (_) {
              writes++;
              return true;
            },
          ),
        ),
      );
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      bundle.failure = 'assets/images/actors-walk-troll.webp';
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () => find.byType(EntryPreparationPanel).evaluate().isEmpty,
      );
      expect(find.byType(GamePage), findsNothing);
      expect(writes, 0);
      bundle.failure = null;
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).ready,
      );
      expect(_session(tester).world.stage, WorldStage.future);
      await _until(
        tester,
        () => _session(
          tester,
        ).mobs.any((enemy) => enemy.kind == 'troll' && enemy.combatReady),
      );
      expect(
        bundle.reads
            .where((name) => name.endsWith('actors-walk-troll.webp'))
            .length,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'storage failure preserves the paused session and target save precedes replacement',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bundle = _TrackingBundle();
      final art = (await tester.runAsync(
        () => GameArt.loadMenu(bundle: bundle),
      ))!;
      addTearDown(art.dispose);
      var stored = _savedForest().encode();
      var rejectTargetSave = false;
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => stored,
            writeCheckpoint: (text) {
              final stage =
                  GameCheckpoint.decode(text)!.data['stage'] as String;
              events.add('save:$stage');
              if (rejectTargetSave && stage == 'sands') return false;
              stored = text;
              return true;
            },
          ),
        ),
      );
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).ready,
      );
      final source = _session(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is MenuButton && widget.label == '여정',
        ),
      );
      await tester.pump();
      final originalSave = stored;
      final oldImages = Map<String, ui.Image>.of(art.images);
      final readsBeforeTravel = bundle.reads.length;
      bundle.failure = '*';
      rejectTargetSave = true;
      await tester.tap(find.text('제2장 의뢰 받기'));
      await _until(
        tester,
        () =>
            source.saveFailed &&
            find.byType(EntryPreparationPanel).evaluate().isEmpty,
      );
      expect(_session(tester), same(source));
      expect(source.disposed, isFalse);
      expect(stored, originalSave);
      expect(source.active, isFalse);
      for (final entry in oldImages.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
      rejectTargetSave = false;
      events.clear();
      await tester.tap(find.text('제2장 의뢰 받기'));
      await _until(
        tester,
        () =>
            _session(tester).world.stage == WorldStage.sands &&
            _session(tester).ready,
      );
      expect(source.disposed, isTrue);
      expect(bundle.reads.length, readsBeforeTravel);
      expect(events.first, 'save:sands');
      expect(GameCheckpoint.decode(stored)!.data['stage'], 'sands');
      for (final entry in oldImages.entries) {
        expect(art.images[entry.key], same(entry.value));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a corrupt deferred image offers a real reload that preserves the checkpoint and restores travel',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var bundle = _TrackingBundle()..corrupt = 'assets/images/ruin-props.webp';
      var stored = _savedForest().encode();
      var reloads = 0;
      final checkpointAtReload = <String>[];
      final artwork = <GameArt>[];
      addTearDown(() {
        for (final art in artwork) {
          art.dispose();
        }
      });
      Future<GameArt> loadArtwork() async {
        final art = await GameArt.loadMenu(bundle: bundle);
        artwork.add(art);
        return art;
      }

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, reloadState) => MaterialApp(
            key: ValueKey(reloads),
            home: EntryPage(
              loadArt: loadArtwork,
              readCheckpoint: () => stored,
              writeCheckpoint: (text) {
                stored = text;
                return true;
              },
              reloadApplication: () {
                checkpointAtReload.add(stored);
                bundle = _TrackingBundle();
                reloadState(() => reloads++);
              },
            ),
          ),
        ),
      );
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).ready,
      );
      final source = _session(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is MenuButton && widget.label == '여정',
        ),
      );
      await tester.pump();
      final originalSave = stored;
      final originalReads = bundle.reads.length;
      bundle.failure = '*';
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('제2장 의뢰 받기'));
        await _until(
          tester,
          () => find.byType(EntryPreparationPanel).evaluate().isEmpty,
        );
        expect(_session(tester), same(source));
        expect(source.active, isFalse);
        expect(source.disposed, isFalse);
        expect(stored, originalSave);
        expect(bundle.reads.length, originalReads);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(SnackBarAction, '새로 열기'));
      await _until(
        tester,
        () => find.byType(TitleScreen).evaluate().isNotEmpty,
      );
      expect(reloads, 1);
      expect(checkpointAtReload, [originalSave]);
      expect(source.disposed, isTrue);
      expect(GameCheckpoint.decode(stored)!.data['stage'], 'forest');
      await tester.tap(find.text('이어하기'));
      await _until(
        tester,
        () =>
            find.byType(BonfireWidget).evaluate().isNotEmpty &&
            _session(tester).ready,
      );
      bundle.failure = '*';
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is MenuButton && widget.label == '여정',
        ),
      );
      await tester.pump();
      await tester.tap(find.text('제2장 의뢰 받기'));
      await _until(
        tester,
        () =>
            _session(tester).world.stage == WorldStage.sands &&
            _session(tester).ready,
      );
      expect(GameCheckpoint.decode(stored)!.data['stage'], 'sands');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
