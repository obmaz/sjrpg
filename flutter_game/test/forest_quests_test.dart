import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/forest_quests.dart';

void main() {
  ForestQuestLedger reload(ForestQuestLedger ledger) =>
      ForestQuestLedger.fromSave(jsonDecode(jsonEncode(ledger.toSave())))!;

  test(
    'old cleared forest sites stay completed and cannot award a second reward',
    () {
      final q = ForestQuestLedger.fromSave(
        null,
        completedSiteIds: ['roots', 'sun'],
      )!;
      expect(q['roots']!.phase, ForestQuestPhase.completed);
      expect(q['sun']!.phase, ForestQuestPhase.completed);
      expect(q['moon']!.phase, ForestQuestPhase.offered);
      expect(q.claimReward('roots'), isNull);
      expect(q.claimReward('sun'), isNull);
      expect(q.accept('sun'), false);
      expect(q.accept('unknown'), false);
      expect(forestQuests.map((q) => q.kind).toSet().length, 3);
      expect(forestQuests.map((q) => q.giverPlace).toSet().length, 3);
    },
  );

  test(
    'a parcel requires NPC acceptance, pickup, delivery and one reward claim',
    () {
      var q = ForestQuestLedger();
      expect(q.collectParcel(), false);
      expect(q.deliverParcel(), false);
      expect(q.claimReward('moon'), isNull);
      expect(q.accept('moon'), true);
      expect(q.deliverParcel(), false);
      expect(q.collectParcel(), true);
      expect(q.collectParcel(), false);
      q = reload(q);
      expect(q['moon']!.hasParcel, true);
      expect(q['moon']!.currentObjective, contains('약초사 노아'));
      expect(q.deliverParcel(), true);
      expect(q.deliverParcel(), false);
      expect(q['moon']!.hasParcel, false);
      expect(q['moon']!.phase, ForestQuestPhase.ready);
      final reward = q.claimReward('moon')!;
      expect(reward.gold, 55);
      expect(reward.experience, 50 * CombatBalance.experienceRewardMultiplier);
      expect(q.claimReward('moon'), isNull);
      expect(reload(q).claimReward('moon'), isNull);
    },
  );

  test(
    'an altar cannot self-give a cleansing quest or complete another objective',
    () {
      final q = ForestQuestLedger();
      expect(q.cleanseAltar(), false);
      expect(q.accept('roots'), true);
      expect(q.cleanseAltar(), true);
      expect(q.cleanseAltar(), false);
      expect(q['roots']!.phase, ForestQuestPhase.ready);
      expect(q['moon']!.phase, ForestQuestPhase.offered);
      expect(q['sun']!.phase, ForestQuestPhase.offered);
      expect(q.claimReward('roots'), isNotNull);
      expect(q.accept('roots'), false);
    },
  );

  test('protection needs thirty real seconds AND all three finite threats', () {
    final q = ForestQuestLedger();
    expect(q.beginProtection(), false);
    expect(q.accept('sun'), true);
    expect(q.beginProtection(), true);
    expect(q.beginProtection(), false);
    final attempt = q['sun']!.attempt;
    expect(q.recordThreatDefeated(0, attempt: attempt), true);
    expect(q.recordThreatDefeated(0, attempt: attempt), false);
    expect(q.recordThreatDefeated(1, attempt: attempt), true);
    expect(q.recordThreatDefeated(2, attempt: attempt), true);
    expect(q['sun']!.remainingThreatTokens, isEmpty);
    expect(q['sun']!.phase, ForestQuestPhase.accepted);
    q.advanceProtection(
      30 * CombatBalance.gameSpeed - .1,
      defenderPresent: true,
    );
    expect(q.claimReward('sun'), isNull);
    q.advanceProtection(.1, defenderPresent: true);
    expect(q['sun']!.phase, ForestQuestPhase.ready);
    expect(q.claimReward('sun'), isNotNull);
    expect(q.claimReward('sun'), isNull);
  });

  test(
    'elapsed defense time cannot complete while finite threats are alive',
    () {
      final q = ForestQuestLedger()
        ..accept('sun')
        ..beginProtection();
      q.advanceProtection(9999, defenderPresent: true);
      expect(q['sun']!.protectedFor, ForestQuestProgress.protectionDuration);
      expect(q['sun']!.phase, ForestQuestPhase.accepted);
      expect(q['sun']!.threatsRemaining, 3);
      for (var token = 0; token < 3; token++) {
        expect(q.recordThreatDefeated(token, attempt: q['sun']!.attempt), true);
      }
      expect(q['sun']!.phase, ForestQuestPhase.ready);
    },
  );

  test(
    'NPC death wins over final-second completion; invalid damage is ignored',
    () {
      final q = ForestQuestLedger()
        ..accept('sun')
        ..beginProtection();
      final attempt = q['sun']!.attempt;
      q.advanceProtection(
        ForestQuestProgress.protectionDuration - .1,
        defenderPresent: true,
      );
      expect(q.damageDefender(double.nan), false);
      expect(q.damageDefender(-1), false);
      expect(q.damageDefender(1, attempt: attempt + 1), false);
      expect(
        q.damageDefender(
          ForestQuestProgress.maximumDefenderHealth,
          attempt: attempt,
        ),
        true,
      );
      q.advanceProtection(1, defenderPresent: true);
      expect(q['sun']!.phase, ForestQuestPhase.failed);
      expect(q['sun']!.failure, ForestQuestFailure.defenderFallen);
      expect(q.recordThreatDefeated(0, attempt: attempt), false);
      expect(q.claimReward('sun'), isNull);
    },
  );

  test(
    'retry resets NPC health and the finite wave, rejecting old-attempt deaths',
    () {
      final q = ForestQuestLedger()
        ..accept('sun')
        ..beginProtection();
      final oldAttempt = q['sun']!.attempt;
      q.recordThreatDefeated(0, attempt: oldAttempt);
      q.damageDefender(20);
      q.advanceProtection(5, defenderPresent: true);
      q.advanceProtection(.1, defenderPresent: false);
      expect(q['sun']!.failure, ForestQuestFailure.abandoned);
      expect(q.retryProtection(), true);
      expect(q['sun']!.protectedFor, 0);
      expect(
        q['sun']!.defenderHealth,
        ForestQuestProgress.maximumDefenderHealth,
      );
      expect(q['sun']!.remainingThreatTokens.toList(), [0, 1, 2]);
      expect(q.beginProtection(), true);
      expect(q['sun']!.attempt, oldAttempt + 1);
      expect(q.recordThreatDefeated(0, attempt: oldAttempt), false);
      expect(q.recordThreatDefeated(0, attempt: q['sun']!.attempt), true);
    },
  );

  test(
    'mid-protection checkpoint retains exact time, NPC damage, attempt and tokens',
    () {
      final q = ForestQuestLedger()
        ..accept('sun')
        ..beginProtection();
      q.advanceProtection(12.75, defenderPresent: true);
      q.damageDefender(17.25);
      q.recordThreatDefeated(1, attempt: q['sun']!.attempt);
      final restored = reload(q)['sun']!;
      expect(restored.protectionActive, true);
      expect(restored.protectedFor, 12.75);
      expect(restored.defenderHealth, 222.75);
      expect(restored.attempt, q['sun']!.attempt);
      expect(restored.remainingThreatTokens.toList(), [0, 2]);
    },
  );

  test(
    'malformed checkpoint state cannot create invalid timers or duplicate deaths',
    () {
      Map<String, dynamic> save() =>
          jsonDecode(jsonEncode(ForestQuestLedger().toSave()));
      for (final value in [
        double.nan,
        -1,
        ForestQuestProgress.protectionDuration + 1,
      ]) {
        final raw = save();
        raw['quests']['sun']['protectedFor'] = value;
        expect(ForestQuestLedger.fromSave(raw), isNull);
      }
      for (final tokens in [
        [0, 0],
        [-1],
        [3],
      ]) {
        final raw = save();
        raw['quests']['sun']['defeatedThreats'] = tokens;
        expect(ForestQuestLedger.fromSave(raw), isNull);
      }
      final unknown = save();
      unknown['quests']['unknown'] = unknown['quests']['sun'];
      expect(ForestQuestLedger.fromSave(unknown), isNull);
      final wrongKind = save();
      wrongKind['quests']['moon']['cleansed'] = true;
      expect(ForestQuestLedger.fromSave(wrongKind), isNull);
    },
  );
  test(
    'protection parser rejects pre-filled kills, dead active NPCs and stale failure flags',
    () {
      Map<String, dynamic> save() =>
          jsonDecode(jsonEncode(ForestQuestLedger().toSave()));
      for (final change in <Map<String, dynamic>>[
        {
          'defeatedThreats': [0],
        },
        {'protectedFor': 1},
        {'attempt': 1},
        {'defenderHealth': 200},
        {
          'phase': 'accepted',
          'protectionStarted': true,
          'attempt': 1,
          'defenderHealth': 0,
        },
        {
          'phase': 'accepted',
          'protectionStarted': true,
          'attempt': 1,
          'failure': 'abandoned',
        },
        {'phase': 'completed', 'protectionStarted': true, 'attempt': 1},
      ]) {
        final raw = save();
        (raw['quests']['sun'] as Map).addAll(change);
        expect(ForestQuestLedger.fromSave(raw), isNull, reason: '$change');
      }
      final active = ForestQuestLedger()
        ..accept('sun')
        ..beginProtection();
      active.damageDefender(20);
      active.failProtection(ForestQuestFailure.abandoned);
      final migrated = ForestQuestLedger.fromSave(
        active.toSave(),
        completedSiteIds: ['sun'],
      )!;
      expect(migrated['sun']!.phase, ForestQuestPhase.completed);
      expect(migrated.claimReward('sun'), isNull);
      expect(ForestQuestLedger.fromSave(migrated.toSave()), isNotNull);
    },
  );
}
