import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/health_widgets.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  for (final hero in HeroClass.values) {
    for (final size in [const Size(320, 420), const Size(844, 390)]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          '$hero portrait and all gauge labels keep separate readable space $size x$scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
            addTearDown(s.dispose);
            addTearDown(s.art.dispose);
            s.progress.level = 30;
            s.progress.hp = s.progress.maxHp * .56;
            if (hero == HeroClass.mage) {
              s.progress.skillPoints = 100;
              trainSkill(s.progress, 'blink');
              s.progress.energy = s.progress.maxEnergy;
              inCombatField(s);
            }
            final output = Platform.environment['SJRPG_HUD_JOIN_PROOF_DIR'];
            if (output != null) {
              Directory(output).createSync(recursive: true);
              File(
                '$output/${hero.name}-checkpoint.json',
              ).writeAsStringSync(GameCheckpoint.capture(s)!.encode());
            }
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: PlayerHealthFeedbackScope(
                    session: s,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GameHud(s),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final portrait = tester.getRect(
              find.byKey(const ValueKey('hud-portrait')),
            );
            final identity = tester.getRect(
              find.byKey(const ValueKey('hud-identity')),
            );
            final health = tester.getRect(find.byType(HealthMeter));
            final resource = tester.getRect(find.byType(ResourceMeter));
            final xp = tester.getRect(
              find.byKey(const ValueKey('hud-experience')),
            );
            final chrome = tester.getRect(
              find.byKey(const ValueKey('hud-status-chrome')),
            );
            final hpText = tester.getRect(
              find.text('${s.progress.hp.ceil()} / ${s.progress.maxHp.ceil()}'),
            );
            final resourceText = tester.getRect(
              find.text('${hero.resource} ${s.progress.energy.floor()}'),
            );
            expect(hpText.left, greaterThanOrEqualTo(portrait.right + 4));
            expect(resourceText.left, greaterThanOrEqualTo(portrait.right + 4));
            expect(identity.bottom, lessThanOrEqualTo(health.top));
            expect(health.bottom, lessThan(resource.top));
            expect(resource.bottom, lessThan(xp.top));
            expect(xp.bottom, lessThan(chrome.bottom));
            expect(tester.takeException(), null);
          },
        );
      }
    }
  }
}
