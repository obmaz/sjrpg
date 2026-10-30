import 'combat_balance.dart';

enum ForestQuestKind { cleanse, delivery, protection }

enum ForestQuestPhase { offered, accepted, ready, failed, completed }

enum ForestQuestFailure { defenderFallen, abandoned, blocked }

enum ForestQuestPlace { villageSupply, chapel, woodlandCabin, caveWorksite }

class ForestQuestReward {
  const ForestQuestReward(this.gold, this.experience);
  final int gold, experience;
}

class ForestQuestDef {
  const ForestQuestDef({
    required this.id,
    required this.title,
    required this.kind,
    required this.giver,
    required this.recipient,
    required this.giverPlace,
    required this.targetPlace,
    required this.description,
    required this.gold,
    required this.baseExperience,
  });

  /// Existing site IDs remain the checkpoint and chapter-completion identities.
  final String id, title, giver, recipient, description;
  final ForestQuestKind kind;
  final ForestQuestPlace giverPlace, targetPlace;
  final int gold, baseExperience;
  ForestQuestReward get reward => ForestQuestReward(
    gold,
    baseExperience * CombatBalance.experienceRewardMultiplier,
  );
}

const forestQuests = [
  ForestQuestDef(
    id: 'roots',
    title: '예배당의 오래된 봉인',
    kind: ForestQuestKind.cleanse,
    giver: '수녀 엘린',
    recipient: '수녀 엘린',
    giverPlace: ForestQuestPlace.chapel,
    targetPlace: ForestQuestPlace.chapel,
    description: '작은 예배당을 위협하는 적을 정리하고 제단의 봉인을 정화해 주세요.',
    gold: 40,
    baseExperience: 40,
  ),
  ForestQuestDef(
    id: 'moon',
    title: '숲속 오두막의 약초 꾸러미',
    kind: ForestQuestKind.delivery,
    giver: '보급원 미라',
    recipient: '약초사 노아',
    giverPlace: ForestQuestPlace.villageSupply,
    targetPlace: ForestQuestPlace.woodlandCabin,
    description: '마을에서 약초 꾸러미를 받아 북동쪽 숲속 오두막의 약초사에게 전해 주세요.',
    gold: 55,
    baseExperience: 50,
  ),
  ForestQuestDef(
    id: 'sun',
    title: '동굴 조사관을 지켜라',
    kind: ForestQuestKind.protection,
    giver: '조사관 로웬',
    recipient: '조사관 로웬',
    giverPlace: ForestQuestPlace.caveWorksite,
    targetPlace: ForestQuestPlace.caveWorksite,
    description: '동굴 앞에서 기록을 해독하는 조사관을 30초 동안 지키고 습격자 세 명을 처치하세요.',
    gold: 70,
    baseExperience: 70,
  ),
];

ForestQuestDef? forestQuest(String id) {
  for (final quest in forestQuests) {
    if (quest.id == id) {
      return quest;
    }
  }
  return null;
}

class ForestQuestProgress {
  ForestQuestProgress(this.definition);
  final ForestQuestDef definition;
  ForestQuestPhase _phase = ForestQuestPhase.offered;
  bool _parcel = false, _cleansed = false, _protectionStarted = false;
  double _protectedFor = 0, _defenderHealth = maximumDefenderHealth;
  int _attempt = 0;
  final Set<int> _defeatedThreats = {};
  ForestQuestFailure? _failure;
  static const maximumDefenderHealth = 240.0;
  static const protectionDuration = 30 * CombatBalance.gameSpeed;
  static const threatCount = 3;
  ForestQuestPhase get phase => _phase;
  bool get hasParcel => _parcel;
  bool get cleansed => _cleansed;
  bool get protectionStarted => _protectionStarted;
  bool get protectionActive =>
      _phase == ForestQuestPhase.accepted && _protectionStarted;
  double get protectedFor => _protectedFor;
  double get defenderHealth => _defenderHealth;
  int get attempt => _attempt;
  int get threatsRemaining => threatCount - _defeatedThreats.length;
  Iterable<int> get remainingThreatTokens => Iterable<int>.generate(
    threatCount,
  ).where((id) => !_defeatedThreats.contains(id));
  ForestQuestFailure? get failure => _failure;
  String get title => definition.title;
  String get giver => definition.giver;
  String get recipient => definition.recipient;
  String get currentObjective {
    if (_phase == ForestQuestPhase.completed) {
      return '의뢰 완료';
    }
    if (_phase == ForestQuestPhase.offered) {
      return '$giver에게 의뢰를 받으세요.';
    }
    if (_phase == ForestQuestPhase.ready) {
      return '$recipient에게 완료를 보고하세요.';
    }
    if (_phase == ForestQuestPhase.failed) {
      return '$giver에게 말해 다시 준비하세요.';
    }
    return switch (definition.kind) {
      ForestQuestKind.cleanse => '예배당 주변의 적을 정리하고 제단을 정화하세요.',
      ForestQuestKind.delivery =>
        _parcel
            ? '숲속 오두막의 $recipient에게 약초 꾸러미를 전하세요.'
            : '$giver에게 약초 꾸러미를 받으세요.',
      ForestQuestKind.protection =>
        !_protectionStarted
            ? '$giver에게 말을 걸어 조사를 시작하세요.'
            : '조사관 보호 ${CombatBalance.realSeconds(_protectedFor).floor()}/30초 · 습격자 $threatsRemaining명 남음',
    };
  }

  void _checkProtection() {
    if (protectionActive &&
        _defenderHealth > 0 &&
        _protectedFor >= protectionDuration &&
        threatsRemaining == 0) {
      _phase = ForestQuestPhase.ready;
    }
  }

  Map<String, dynamic> toSave() => {
    'phase': _phase.name,
    'parcel': _parcel,
    'cleansed': _cleansed,
    'protectionStarted': _protectionStarted,
    'protectedFor': _protectedFor,
    'defenderHealth': _defenderHealth,
    'attempt': _attempt,
    'defeatedThreats': _defeatedThreats.toList()..sort(),
    'failure': _failure?.name,
  };
}

/// The ledger never awards resources itself. A successful claim returns the one
/// reward transaction for Adventure to apply and mark in cleansedSites.
class ForestQuestLedger {
  ForestQuestLedger({Iterable<String> completedSiteIds = const []}) {
    final completed = completedSiteIds.toSet();
    for (final def in forestQuests) {
      final state = ForestQuestProgress(def);
      if (completed.contains(def.id)) state._phase = ForestQuestPhase.completed;
      _quests[def.id] = state;
    }
  }
  final Map<String, ForestQuestProgress> _quests = {};
  Iterable<ForestQuestProgress> get quests => _quests.values;
  ForestQuestProgress? operator [](String id) => _quests[id];
  bool accept(String id) {
    final q = _quests[id];
    if (q == null || q.phase != ForestQuestPhase.offered) {
      return false;
    }
    q._phase = ForestQuestPhase.accepted;
    return true;
  }

  bool collectParcel() {
    final q = _quests['moon']!;
    if (q.phase != ForestQuestPhase.accepted || q._parcel) {
      return false;
    }
    q._parcel = true;
    return true;
  }

  bool deliverParcel() {
    final q = _quests['moon']!;
    if (q.phase != ForestQuestPhase.accepted || !q._parcel) {
      return false;
    }
    q._parcel = false;
    q._phase = ForestQuestPhase.ready;
    return true;
  }

  bool cleanseAltar() {
    final q = _quests['roots']!;
    if (q.phase != ForestQuestPhase.accepted || q._cleansed) {
      return false;
    }
    q._cleansed = true;
    q._phase = ForestQuestPhase.ready;
    return true;
  }

  bool beginProtection() {
    final q = _quests['sun']!;
    if (q.phase != ForestQuestPhase.accepted || q._protectionStarted) {
      return false;
    }
    q._protectionStarted = true;
    q._attempt++;
    return true;
  }

  bool damageDefender(double amount, {int? attempt}) {
    final q = _quests['sun']!;
    if (!q.protectionActive ||
        attempt != null && attempt != q.attempt ||
        !amount.isFinite ||
        amount <= 0) {
      return false;
    }
    q._defenderHealth = (q._defenderHealth - amount).clamp(
      0,
      ForestQuestProgress.maximumDefenderHealth,
    );
    if (q._defenderHealth == 0) {
      failProtection(ForestQuestFailure.defenderFallen);
    }
    return true;
  }

  void advanceProtection(double dt, {required bool defenderPresent}) {
    final q = _quests['sun']!;
    if (!q.protectionActive || !dt.isFinite || dt <= 0) return;
    if (!defenderPresent) {
      failProtection(ForestQuestFailure.abandoned);
      return;
    }
    q._protectedFor = (q._protectedFor + dt).clamp(
      0,
      ForestQuestProgress.protectionDuration,
    );
    q._checkProtection();
  }

  bool recordThreatDefeated(int token, {required int attempt}) {
    final q = _quests['sun']!;
    if (!q.protectionActive ||
        attempt != q.attempt ||
        token < 0 ||
        token >= ForestQuestProgress.threatCount ||
        !q._defeatedThreats.add(token)) {
      return false;
    }
    q._checkProtection();
    return true;
  }

  bool failProtection(ForestQuestFailure reason) {
    final q = _quests['sun']!;
    if (!q.protectionActive) {
      return false;
    }
    q._phase = ForestQuestPhase.failed;
    q._failure = reason;
    return true;
  }

  bool retryProtection() {
    final q = _quests['sun']!;
    if (q.phase != ForestQuestPhase.failed) {
      return false;
    }
    q._phase = ForestQuestPhase.accepted;
    q._protectionStarted = false;
    q._protectedFor = 0;
    q._defenderHealth = ForestQuestProgress.maximumDefenderHealth;
    q._defeatedThreats.clear();
    q._failure = null;
    return true;
  }

  ForestQuestReward? claimReward(String id) {
    final q = _quests[id];
    if (q == null || q.phase != ForestQuestPhase.ready) {
      return null;
    }
    q._phase = ForestQuestPhase.completed;
    return q.definition.reward;
  }

  Map<String, dynamic> toSave() => {
    'version': 1,
    'quests': {
      for (final entry in _quests.entries) entry.key: entry.value.toSave(),
    },
  };

  /// Missing data is an old checkpoint; old cleared sites count as already paid.
  static ForestQuestLedger? fromSave(
    Object? raw, {
    Iterable<String> completedSiteIds = const [],
  }) {
    if (raw == null) {
      return ForestQuestLedger(completedSiteIds: completedSiteIds);
    }
    try {
      if (raw is! Map || raw['version'] != 1 || raw['quests'] is! Map) {
        return null;
      }
      final ledger = ForestQuestLedger();
      final states = raw['quests'] as Map;
      if (states.keys.any(
        (key) => key is! String || forestQuest(key) == null,
      )) {
        return null;
      }
      for (final entry in states.entries) {
        final q = ledger._quests[entry.key]!;
        final data = entry.value;
        if (data is! Map) {
          return null;
        }
        final phase = ForestQuestPhase.values
            .where((p) => p.name == data['phase'])
            .firstOrNull;
        final parcel = data['parcel'],
            cleansed = data['cleansed'],
            started = data['protectionStarted'];
        final elapsed = data['protectedFor'],
            hp = data['defenderHealth'],
            attempt = data['attempt'];
        final defeated = data['defeatedThreats'];
        if (phase == null ||
            parcel is! bool ||
            cleansed is! bool ||
            started is! bool ||
            elapsed is! num ||
            !elapsed.isFinite ||
            elapsed < 0 ||
            elapsed > ForestQuestProgress.protectionDuration ||
            hp is! num ||
            !hp.isFinite ||
            hp < 0 ||
            hp > ForestQuestProgress.maximumDefenderHealth ||
            attempt is! int ||
            attempt < 0 ||
            attempt > 1000000 ||
            defeated is! List ||
            defeated.any(
              (id) =>
                  id is! int || id < 0 || id >= ForestQuestProgress.threatCount,
            ) ||
            defeated.toSet().length != defeated.length) {
          return null;
        }
        ForestQuestFailure? failure;
        if (data['failure'] != null) {
          failure = ForestQuestFailure.values
              .where((f) => f.name == data['failure'])
              .firstOrNull;
          if (failure == null) {
            return null;
          }
        }
        if (q.definition.kind != ForestQuestKind.delivery && parcel ||
            q.definition.kind != ForestQuestKind.cleanse && cleansed ||
            q.definition.kind != ForestQuestKind.protection &&
                (started ||
                    elapsed != 0 ||
                    hp != ForestQuestProgress.maximumDefenderHealth ||
                    attempt != 0 ||
                    defeated.isNotEmpty ||
                    failure != null)) {
          return null;
        }
        if (phase == ForestQuestPhase.offered &&
                (parcel || cleansed || started) ||
            phase == ForestQuestPhase.failed &&
                (q.definition.kind != ForestQuestKind.protection ||
                    failure == null) ||
            started && attempt == 0) {
          return null;
        }
        if (phase == ForestQuestPhase.ready &&
            switch (q.definition.kind) {
              ForestQuestKind.cleanse => !cleansed,
              ForestQuestKind.delivery => parcel,
              ForestQuestKind.protection =>
                !started ||
                    hp <= 0 ||
                    elapsed < ForestQuestProgress.protectionDuration ||
                    defeated.length != ForestQuestProgress.threatCount,
            }) {
          return null;
        }
        // Only protection owns damage, elapsed time and finite threat tokens.
        // A fresh or retried attempt has no pre-filled kills or hidden timer.
        if (!started &&
            (elapsed != 0 ||
                hp != ForestQuestProgress.maximumDefenderHealth ||
                defeated.isNotEmpty ||
                failure != null)) {
          return null;
        }
        if (phase == ForestQuestPhase.offered && attempt != 0) {
          return null;
        }
        if (failure != null && phase != ForestQuestPhase.failed) {
          return null;
        }
        if (phase == ForestQuestPhase.failed && !started) {
          return null;
        }
        if (phase == ForestQuestPhase.accepted && started && hp <= 0) {
          return null;
        }
        if (phase == ForestQuestPhase.accepted && cleansed) {
          return null;
        }
        if (phase == ForestQuestPhase.completed && parcel) {
          return null;
        }
        if (phase == ForestQuestPhase.completed &&
            started &&
            (hp <= 0 ||
                elapsed < ForestQuestProgress.protectionDuration ||
                defeated.length != ForestQuestProgress.threatCount)) {
          return null;
        }
        if (failure == ForestQuestFailure.defenderFallen && hp != 0) {
          return null;
        }
        q._phase = phase;
        q._parcel = parcel;
        q._cleansed = cleansed;
        q._protectionStarted = started;
        q._protectedFor = elapsed.toDouble();
        q._defenderHealth = hp.toDouble();
        q._attempt = attempt;
        q._defeatedThreats.addAll(defeated.cast<int>());
        q._failure = failure;
      }
      for (final id in completedSiteIds) {
        final previous = ledger._quests[id];
        if (previous != null && previous.phase != ForestQuestPhase.completed) {
          ledger._quests[id] = ForestQuestProgress(previous.definition)
            .._phase = ForestQuestPhase.completed;
        }
      }
      return ledger;
    } catch (_) {
      return null;
    }
  }
}
