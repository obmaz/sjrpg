import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

import 'support/test_game.dart';

class _ControlArt extends GameArt {
  @override
  void control(ui.Canvas canvas, String key, ui.Rect destination) {}
}

void main() {
  Future<Adventure> showControls(
    WidgetTester tester, {
    bool secondCoolingDown = false,
  }) async {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.progress.ranks.addAll({'charge': 1, 'crushingBlow': 1});
    expect(s.progress.selectSkill('charge'), true);
    expect(s.progress.selectSkill('crushingBlow', slot: 1), true);
    if (secondCoolingDown) s.hero.cooldowns['crushingBlow'] = 2;

    Widget button(int slot) => ActionButton(
      key: ValueKey(slot),
      art: _ControlArt(),
      sprite: 'roundEmpty',
      label: '',
      semanticLabel: 'skill $slot',
      size: 64,
      showLabel: false,
      remaining: s.hero.cooldowns[s.progress.skillAt(slot)!.id] ?? 0,
      onTap: () => s.hero.skill(slot: slot),
      onAimStart: () => s.hero.beginAim(slot),
      onAimMove: (delta) => s.hero.moveAim(delta, ownerSlot: slot),
      onAimEnd: (cancelled) => s.hero.finishAim(cancelled, ownerSlot: slot),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [button(0), const SizedBox(width: 40), button(1)],
          ),
        ),
      ),
    );
    return s;
  }

  Future<TestGesture> press(WidgetTester tester, int slot) =>
      tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(slot))),
        pointer: slot + 1,
      );

  for (final cancel in [false, true]) {
    testWidgets(
      '${cancel ? 'cancelling' : 'releasing'} an unavailable second skill preserves the first aim',
      (tester) async {
        final s = await showControls(tester, secondCoolingDown: true);
        final energy = s.progress.energy;
        final first = await press(tester, 0);
        expect(s.hero.aim?.id, 'charge');
        final second = await press(tester, 1);
        expect(s.hero.aim?.id, 'charge');
        await second.moveBy(const Offset(30, 40));
        expect(s.hero.aim?.delta, Offset.zero);

        if (cancel) {
          await second.cancel();
        } else {
          await second.up();
        }

        expect(s.progress.energy, energy);
        expect(s.hero.cooldowns['charge'], isNull);
        expect(s.hero.aim?.id, 'charge');
        await first.moveBy(const Offset(50, 0));
        expect(s.hero.aim?.delta, const Offset(50, 0));
        await first.cancel();
        expect(s.hero.aim, isNull);
        expect(s.progress.energy, energy);
      },
    );

    testWidgets(
      'the last valid aim survives the first finger ${cancel ? 'cancellation' : 'release'} and casts on its own release',
      (tester) async {
        final s = await showControls(tester);
        final energy = s.progress.energy;
        final first = await press(tester, 0);
        expect(s.hero.aim?.id, 'charge');
        final second = await press(tester, 1);
        expect(s.hero.aim?.id, 'crushingBlow');
        await first.moveBy(const Offset(50, 0));
        expect(s.hero.aim?.delta, Offset.zero);

        if (cancel) {
          await first.cancel();
        } else {
          await first.up();
        }

        expect(s.hero.aim?.id, 'crushingBlow');
        expect(s.hero.cooldowns['crushingBlow'], isNull);
        expect(s.progress.energy, energy);
        await second.moveBy(const Offset(0, -40));
        expect(s.hero.aim?.delta, const Offset(0, -40));
        await second.up();
        expect(s.hero.aim, isNull);
        expect(s.hero.cooldowns['charge'], isNull);
        expect(s.hero.cooldowns['crushingBlow'], greaterThan(0));
        expect(s.hero.heavyWindup, greaterThan(0));
        expect(s.progress.energy, energy - 22);
      },
    );
  }
}
