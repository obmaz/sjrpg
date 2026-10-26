import 'dart:async' as async;
import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';

import 'adventure.dart';
import 'back_actions.dart';
import 'back_bridge.dart' as history;
import 'battle_effects.dart';
import 'class_selection.dart';
import 'destructible_chest.dart';
import 'game_art.dart';
import 'game_checkpoint.dart';
import 'game_panels.dart';
import 'game_ui.dart';
import 'nearby_controls.dart';
import 'panel_controls.dart';
import 'quest_giver.dart';
import 'quest_guide.dart';
import 'rpg_widgets.dart';
import 'sanctuary_fence.dart';
import 'save_bridge.dart' as storage;
import 'well_portal.dart';
import 'world_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '자연의 수호자',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Guardian',
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      scaffoldBackgroundColor: ink,
    ),
    home: const EntryPage(),
  );
}

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});
  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final backActions = BackActions();
  void Function()? stopBackListener;
  @override
  void initState() {
    super.initState();
    stopBackListener = history.listenForBack(handleBack);
  }

  void handleBack() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      backActions.dispatch();
    }
  }

  void returnToMenu() {
    final checkpoint = GameCheckpoint.decode(storage.readCheckpoint());
    setState(() {
      run++;
      started = false;
      resuming = false;
      enteringStage = false;
      arrivingByWell = false;
      savedAdventure = checkpoint;
      if (checkpoint != null) chosen = checkpoint.progress.heroClass;
    });
  }

  @override
  void dispose() {
    stopBackListener?.call();
    super.dispose();
  }

  late Future<GameArt> loading = GameArt.load();
  bool started = false;
  int run = 0;
  HeroClass chosen = HeroClass.warrior;
  GameCheckpoint? savedAdventure = GameCheckpoint.decode(
    storage.readCheckpoint(),
  );
  bool resuming = false, enteringStage = false, arrivingByWell = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) handleBack();
    },
    child: FutureBuilder<GameArt>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '그림을 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    GameAction(
                      '다시 불러오기',
                      primary: true,
                      icon: Icons.refresh,
                      onTap: () => setState(() => loading = GameArt.load()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: gold),
                  SizedBox(height: 24),
                  Text('모험의 풍경을 불러오고 있어요', style: TextStyle(color: cream)),
                ],
              ),
            ),
          );
        }
        final art = snapshot.data!;
        if (started) {
          return GamePage(
            key: ValueKey(run),
            backActions: backActions,
            onReturnToMenu: returnToMenu,
            art: art,
            heroClass: chosen,
            showStageBriefing: enteringStage,
            arrivingByWell: arrivingByWell,
            checkpoint: resuming ? savedAdventure : null,
            onAdvance: (checkpoint) => setState(() {
              run++;
              savedAdventure = checkpoint;
              enteringStage = true;
              arrivingByWell = false;
              resuming = true;
              started = true;
            }),
            onTravel: (checkpoint) => setState(() {
              run++;
              savedAdventure = checkpoint;
              enteringStage = false;
              arrivingByWell = true;
              resuming = true;
              started = true;
            }),
            onRetryCheckpoint: () {
              final checkpoint = GameCheckpoint.decode(
                storage.readCheckpoint(),
              );
              setState(() {
                run++;
                savedAdventure = checkpoint;
                enteringStage = false;
                arrivingByWell = false;
                resuming = checkpoint != null;
                started = checkpoint != null;
                if (checkpoint != null) chosen = checkpoint.progress.heroClass;
              });
            },
            onRestart: () => setState(() {
              run++;
              started = false;
              savedAdventure = null;
              resuming = false;
              enteringStage = false;
              arrivingByWell = false;
            }),
          );
        }
        return ClassSelection(
          art: art,
          continueSummary: savedAdventure?.summary,
          onContinue: savedAdventure == null
              ? null
              : () => setState(() {
                  chosen = savedAdventure!.progress.heroClass;
                  resuming = true;
                  enteringStage = false;
                  arrivingByWell = false;
                  started = true;
                }),
          onBegin: (value) => setState(() {
            chosen = value;
            resuming = false;
            enteringStage = false;
            arrivingByWell = false;
            started = true;
          }),
        );
      },
    ),
  );
}

class GamePage extends StatefulWidget {
  const GamePage({
    required this.art,
    required this.onRestart,
    this.heroClass = HeroClass.warrior,
    this.checkpoint,
    this.showStageBriefing = false,
    this.arrivingByWell = false,
    this.onRetryCheckpoint,
    this.onAdvance,
    this.onTravel,
    this.backActions,
    this.onReturnToMenu,
    super.key,
  });
  final GameCheckpoint? checkpoint;
  final bool showStageBriefing;
  final bool arrivingByWell;
  final HeroClass heroClass;
  final GameArt art;
  final VoidCallback onRestart;
  final VoidCallback? onRetryCheckpoint;
  final ValueChanged<GameCheckpoint>? onAdvance;
  final ValueChanged<GameCheckpoint>? onTravel;
  final BackActions? backActions;
  final VoidCallback? onReturnToMenu;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final Adventure adventure =
      widget.checkpoint?.restore(widget.art) ??
      Adventure(widget.art, heroClass: widget.heroClass);
  async.Timer? saveTimer;
  void Function()? stopSaveListener;
  void Function()? stopBackAction;
  bool keepSave = true;
  void saveNow({bool notify = true}) {
    if (!keepSave) return;
    final checkpoint = GameCheckpoint.capture(adventure);
    if (checkpoint == null) return;
    final failed = !storage.writeCheckpoint(checkpoint.encode());
    final changed = failed != adventure.saveFailed;
    adventure.saveFailed = failed;
    if (changed && notify && mounted && !adventure.disposed) {
      adventure.announce(
        failed ? '저장하지 못했습니다 · 설정에서 저장 상태를 확인하세요' : '자동 저장이 다시 작동합니다',
      );
    }
  }

  void advanceStage() {
    final next = GameCheckpoint.advance(adventure);
    if (next == null || widget.onAdvance == null) return;
    if (!storage.writeCheckpoint(next.encode())) {
      adventure.saveFailed = true;
      adventure.refresh();
      return;
    }
    keepSave = false;
    widget.onAdvance!(next);
  }

  void travelTo(WorldStage stage, String wellId) {
    if (widget.onTravel == null) return;
    final next = GameCheckpoint.warp(adventure, stage, wellId);
    if (next == null) return;
    if (!storage.writeCheckpoint(next.encode())) {
      adventure.saveFailed = true;
      adventure.refresh();
      return;
    }
    keepSave = false;
    widget.onTravel!(next);
  }

  void openWarp() {
    if (!adventure.active ||
        adventure.riding != null ||
        adventure.travelJournal.nearbyWell(
              adventure.world,
              adventure.hero.body.center,
            ) ==
            null) {
      return;
    }
    open('warp');
  }

  void restoreGameFocus() {
    if (mounted && adventure.active && panel == null) gameFocus.requestFocus();
  }

  NearbyControl nearbyControl(NearbyAction action) => NearbyControl(
    label: switch (action) {
      NearbyAction.shrine =>
        adventure.world.stage == WorldStage.sands ? '조사' : '정화',
      NearbyAction.mount =>
        adventure.nearbyMount?.durability == 0 ? '보수하기' : '타기',
      NearbyAction.dismount => '내리기',
      NearbyAction.shop => '상점',
      NearbyAction.talk => adventure.nearbyTimeGiver?.name ?? '대화',
    },
    icon: switch (action) {
      NearbyAction.shrine => Icons.water_drop_outlined,
      NearbyAction.mount => Icons.pets_outlined,
      NearbyAction.dismount => Icons.south_west,
      NearbyAction.shop => Icons.storefront,
      NearbyAction.talk => Icons.chat_bubble_outline,
    },
    condition: action == NearbyAction.mount || action == NearbyAction.dismount
        ? (adventure.serviceMount?.durability ?? 100) / 100
        : null,
    onTap: () {
      switch (action) {
        case NearbyAction.mount:
          if (adventure.nearbyMount?.durability == 0) {
            open('settings');
          } else if (adventure.boardNearbyMount()) {
            saveNow();
          }
        case NearbyAction.dismount:
          if (adventure.dismount()) saveNow();
        case NearbyAction.shrine:
          if (adventure.cleanseNearbySite()) saveNow();
        case NearbyAction.shop:
          open('shop');
        case NearbyAction.talk:
          open('talk');
      }
      restoreGameFocus();
    },
  );

  void abandon() {
    keepSave = false;
    storage.clearCheckpoint();
    widget.onRestart();
  }

  void returnToMenu() {
    if (widget.onReturnToMenu == null) return;
    saveNow();
    keepSave = false;
    widget.onReturnToMenu!();
  }

  late final Widget game;
  String? panel;
  TimePath? offeredPath;
  final gameFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    stopBackAction = widget.backActions?.register(() {
      if (adventure.defeated) {
        returnToMenu();
      } else if (adventure.won) {
        adventure.continueExploring();
        close();
      } else if (panel != null) {
        close();
      } else if (!adventure.defeated && !adventure.won) {
        open('pause');
      }
    });
    WidgetsBinding.instance.addObserver(this);
    saveTimer = async.Timer.periodic(
      const Duration(seconds: 5),
      (_) => saveNow(),
    );
    stopSaveListener = storage.listenForExit(saveNow);
    game = BonfireWidget(
      map: WorldMap.empty(size: Vector2(worldSize.width, worldSize.height)),
      player: adventure.hero,
      playerControllers: [
        Keyboard(
          config: KeyboardConfig(
            directionalKeys: [
              KeyboardDirectionalKeys.wasd(),
              KeyboardDirectionalKeys.arrows(),
            ],
          ),
        ),
      ],
      components: [
        LandscapeLayer(adventure),
        WorldDirector(adventure),
        WellDiscoveryDirector(
          adventure,
          onOpen: openWarp,
          onDiscovered: saveNow,
        ),
        StageLandmarks(adventure),
        for (
          var index = 0;
          index < adventure.stageChestLocations.length;
          index++
        )
          DestructibleChest(adventure, index),
        for (final section in adventure.world.sanctuaryFences)
          SanctuaryFence(section, adventure.world.stage),
        VillagePerson(adventure, true),
        if (adventure.world.stage == WorldStage.sands)
          for (final giver in timeQuestGivers) QuestGiver(adventure, giver)
        else
          VillagePerson(adventure, false),
      ],
      cameraConfig: CameraConfig(
        moveOnlyMapArea: false,
        initPosition: Vector2(
          adventure.world.spawn.dx + 12,
          adventure.world.spawn.dy + 11,
        ),
        startFollowPlayer: false,
        movementWindow: Vector2.zero(),
        zoom: 1,
      ),
      collisionConfig: BonfireCollisionConfig.quadTree(),
      backgroundColor: ink,
      focusNode: gameFocus,
      onReady: (game) {
        game.camera.updateBoundsAndZoomFit(moveOnlyMapArea: true);
        game.camera.position = adventure.cameraFocus;
        adventure.start(game);
        saveNow();
        if (!widget.arrivingByWell &&
            (widget.showStageBriefing ||
                adventure.world.stage == WorldStage.sands &&
                    adventure.timePath == null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) open('journal');
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    adventure.viewportSize = size;
    adventure.cameraOffsetY = size.width < 400 && size.height < 520 ? 36 : 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && adventure.ready && mounted) {
      if (panel == null) {
        open('pause');
      } else {
        adventure.pause();
        saveNow();
      }
    }
  }

  void open(String name) {
    saveNow();
    adventure.pause();
    setState(() {
      panel = name;
      offeredPath = name == 'talk' ? adventure.nearbyTimeGiver?.path : null;
    });
  }

  void close() {
    saveNow();
    setState(() => panel = null);
    adventure.resume();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && panel == null && !adventure.defeated && !adventure.won) {
        gameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    stopSaveListener?.call();
    stopBackAction?.call();
    saveNow(notify: false);
    WidgetsBinding.instance.removeObserver(this);
    adventure.dispose();
    gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: adventure,
      child: game,
      builder: (context, child) {
        final media = MediaQuery.of(context),
            width = media.size.width,
            short = media.size.height < 500;
        final landscapeControls = short && width >= 500;
        final tightLandscape = landscapeControls && width < 600;
        final sideGuide = landscapeControls || width >= 600;
        final stick = short && width < 500
                ? math.min(112.0, math.max(44.0, media.size.height - 318))
                : width < 360
                ? 122.0
                : short
                ? 112.0
                : 142.0,
            attack = width < 360 ? 90.0 : 104.0,
            bottom = short ? 86.0 : 112.0;
        final modal = adventure.defeated
            ? 'defeat'
            : adventure.won
            ? 'victory'
            : panel;
        final p = adventure.progress;
        final guide = adventure.nearbyQuestGuide;
        final contextActions = [
          for (final action in adventure.nearbyActions)
            if (switch (action) {
              NearbyAction.shrine => guide == null,
              NearbyAction.talk => guide?.action != QuestGuideAction.talk,
              NearbyAction.dismount =>
                guide?.action != QuestGuideAction.dismount,
              _ => true,
            })
              nearbyControl(action),
          if (widget.onTravel != null &&
              adventure.riding == null &&
              adventure.travelJournal.nearbyWell(
                    adventure.world,
                    adventure.hero.body.center,
                  ) !=
                  null)
            NearbyControl(
              label: '워프',
              icon: Icons.blur_circular,
              onTap: openWarp,
            ),
        ];
        final compactGuide =
            short && contextActions.isNotEmpty && guide != null;

        final peacefulAttack =
            adventure.sheltered &&
            adventure
                .attackableChests(
                  adventure.hero.body.center,
                  p.heroClass == HeroClass.mage ? 540 : p.weapon.base.range,
                )
                .isEmpty;
        final layouts = short && width < 500
            ? [
                (14.0, 128.0, 52.0),
                (18.0, 188.0, 48.0),
                (94.0, 168.0, 48.0),
                (94.0, 112.0, 48.0),
              ]
            : short
            ? [
                (258.0, 80.0, 48.0),
                (202.0, 80.0, 48.0),
                (258.0, 24.0, 48.0),
                (202.0, 24.0, 48.0),
              ]
            : width < 360
            ? [
                (18.0, 152.0, 56.0),
                (66.0, 204.0, 48.0),
                (96.0, 166.0, 48.0),
                (120.0, 112.0, 48.0),
              ]
            : [
                (18.0, 152.0, 64.0),
                (84.0, 192.0, 56.0),
                (148.0, 166.0, 52.0),
                (160.0, 112.0, 48.0),
              ];
        Widget skillButton(int slot) {
          final skill = p.skillAt(slot)!, layout = layouts[slot];
          final remaining = adventure.hero.cooldowns[skill.id] ?? 0;
          final aimed = const {
            'meteor',
            'seismicSlam',
            'charge',
            'crushingBlow',
          }.contains(skill.id);
          return Positioned(
            right: layout.$1,
            bottom: bottom + layout.$2,
            child: ActionButton(
              art: widget.art,
              sprite: 'roundEmpty',
              effect: skillEffect(skill.id),
              showLabel: false,
              label: skill.shortName,
              semanticLabel: slot == 0
                  ? skill.name
                  : slot == 1
                  ? '보조 ${skill.name}'
                  : '스킬 ${slot + 1} ${skill.name}',
              size: layout.$3,
              insufficientResource: p.energy < skill.cost,
              remaining: remaining,
              total: p.skillCooldown(skill),
              onTap: () => adventure.hero.skill(slot: slot),
              onAimStart: aimed ? () => adventure.hero.beginAim(slot) : null,
              onAimMove: aimed
                  ? (delta) => adventure.hero.moveAim(delta, ownerSlot: slot)
                  : null,
              onAimEnd: aimed
                  ? (cancelled) =>
                        adventure.hero.finishAim(cancelled, ownerSlot: slot)
                  : null,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: modal != null,
              child: ExcludeFocus(
                excluding: modal != null,
                child: IgnorePointer(ignoring: modal != null, child: child!),
              ),
            ),
            SafeArea(
              bottom: false,
              child: ExcludeSemantics(
                excluding: modal != null,
                child: IgnorePointer(
                  ignoring: modal != null,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: GameHud(
                      adventure,
                      onMap: modal == null ? () => open('map') : null,
                    ),
                  ),
                ),
              ),
            ),
            if (!adventure.ready)
              const Center(child: CircularProgressIndicator(color: gold)),
            if (modal == null && adventure.ready) ...[
              Positioned(
                left: 12,
                bottom: bottom,
                child: GameStick(
                  art: widget.art,
                  size: stick,
                  onChange: (angle, intensity) =>
                      adventure.hero.onJoystickChangeDirectional(
                        JoystickDirectionalEvent(
                          directional: intensity == 0
                              ? JoystickMoveDirectional.IDLE
                              : JoystickMoveDirectional.MOVE_RIGHT,
                          radAngle: angle,
                          intensity: intensity,
                        ),
                      ),
                ),
              ),
              Positioned(
                right: width < 360 ? 14 : 22,
                bottom: bottom,
                child: ActionButton(
                  art: widget.art,
                  sprite: 'roundEmpty',
                  artwork: SizedBox.square(
                    dimension: attack * .75,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: peacefulAttack ? .45 : 1,
                          child: CustomPaint(
                            painter: GearGlyph(p.weapon, widget.art),
                          ),
                        ),
                        if (peacefulAttack)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              Icons.shield_rounded,
                              color: gold,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                  label: '공격',
                  semanticLabel: '공격',
                  size: attack,
                  remaining: adventure.hero.attackClock,
                  total: p.attackInterval,
                  onHold: (held) => adventure.holdAttack('touch', held),
                  onTap: adventure.hero.slash,
                ),
              ),
              for (var slot = 0; slot < 4; slot++)
                if (p.skillAt(slot) != null) skillButton(slot),
              Positioned(
                right: width < 360 ? 112 : 134,
                bottom: bottom + 20,
                child: ActionButton(
                  art: widget.art,
                  sprite: 'roundEmpty',
                  artwork: CustomPaint(
                    size: Size.square((width < 360 ? 56 : 64) * .78),
                    painter: AbilityPicturePainter(widget.art, 'dodge-icon'),
                  ),
                  label: '회피',
                  semanticLabel: '회피',
                  size: width < 360 ? 56 : 64,
                  remaining: adventure.hero.dodgeClock,
                  total: 1.5,
                  onTap: adventure.hero.dodge,
                ),
              ),
              if (contextActions.isNotEmpty)
                Positioned(
                  left: short && width >= 500 ? 136 : 12,
                  top: short
                      ? media.padding.top + (guide == null ? 164 : 144)
                      : null,
                  bottom: short ? null : bottom + stick + 12,
                  width: short
                      ? width >= 500
                            ? (width - 450).clamp(100, 320).toDouble()
                            : (width - 174).clamp(44, width - 24).toDouble()
                      : 120,
                  child: NearbyControls(
                    actions: contextActions,
                    horizontal: short,
                  ),
                ),
              Positioned(
                left: short && width >= 500 ? 136 : 14,
                top: tightLandscape
                    ? null
                    : media.padding.top +
                          (guide != null
                              ? (short && width < 500 ? 188 : 198)
                              : 110),
                bottom: tightLandscape
                    ? math.max(8, media.padding.bottom) + 58
                    : null,
                child: PotionBelt(adventure, onUse: restoreGameFocus),
              ),
              if (guide != null)
                Positioned(
                  left: sideGuide ? 136 : 12,
                  top: media.padding.top + 100,
                  width: sideGuide
                      ? (width - 450).clamp(100, 280).toDouble()
                      : (width - (short ? 164 : 150))
                            .clamp(148, 250)
                            .toDouble(),
                  height: compactGuide
                      ? 44
                      : short && width < 600
                      ? 84
                      : 92,
                  child: NearbyQuestCard(
                    guide,
                    compact: compactGuide,
                    onTap: () {
                      switch (guide.action) {
                        case QuestGuideAction.journal:
                          open('journal');
                        case QuestGuideAction.talk:
                          open('talk');
                        case QuestGuideAction.cleanse:
                          if (adventure.cleanseNearbySite()) saveNow();
                        case QuestGuideAction.dismount:
                          if (adventure.dismount()) saveNow();
                      }
                      restoreGameFocus();
                    },
                  ),
                ),
              if (adventure.noticeTime > 0)
                Positioned(
                  left: 55,
                  right: 55,
                  top: media.padding.top + 160,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gold.withValues(alpha: .6)),
                      ),
                      child: Text(
                        adventure.notice,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: math.max(8, media.padding.bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _menu('touchInventory', '가방', 'bag'),
                    _menu('touchQuests', '스킬', 'skills'),
                    _menu('touchCompendium', '여정', 'journal'),
                    _menu('touchSettings', '설정', 'settings'),
                  ],
                ),
              ),
            ],
            if (modal != null)
              Positioned.fill(
                child: AdventurePanel(
                  backActions: widget.backActions,
                  session: adventure,
                  name: modal,
                  offeredPath: offeredPath,
                  onClose: close,
                  onRestart: abandon,
                  onCheckpoint: saveNow,
                  onAdvance: widget.onAdvance == null ? null : advanceStage,
                  onTravel: widget.onTravel == null ? null : travelTo,
                  onRetryCheckpoint:
                      adventure.defeated &&
                          widget.onRetryCheckpoint != null &&
                          GameCheckpoint.decode(storage.readCheckpoint()) !=
                              null
                      ? widget.onRetryCheckpoint
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _menu(String sprite, String label, String target) => MenuButton(
    art: widget.art,
    sprite: sprite,
    label: label,
    badge: target == 'skills'
        ? adventure.progress.skillPoints
        : target == 'journal'
        ? (adventure.world.stage == WorldStage.sands
              ? (4 -
                    adventure.cleansedSites.length +
                    (adventure.progress.bossDefeated ? 0 : 1))
              : (adventure.world.sites.length -
                    adventure.cleansedSites.length +
                    (adventure.progress.bossDefeated ? 0 : 1)))
        : target == 'bag'
        ? adventure.progress.unseenGear.length
        : 0,
    onTap: () => open(target),
  );
}
