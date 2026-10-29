import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/title_screen.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

// A deterministic pause in the real page's artwork barrier. The renderer still
// uses actual decoded images, but timing does not depend on image codec speed.
class _GatedArt extends GameArt {
  _GatedArt(this.source, this.delayedStage) {
    images.addAll(source.images);
    materials.addAll(source.materials);
    actors = source.actors;
    controls = source.controls;
  }
  final GameArt source;
  final WorldStage delayedStage;
  final gate = Completer<void>();
  bool waiting = false, blocked = true;
  @override
  Future<void> ensureStage(
    WorldStage stage, {
    required HeroClass heroClass,
    Iterable<String> enemyKinds = const [],
  }) async {
    if (blocked && stage == delayedStage) {
      waiting = true;
      await gate.future;
    }
  }

  @override
  void dispose() {
    source.dispose();
    images.clear();
    materials.clear();
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

GameCheckpoint _clearedForest() {
  final source = Adventure(GameArt())..start(TestGame());
  source.cleansedSites.addAll(source.world.sites.map((site) => site.id));
  source.progress.bossDefeated = true;
  final result = GameCheckpoint.capture(source)!;
  source.dispose();
  return result;
}

void main() {
  testWidgets(
    'browser-route back cannot reach the defeated child during delayed retry preparation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final full = (await tester.runAsync(GameArt.load))!;
      final art = _GatedArt(full, WorldStage.forest)..blocked = false;
      addTearDown(art.dispose);
      addTearDown(() {
        if (!art.gate.isCompleted) art.gate.complete();
      });
      final source = Adventure(GameArt())..start(TestGame());
      inCombatField(source);
      source.afflictions.apply(PlayerStatus.poison);
      source.afflictions.poisonTick = .05;
      source.progress.hp = .1;
      source.syncLife();
      var stored = GameCheckpoint.capture(source)!.encode();
      source.dispose();
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => stored,
            writeCheckpoint: (value) {
              stored = value;
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
      final checkpointBeforeRetry = stored;
      art.blocked = true;
      await tester.tap(find.text('체크포인트 재도전'));
      await tester.pump();
      expect(art.waiting, isTrue);
      for (var i = 0; i < 3; i++) {
        // Both Flutter's route callback and the web popstate listener enter
        // EntryPage.handleBack before its child's BackActions handlers.
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(TitleScreen), findsNothing);
        expect(_session(tester), same(fallen));
        expect(fallen.disposed, isFalse);
        expect(stored, checkpointBeforeRetry);
      }
      art.gate.complete();
      await _until(
        tester,
        () => !identical(_session(tester), fallen) && _session(tester).ready,
      );
      expect(_session(tester).defeated, isFalse);
      expect(_session(tester).afflictions.active, isEmpty);
      expect(fallen.disposed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'keyboard cannot close a paused page while target artwork is pending',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final full = (await tester.runAsync(GameArt.load))!;
      final art = _GatedArt(full, WorldStage.sands);
      addTearDown(art.dispose);
      addTearDown(() {
        if (!art.gate.isCompleted) art.gate.complete();
      });
      var stored = _clearedForest().encode();
      await tester.pumpWidget(
        MaterialApp(
          home: EntryPage(
            loadArt: () async => art,
            readCheckpoint: () => stored,
            writeCheckpoint: (value) {
              stored = value;
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
      await tester.tap(find.text('제2장 의뢰 받기'));
      await tester.pump();
      expect(art.waiting, isTrue);
      expect(source.active, isFalse);
      // A physical keyboard can traverse controls behind a pointer-only barrier.
      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          source.active,
          isFalse,
          reason: 'pending transition must own a paused source',
        );
        expect(_session(tester), same(source));
      }
      art.gate.complete();
      await _until(
        tester,
        () =>
            _session(tester).world.stage == WorldStage.sands &&
            _session(tester).ready,
      );
      expect(source.disposed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final background in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
  ]) {
    for (final continuing in [false, true]) {
      testWidgets(
        'a ${continuing ? 'stage transition' : 'new adventure'} interrupted by $background stays paused until explicit resume',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          addTearDown(
            () => tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            ),
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final full = (await tester.runAsync(GameArt.load))!;
          final target = continuing ? WorldStage.sands : WorldStage.forest;
          final art = _GatedArt(full, target);
          addTearDown(art.dispose);
          addTearDown(() {
            if (!art.gate.isCompleted) art.gate.complete();
          });
          String? stored = continuing ? _clearedForest().encode() : null;
          await tester.pumpWidget(
            MaterialApp(
              home: EntryPage(
                loadArt: () async => art,
                readCheckpoint: () => stored,
                writeCheckpoint: (value) {
                  stored = value;
                  return true;
                },
              ),
            ),
          );
          await _until(
            tester,
            () => find.byType(TitleScreen).evaluate().isNotEmpty,
          );
          if (continuing) {
            await tester.tap(find.text('이어하기'));
            await _until(
              tester,
              () =>
                  find.byType(BonfireWidget).evaluate().isNotEmpty &&
                  _session(tester).ready,
            );
            await tester.tap(
              find.byWidgetPredicate(
                (widget) => widget is MenuButton && widget.label == '여정',
              ),
            );
            await tester.pump();
            await tester.tap(find.text('제2장 의뢰 받기'));
          } else {
            await tester.tap(find.text('시작'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('전사로 모험 시작'));
          }
          await tester.pump();
          expect(art.waiting, isTrue);
          tester.binding.handleAppLifecycleStateChanged(background);
          art.gate.complete();
          if (background == AppLifecycleState.hidden) {
            // Hidden Flutter pages do not schedule frames. Let preparation finish,
            // then reproduce returning before the new scene has been mounted.
            await tester.pump();
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          }
          await _until(
            tester,
            () =>
                find.byType(BonfireWidget).evaluate().isNotEmpty &&
                _session(tester).ready &&
                _session(tester).world.stage == target,
          );
          final session = _session(tester);
          expect(
            session.active,
            isFalse,
            reason: 'background transition must not start simulation',
          );
          expect(session.paused, isTrue);
          final elapsed = session.elapsed;
          await tester.pump(const Duration(seconds: 1));
          expect(session.elapsed, elapsed);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(
            session.paused,
            isTrue,
            reason: 'foreground alone must not dismiss pause',
          );
          await tester.tap(find.text('모험 계속하기'));
          await tester.pump();
          expect(session.active, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
