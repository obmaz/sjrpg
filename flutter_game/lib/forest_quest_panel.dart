import 'package:flutter/material.dart';

import 'back_actions.dart';
import 'combat_balance.dart';
import 'combat_numbers.dart';
import 'forest_quest_runtime.dart';
import 'forest_quests.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_widgets.dart';

class ForestQuestPanel extends StatefulWidget {
  const ForestQuestPanel({
    required this.runtime,
    required this.onClose,
    this.onCheckpoint,
    this.backActions,
    super.key,
  });
  final ForestQuestRuntime runtime;
  final VoidCallback onClose;
  final VoidCallback? onCheckpoint;
  final BackActions? backActions;
  @override
  State<ForestQuestPanel> createState() => _ForestQuestPanelState();
}

class _ForestQuestPanelState extends State<ForestQuestPanel> {
  VoidCallback? _stopBack;
  @override
  void initState() {
    super.initState();
    _stopBack = widget.backActions?.register(widget.onClose);
  }

  @override
  void dispose() {
    _stopBack?.call();
    super.dispose();
  }

  void perform() {
    final wasProtecting = widget.runtime.protectionActive;
    final changed = widget.runtime.performAction();
    if (changed) widget.onCheckpoint?.call();
    if (changed && !wasProtecting && widget.runtime.protectionActive) {
      widget.onClose();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xcc040d10),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  24,
            ),
            child: AnimatedBuilder(
              animation: widget.runtime.session,
              builder: (context, _) {
                final r = widget.runtime, q = r.selectedQuest;
                return FramedSurface(
                  art: r.session.art,
                  compact: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GamePanelHeader(
                        title: r.selectedNpc?.name ?? '의뢰 대화',
                        subtitle: q?.title,
                        closeLabel: '의뢰 대화 닫기',
                        onClose: widget.onClose,
                        dense: MediaQuery.sizeOf(context).height < 500,
                      ),
                      const Divider(height: 1, color: Color(0xff3b584c)),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                r.dialogue,
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 16,
                                  height: 1.65,
                                ),
                              ),
                              if (q != null) ...[
                                const SizedBox(height: 16),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xff173a34),
                                    border: Border.all(
                                      color: const Color(0xff42645b),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      q.currentObjective,
                                      style: const TextStyle(
                                        color: cream,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                if (q.definition.kind ==
                                        ForestQuestKind.protection &&
                                    q.protectionStarted &&
                                    q.phase != ForestQuestPhase.completed) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    '조사관 체력 ${CombatNumbers.stat(q.defenderHealth)} / ${CombatNumbers.stat(ForestQuestProgress.maximumDefenderHealth)}',
                                    style: const TextStyle(
                                      color: cream,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value:
                                        q.defenderHealth /
                                        ForestQuestProgress
                                            .maximumDefenderHealth,
                                    minHeight: 6,
                                    color: const Color(0xffdf6758),
                                    backgroundColor: const Color(0xff33272a),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '보호 ${CombatBalance.realSeconds(q.protectedFor).floor()}/30초 · 습격자 ${q.threatsRemaining}명 남음',
                                    style: const TextStyle(
                                      color: gold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  '보상 · ${q.definition.reward.gold} 골드 · 경험치 ${q.definition.reward.experience}',
                                  style: const TextStyle(
                                    color: gold,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              if (r.blockedReason != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  r.blockedReason!,
                                  style: const TextStyle(
                                    color: Color(0xffa8beb2),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: GameAction('닫기', onTap: widget.onClose),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GameAction(
                                r.actionLabel,
                                primary: true,
                                semanticLabel: '의뢰 ${r.actionLabel}',
                                semanticValue: r.blockedReason,
                                onTap: r.actionEnabled ? perform : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
