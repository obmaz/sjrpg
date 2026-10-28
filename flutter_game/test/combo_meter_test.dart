import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combo_feedback.dart';
import 'package:guardian_new/combo_meter.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/rpg_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'combo paints simulation data without consuming taps or a clock',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = ValueNotifier(const ComboHudState());
      addTearDown(state.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
              ComboMeterOverlay(
                feedback: state,
                viewport: const Size(390, 844),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(ComboMeter), findsNothing);
      state.value = const ComboHudState(
        active: true,
        count: 2,
        chainLength: 4,
        progress: .65,
        windowStart: .6,
        windowEnd: .8,
      );
      await tester.pump();
      expect(find.text('2 / 4 COMBO'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(ComboMeter)));
      await tester.pump(const Duration(seconds: 1));
      expect(taps, 1);
      expect(
        state.value.progress,
        .65,
        reason: 'UI cannot advance the judgement clock',
      );
      state.value = const ComboHudState(
        active: true,
        queued: true,
        count: 7,
        windowStart: .3,
        windowEnd: .5,
        traitProc: true,
      );
      await tester.pump();
      expect(find.text('7 COMBO ∞'), findsOneWidget);
      expect(find.text('연계 특성'), findsOneWidget);
      expect(tester.takeException(), isNull);
      state.value = const ComboHudState();
      await tester.pump();
      expect(find.byType(ComboMeter), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'cursor follows timing data and queued success stays in the target window',
    () async {
      Future<Uint8List> paint(ComboHudState state) async {
        final r = ui.PictureRecorder();
        ComboTimingPainter(state).paint(ui.Canvas(r), const Size(200, 14));
        final p = r.endRecording(), image = await p.toImage(200, 14);
        p.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final result = Uint8List.fromList(data.buffer.asUint8List());
        image.dispose();
        return result;
      }

      List<int> pixel(Uint8List data, int x) =>
          data.sublist((7 * 200 + x) * 4, (7 * 200 + x) * 4 + 4);
      final early = await paint(
        const ComboHudState(
          active: true,
          progress: .25,
          windowStart: .6,
          windowEnd: .8,
        ),
      );
      final late = await paint(
        const ComboHudState(
          active: true,
          progress: .8,
          windowStart: .6,
          windowEnd: .8,
        ),
      );
      final queued = await paint(
        const ComboHudState(
          active: true,
          queued: true,
          progress: 0,
          windowStart: .6,
          windowEnd: .8,
        ),
      );
      expect(pixel(early, 55)[0], greaterThan(200));
      expect(pixel(late, 55)[0], lessThan(200));
      expect(
        pixel(queued, 136)[0],
        greaterThan(200),
        reason: 'queued success holds within highlighted interval',
      );
      expect(
        pixel(queued, 10)[0],
        lessThan(200),
        reason: 'queued cursor cannot misleadingly reset to the beginning',
      );
    },
  );

  testWidgets(
    'learned combat controls and hero remain clear in portrait and landscape',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final art = await tester.runAsync(GameArt.load);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: GamePage(art: art!, onRestart: () {}),
        ),
      );
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      final hero =
          tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
              as Guardian;
      final s = hero.session;
      expect(s.ready, true);
      s.progress.gainXp(8000);
      s.progress.healingPotions = s.progress.energyPotions = 128;
      const ids = ['whirlwind', 'frenzy', 'warcry', 'seismicSlam'];
      s.progress.ranks.addAll({
        for (final id in ids) id: 1,
        s.progress.mobilitySkill.id: 1,
      });
      for (var i = 0; i < ids.length; i++) {
        expect(s.progress.selectSkill(ids[i], slot: i), true);
      }
      s.refresh();
      s.game!.pauseEngine();
      for (final inset in [0.0, 21.0, 34.0]) {
        tester.view.padding = FakeViewPadding(bottom: inset);
        for (final size in const [
          Size(390, 844),
          Size(390, 650),
          Size(320, 420),
          Size(300, 450),
          Size(568, 320),
          Size(844, 390),
          Size(756, 420),
          Size(1080, 720),
        ]) {
          tester.view.physicalSize = size;
          hero.comboHud.value = const ComboHudState(
            active: true,
            count: 7,
            progress: .4,
            windowStart: .3,
            windowEnd: .6,
          );
          await tester.pump();
          final meter = find.byType(ComboMeter);
          expect(meter, findsOneWidget, reason: '$size');
          final r = tester.getRect(meter);
          expect((Offset.zero & size).contains(r.topLeft), true);
          expect((Offset.zero & size).contains(r.bottomRight), true);
          for (final type in [
            ActionButton,
            GameStick,
            MenuButton,
            PotionBelt,
          ]) {
            final targets = find.byType(type);
            for (var i = 0; i < targets.evaluate().length; i++) {
              expect(
                r.overlaps(tester.getRect(targets.at(i))),
                false,
                reason:
                    '$size $r overlaps $type ${tester.getRect(targets.at(i))}',
              );
            }
          }
          final heroPoint = Offset(
            size.width / 2,
            size.height / 2 - (size.width < 400 && size.height < 520 ? 36 : 0),
          );
          expect(
            r.overlaps(
              Rect.fromCenter(center: heroPoint, width: 70, height: 90),
            ),
            false,
            reason: 'meter must leave the body visible at $size',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$size at 1.3 text scale',
          );
        }
      }
      s.pause();
      await tester.pump();
      expect(
        find.byType(ComboMeter),
        findsNothing,
        reason: 'paused combat has no moving combo HUD',
      );
      await tester.pumpWidget(const SizedBox());
      art.dispose();
    },
  );
}
