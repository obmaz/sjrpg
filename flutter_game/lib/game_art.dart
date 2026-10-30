import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'actor_atlas.dart';
import 'boss_sprite_mesh.dart';
import 'desert_temple_art.dart';
import 'effect_atlas.dart';
import 'enemy_catalog.dart';
import 'field_landscape.dart';
import 'field_palettes.dart';
import 'ground_texture.dart';
import 'interface_art.dart';
import 'mount_sprite_mesh.dart';
import 'prop_grounding.dart';
import 'quest_scenery.dart';
import 'village_scene_blend.dart';
import 'world_model.dart';

class GameArt {
  final images = <String, ui.Image>{};
  late final effects = EffectAtlas(images);
  late final Map<String, dynamic> actors, controls;
  final materials = <ui.Shader>[];

  /// Four full-resolution shared field textures; all stages borrow these.
  final fieldMaterials = <ui.Shader>[];
  static const _fieldImages = [
    'field-ground-meadow',
    'field-ground-desert',
    'field-ground-stone',
    'field-ground-industrial',
  ];
  final _actorAtlases = <String, ActorAtlas>{};
  final _labels = <(String, double, ui.Color), ui.Paragraph>{};
  static const _labelLimit = 128;
  final _bossMesh = BossSpriteMeshPainter();
  final _walkMesh = BossSpriteMeshPainter(imageLimit: 12, uvLimit: 128);
  final _mountMesh = MountSpriteMeshPainter();
  static const characterWidthScale = 1.08, heroHeightScale = 1.0;

  /// Presentation only; collision footprints and weapon reach stay in world units.
  static const characterBodyScale = 1.18;
  static const characterRenderScale = .8;
  late final _actorPaint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  late final _rollPaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  late final _portraitPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium;
  ActorAtlas _atlas(String sheet) {
    final cached = _actorAtlases[sheet];
    if (cached != null) return cached;
    final atlas = ActorAtlas.fromJson(actors[sheet] as Map<String, dynamic>);
    _actorAtlases[sheet] = atlas;
    return atlas;
  }

  // Class portraits replace the large gameplay atlases on the menu. Those
  // atlases still join the stage's transactional preparation before play.
  static const _menuImages = ['entry-scene', 'class-selection', 'entry-ui'];
  static const _pngImages = {
    'actors-mage',
    'actors-motor',
    'actors-horse',
    'actors-boat',
    'gear-icons',
    'combat-fx',
    'dodge-icon',
    'actors-roll',
  };
  static const _allImages = [
    ..._fieldImages,
    'entry-scene',
    'class-selection',
    'entry-ui',
    'actors-hero',
    'hero-helmeted-portrait',
    'actors-mage',
    'gear-icons',
    'combat-fx',
    'passive-icons',
    'skill-perks',
    'physical-icons',
    'combat-illustrations',
    'combat-actions',
    'd1-interface',
    'cinematic-interface',
    'reference-battle-buttons',
    'mount-skill-icons',
    'actors-cinematic-goblin',
    'actors-cinematic-wolf',
    'actors-cinematic-skeleton',
    'actors-cinematic-cultist',
    'actors-cinematic-troll',
    'actors-cinematic-golem',
    'actors-cinematic-scorpion',
    'actors-cinematic-mummy',
    'actors-cinematic-boar',
    'actors-cinematic-basilisk',
    'actors-cinematic-wraith',
    'actors-cinematic-drone',
    'actors-cinematic-viper',
    'actors-cinematic-bonehound',
    'actors-cinematic-clockwork-spider',
    'actors-cinematic-crystal-beetle',
    'actors-cinematic-cyber',
    'actors-cinematic-gunner',
    'actors-cinematic-sand-warden',
    'actors-cinematic-ancient-king',
    'actors-cinematic-cyber-core',
    'reference-menus',
    'village-gateway',
    'd1-warrior',
    'd1-mage',
    'fx-level-up',
    'fx-meteor',
    'fx-ice-nova',
    'fx-steel-whirlwind',
    'victory-crest',
    'well-portal',
    'encounter-beacons',
    'fx-warcry',
    'fx-crushing-blow',
    'dodge-icon',
    'actors-roll',
    'terrain-materials',
    'actors-hero-attack',
    'actors-hero-backhand',
    'actors-hero-cleave',
    'actors-mage-cast',
    'actors-villagers',
    'quest-sites',
    'time-sites',
    'time-paths',
    'stage-materials',
    'actors-bicycle',
    'actors-motor',
    'actors-horse',
    'actors-boat',
    'cyber-props',
    'ruin-props',
    'desert-temple',
    'village-scene',
    'settlement-forest',
    'settlement-sands',
    'settlement-past',
    'settlement-future',
    'settlement-tombs',
    'settlement-foundry',
    'settlement-convergence',

    'blacksmith-forge',
    'village-gardens',
    'village-cottage',
    'quest-root-garden',
    'action-glyphs',
    'barbarian-skills',
    'sorceress-skills',
    'landscape-bridge',
    'world-forest',
    'world-desert',
    'controls',
    'atlas',
  ];
  // Stable saved stage IDs keep later chapters compatible with their art family.
  static const _sceneryImages = <String, Set<String>>{
    'forest': {
      'settlement-forest',
      'village-gateway',
      'world-desert',
      'landscape-bridge',
      'quest-root-garden',
    },
    'sands': {
      'settlement-sands',
      'world-desert',
      'ruin-props',
      'desert-temple',
    },
    'past': {'settlement-past', 'ruin-props'},
    'future': {'settlement-future', 'cyber-props'},
    'tombs': {'settlement-tombs', 'ruin-props'},
    'foundry': {'settlement-foundry', 'cyber-props'},
    'convergence': {'settlement-convergence', 'ruin-props'},
  };
  // Simplified runtime effects no longer draw these large decorative atlases.
  // Keep the original sources available to the full loader and art tooling.
  static const _stagedRetiredVfx = {
    'fx-steel-whirlwind',
    'fx-warcry',
    'barbarian-skills',
    'sorceress-skills',
    'village-scene',
    'village-gardens',
    'village-cottage',
    'blacksmith-forge',
  };

  static const _sharedActors = {
    'actors-hero',
    'actors-mage',
    'actors-roll',
    'actors-villagers',
    'actors-bicycle',
    'actors-motor',
    'actors-horse',
    'actors-boat',
  };
  AssetBundle _bundle = rootBundle;
  final _sourceBytes = <String, ByteData>{};
  bool _sourcesReady = false;
  bool _staged = false;
  Future<void> _preparation = Future<void>.value();

  static Future<GameArt> load() => _load(staged: false);
  static Future<GameArt> loadMenu({AssetBundle? bundle}) =>
      _load(staged: true, bundle: bundle);

  static Future<GameArt> _load({
    required bool staged,
    AssetBundle? bundle,
  }) async {
    final art = GameArt()
      .._staged = staged
      .._bundle = bundle ?? rootBundle;
    try {
      final data =
          jsonDecode(await art._bundle.loadString('assets/art.json'))
              as Map<String, dynamic>;
      art.actors = data['actors'];
      art.controls = data['controls'];
      for (final sheet in art.actors.keys) {
        art._atlas(sheet);
      }
      await Future.wait([
        art._ensureImages(
          staged ? _menuImages : _allImages,
          ground: !staged,
          village: !staged,
        ),
        prepareInterfaceArtwork(),
      ]);
      return art;
    } catch (_) {
      art.dispose();
      rethrow;
    }
  }

  Future<void> ensureStage(
    WorldStage stage, {
    required HeroClass heroClass,
    Iterable<String> enemyKinds = const [],
  }) {
    if (!_staged) return Future<void>.value();
    final kinds = enemyKinds.toList();
    final ready = _preparation.then(
      (_) => _ensureStage(stage, heroClass, kinds),
    );
    // A failed request must leave subsequent retry requests usable.
    _preparation = ready.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return ready;
  }

  Future<void> _ensureStage(
    WorldStage stage,
    HeroClass heroClass,
    Iterable<String> savedKinds,
  ) async {
    await _prefetchSources();
    final scenery = _sceneryImages[stage.name];
    if (scenery == null) {
      await _ensureImages(_allImages, ground: true, village: true);
      return;
    }
    final exclusiveScenery = _sceneryImages.values
        .expand((names) => names)
        .toSet();
    final names = <String>{
      for (final name in _allImages)
        if (!_stagedRetiredVfx.contains(name) &&
            (!const {
                  'barbarian-skills',
                  'd1-warrior',
                  'hero-helmeted-portrait',
                }.contains(name) ||
                heroClass == HeroClass.warrior) &&
            (!const {'sorceress-skills', 'd1-mage'}.contains(name) ||
                heroClass == HeroClass.mage) &&
            (!name.startsWith('actors-') || _sharedActors.contains(name)) &&
            !exclusiveScenery.contains(name))
          name,
      ...scenery,
      if (heroClass == HeroClass.warrior) ...[
        'actors-hero-attack',
        'actors-hero-backhand',
        'actors-hero-cleave',
      ] else
        'actors-mage-cast',
    };
    final actorKeys = <String>{
      stage.bossActor,
      // Chests can release these even when the local encounter pool cannot.
      stage.usesCityArt ? 'drone' : 'viper',
      ...savedKinds,
      for (final path in TimePath.values)
        if (chapterContract(stage, path) case final contract?) contract.actor,
    };
    for (final sand in [false, true]) {
      for (final wooded in [false, true]) {
        for (final ruins in [false, true]) {
          actorKeys.addAll(
            biomeEnemies(stage, sand: sand, wooded: wooded, ruins: ruins),
          );
        }
      }
    }
    if (stage == WorldStage.sands) {
      actorKeys.addAll(timeQuestGivers.map((giver) => giver.actor));
    }
    names.addAll(
      actorKeys.map((key) => 'actors-${_actorDefinitions[key]!.$1}'),
    );
    await _ensureImages(names, ground: true, village: false);
  }

  String _imagePath(String name) =>
      'assets/images/$name.${_pngImages.contains(name) ? 'png' : 'webp'}';

  Future<void> _prefetchSources() async {
    if (_sourcesReady) return;
    final incoming = <String, ByteData>{};
    // A published release can disappear while its page remains open. Keep
    // deferred sources locally before starting play, then drop each compressed
    // source when its decoded image or baked replacement becomes resident.
    await Future.wait([
      for (final name in _allImages)
        if (!_stagedRetiredVfx.contains(name) && !images.containsKey(name))
          _bundle.load(_imagePath(name)).then((bytes) {
            incoming[name] = bytes;
          }),
    ]);
    _sourceBytes.addAll(incoming);
    _sourcesReady = true;
  }

  Future<Map<String, ui.Image>> _decodeMissing(Iterable<String> names) async {
    final decoded = <String, ui.Image>{};
    try {
      await Future.wait(
        names.toSet().where((name) => !images.containsKey(name)).map((
          name,
        ) async {
          final cached = _sourceBytes[name];
          if (_staged && _sourcesReady && cached == null) {
            throw StateError('A stage requested an unprepared image: $name');
          }
          final data = cached ?? await _bundle.load(_imagePath(name));
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          try {
            decoded[name] = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        }),
      );
      return decoded;
    } catch (_) {
      for (final image in decoded.values) {
        image.dispose();
      }
      rethrow;
    }
  }

  Future<void> _ensureImages(
    Iterable<String> names, {
    bool ground = false,
    bool village = false,
  }) async {
    final buildGround = ground && materials.isEmpty;
    final buildField = ground && fieldMaterials.isEmpty;
    final buildVillage = village && !images.containsKey('village-blended');
    final requested = names
        .where(
          (name) => name != 'terrain-materials' && name != 'stage-materials',
        )
        .toSet();
    if (buildGround) requested.addAll(['terrain-materials', 'stage-materials']);
    if (buildField) requested.addAll(_fieldImages);
    final decoded = await _decodeMissing(requested);
    final consumedSources = decoded.keys.toList();
    final baked = <String, ui.Image>{};
    final shaders = <ui.Shader>[];
    final fieldShaders = <ui.Shader>[];
    try {
      for (final name in decoded.keys.toList()) {
        final source = decoded[name]!;
        if (name.startsWith('settlement-')) {
          decoded[name] = await _featherSettlement(source);
        } else if (buildField && _fieldImages.contains(name)) {
          decoded[name] = await _bakeFieldTexture(source);
        } else {
          continue;
        }
        source.dispose();
      }
      final sourceImages = {...images, ...decoded};
      if (buildGround) {
        await _bakeGround(sourceImages, shaders, baked);
        for (final name in ['terrain-materials', 'stage-materials']) {
          sourceImages.remove(name);
          decoded.remove(name)!.dispose();
        }
      }
      if (buildField) _buildFieldMaterials(sourceImages, fieldShaders);
      if (buildVillage) await _bakeVillage(sourceImages, baked);
    } catch (_) {
      for (final shader in [...shaders, ...fieldShaders]) {
        shader.dispose();
      }
      for (final image in [...decoded.values, ...baked.values]) {
        image.dispose();
      }
      rethrow;
    }
    images.addAll(decoded);
    images.addAll(baked);
    materials.addAll(shaders);
    fieldMaterials.addAll(fieldShaders);
    for (final name in consumedSources) {
      _sourceBytes.remove(name);
    }
    _bossMesh.trim(images.values);
    _walkMesh.trim(images.values);
    _mountMesh.trim(images.values);
    effects.warm();
  }

  void _buildFieldMaterials(
    Map<String, ui.Image> sourceImages,
    List<ui.Shader> shaders,
  ) {
    for (final name in _fieldImages) {
      final image = sourceImages[name]!;
      if (image.width != 768 || image.height != 768) {
        throw FormatException('$name must retain its 768px field detail');
      }
      shaders.add(
        ui.ImageShader(
          image,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        ),
      );
    }
  }

  Future<ui.Image> _bakeFieldTexture(ui.Image source) async {
    if (source.width != 768 || source.height != 768) {
      throw const FormatException('Field sources must retain 768px detail');
    }
    final recorder = ui.PictureRecorder();
    paintSeamlessGround(
      ui.Canvas(recorder),
      source,
      const ui.Rect.fromLTWH(0, 0, 768, 768),
      768,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(768, 768);
    } finally {
      picture.dispose();
    }
  }

  Future<void> _bakeGround(
    Map<String, ui.Image> sourceImages,
    List<ui.Shader> shaders,
    Map<String, ui.Image> baked,
  ) async {
    final atlas = sourceImages['terrain-materials']!;
    for (var i = 0; i < 12; i++) {
      final source = i < 6 ? atlas : sourceImages['stage-materials']!;
      final cell = i % 6;
      const tileSize = 192;
      final recorder = ui.PictureRecorder();
      // A separate recorder per material keeps shaders small and shared by every sector.
      final c = ui.Canvas(recorder);
      final crop = ui.Rect.fromLTWH(
        (cell % 3) * source.width / 3 + 12,
        (cell ~/ 3) * source.height / 2 + 12,
        source.width / 3 - 24,
        source.height / 2 - 24,
      );
      if (i < 6) {
        paintSeamlessGround(c, source, crop, tileSize.toDouble());
      } else {
        c.drawImageRect(
          source,
          crop,
          ui.Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
          ui.Paint(),
        );
      }
      final picture = recorder.endRecording();
      late final ui.Image image;
      try {
        image = await picture.toImage(tileSize, tileSize);
      } finally {
        picture.dispose();
      }
      // CanvasKit can rebuild a shader for another paint quality. Retain the
      // small image, owning it early enough to release it if construction fails.
      baked['ground-$i'] = image;
      shaders.add(
        ui.ImageShader(
          image,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        ),
      );
    }
  }

  Future<ui.Image> _featherSettlement(ui.Image source) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Rect.fromLTWH(
      0,
      0,
      source.width.toDouble(),
      source.height.toDouble(),
    );
    canvas.saveLayer(bounds, ui.Paint());
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());
    final edge = source.width * .035;
    for (final side in [
      (
        ui.Offset.zero,
        ui.Offset(edge, 0),
        ui.Rect.fromLTWH(0, 0, edge, bounds.height),
      ),
      (
        ui.Offset(bounds.width, 0),
        ui.Offset(bounds.width - edge, 0),
        ui.Rect.fromLTWH(bounds.width - edge, 0, edge, bounds.height),
      ),
      (
        ui.Offset.zero,
        ui.Offset(0, edge),
        ui.Rect.fromLTWH(0, 0, bounds.width, edge),
      ),
      (
        ui.Offset(0, bounds.height),
        ui.Offset(0, bounds.height - edge),
        ui.Rect.fromLTWH(0, bounds.height - edge, bounds.width, edge),
      ),
    ]) {
      final shader = ui.Gradient.linear(side.$1, side.$2, [
        const ui.Color(0x00ffffff),
        const ui.Color(0xffffffff),
      ]);
      canvas.drawRect(
        side.$3,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = shader,
      );
      shader.dispose();
    }
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
    }
  }

  Future<void> _bakeVillage(
    Map<String, ui.Image> sourceImages,
    Map<String, ui.Image> baked,
  ) async {
    final village = sourceImages['village-scene']!,
        rec = ui.PictureRecorder(),
        canvas = ui.Canvas(rec);
    paintVillageSceneBlend(
      canvas,
      village,
      const ui.Rect.fromLTWH(0, 0, 640, 960),
    );
    final picture = rec.endRecording();
    try {
      baked['village-blended'] = await picture.toImage(640, 960);
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    for (final paragraph in _labels.values) {
      paragraph.dispose();
    }
    _labels.clear();
    _bossMesh.dispose();
    _walkMesh.dispose();
    _mountMesh.dispose();
    for (final shader in [...materials, ...fieldMaterials]) {
      shader.dispose();
    }
    for (final image in images.values) {
      image.dispose();
    }
    materials.clear();
    fieldMaterials.clear();
    images.clear();
    _sourceBytes.clear();
  }

  static const _actorDefinitions = {
    'hero': ('hero', 0, 16),
    'mage': ('mage', 0, 16),
    'goblin': ('cinematic-goblin', 0, 8),
    'boar': ('cinematic-boar', 0, 8),
    'basilisk': ('cinematic-basilisk', 0, 8),
    'wraith': ('cinematic-wraith', 0, 8),
    'drone': ('cinematic-drone', 0, 8),
    'viper': ('cinematic-viper', 0, 8),
    'bonehound': ('cinematic-bonehound', 0, 8),
    'clockwork-spider': ('cinematic-clockwork-spider', 0, 8),
    'crystal-beetle': ('cinematic-crystal-beetle', 0, 8),
    'wolf': ('cinematic-wolf', 0, 8),
    'skeleton': ('cinematic-skeleton', 0, 8),
    'cultist': ('cinematic-cultist', 0, 8),
    'golem': ('cinematic-golem', 0, 8),
    'scorpion': ('cinematic-scorpion', 0, 8),
    'mummy': ('cinematic-mummy', 0, 8),
    'troll': ('cinematic-troll', 0, 8),
    'cyber': ('cinematic-cyber', 0, 8),
    'gunner': ('cinematic-gunner', 0, 8),
    'sand-warden': ('cinematic-sand-warden', 0, 8),
    'ancient-king': ('cinematic-ancient-king', 0, 8),
    'cyber-core': ('cinematic-cyber-core', 0, 8),
    'merchant': ('villagers', 0, 8),
    'villager': ('villagers', 1, 8),
    'horse': ('horse', 0, 8),
    'bicycle': ('bicycle', 0, 8),
    'motor': ('motor', 0, 8),
    'boat': ('boat', 0, 8),
  };

  void landmark(
    ui.Canvas canvas,
    int index,
    ui.Offset feet,
    double side, {
    bool themed = false,
    double opacity = 1,
  }) {
    final image = images[themed ? 'time-sites' : 'quest-sites'];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        themed ? index % 4 * image.width / 4 : index * image.width / 3,
        themed ? index ~/ 4 * image.height / 2 : 0,
        image.width / (themed ? 4 : 3),
        image.height / (themed ? 2 : 1),
      ),
      ui.Rect.fromLTWH(feet.dx - side / 2, feet.dy - side * .9375, side, side),
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = ui.FilterQuality.medium,
    );
  }

  void cityProp(
    ui.Canvas canvas,
    int index,
    ui.Offset feet,
    double side, {
    double opacity = 1,
  }) {
    final image = images['cyber-props'];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        index % 4 * image.width / 4,
        index ~/ 4 * image.height / 2,
        image.width / 4,
        image.height / 2,
      ),
      ui.Rect.fromLTWH(feet.dx - side / 2, feet.dy - side * .9375, side, side),
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = ui.FilterQuality.medium,
    );
  }

  /// The HUD may clip this identity portrait to its existing circular frame.
  void helmetedWarriorPortrait(ui.Canvas canvas, ui.Rect destination) {
    final image = images['hero-helmeted-portrait'];
    if (image == null) return;
    final fit = math.max(
      destination.width / image.width,
      destination.height / image.height,
    );
    final source = ui.Rect.fromCenter(
      center: ui.Offset(image.width / 2, image.height / 2),
      width: destination.width / fit,
      height: destination.height / fit,
    );
    canvas.drawImageRect(image, source, destination, _portraitPaint);
  }

  /// Existing and unloaded atlases retain the original two-phase gait.
  int runFrameCount(String key) {
    final sheet = _actorDefinitions[key]!.$1;
    if (!images.containsKey('actors-$sheet')) return 2;
    return _atlas(sheet).motion?.framesPerDirection ?? 2;
  }

  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    bool moving = false,
    int comboPose = 0,
    double? actionProgress,
    BossVisualPose? bossPose,
    BossVisualPose? walkPose,
    MountVisualPose? mountPose,
    double opacity = 1,
    double flash = 0,
  }) {
    final definition = _actorDefinitions[key]!;
    final sheet = attack && key == 'hero'
            ? const ['hero-attack', 'hero-backhand', 'hero-cleave'][comboPose
                  .clamp(0, 2)]
            : attack && key == 'mage'
            ? 'mage-cast'
            : definition.$1,
        count = definition.$3;
    final atlas = _atlas(sheet);
    final motion = !attack && (key == 'hero' || key == 'mage')
        ? atlas.motion
        : null;
    final action = attack ? atlas.action : null;
    final selectedPhase = bossPose == null && walkPose == null ? phase : 0;
    final index = action != null
        ? action.frameIndex(
            facingFrame(angle, 16),
            actionProgress ?? (phase.isEven ? 0.0 : .5),
          )
        : motion != null
        ? motion.frameIndex(
            facingFrame(angle, ActorRunClip.directions),
            phase,
            moving: moving,
          )
        : sheet.startsWith('cinematic-') ||
              const {
                'cyber',
                'gunner',
                'sand-warden',
                'ancient-king',
                'cyber-core',
                'bicycle',
                'motor',
                'horse',
                'boat',
                'boar',
                'basilisk',
                'wraith',
                'drone',
                'viper',
                'bonehound',
                'clockwork-spider',
                'crystal-beetle',
              }.contains(key)
        ? facingFrame(angle, 8) * 2 + selectedPhase % 2
        : count == 16
        ? facingFrame(angle, count) + (selectedPhase % 2) * 16
        : definition.$2 * 8 +
              facingFrame(angle, count) +
              (selectedPhase % 2) * 32;
    final frame = atlas.frames[index];
    final scale = height / atlas.heights[definition.$2], src = frame.source;
    final hero = key == 'hero' || key == 'mage';
    final characterScale = hero
        ? characterRenderScale * characterBodyScale
        : 1.0;
    final scaleX = scale * (hero ? characterWidthScale : 1) * characterScale;
    final scaleY = scale * (hero ? heroHeightScale : 1) * characterScale;
    final dst = ui.Rect.fromLTWH(
      feet.dx - frame.anchor.dx * scaleX,
      feet.dy - frame.anchor.dy * scaleY,
      src.width * scaleX,
      src.height * scaleY,
    );
    final mirror = frame.mirrored;
    if (mirror) {
      canvas.save();
      canvas.translate(feet.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-feet.dx, 0);
    }
    _actorPaint
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
      ..colorFilter = flash > 0
          ? ui.ColorFilter.mode(
              ui.Color.fromRGBO(255, 249, 220, flash.clamp(0, 1)),
              ui.BlendMode.srcATop,
            )
          : null;
    if (mountPose != null) {
      _mountMesh.paint(
        canvas,
        images['actors-$sheet']!,
        src,
        dst,
        _actorPaint,
        mountPose,
        groundOrigin: feet,
      );
    } else if (walkPose != null) {
      _walkMesh.paint(
        canvas,
        images['actors-$sheet']!,
        src,
        dst,
        _actorPaint,
        walkPose,
        groundOrigin: feet,
      );
    } else if (bossPose == null) {
      canvas.drawImageRect(images['actors-$sheet']!, src, dst, _actorPaint);
    } else {
      _bossMesh.paint(
        canvas,
        images['actors-$sheet']!,
        src,
        dst,
        _actorPaint,
        bossPose,
        groundOrigin: feet,
      );
    }
    if (mirror) canvas.restore();
  }

  void roll(
    ui.Canvas canvas,
    ui.Offset feet,
    double angle,
    int phase, {
    required bool mage,
  }) {
    final atlas = _atlas('roll');
    final index =
        (mage ? 32 : 0) + (phase.clamp(0, 3) * 8) + facingFrame(angle, 8);
    final frame = atlas.frames[index], src = frame.source;
    final anchor = atlas.projectedOrigin
        ? frame.anchor
        : ui.Offset(src.width / 2, src.height);
    final scale =
        43 /
        atlas.heights[mage ? 1 : 0] *
        characterRenderScale *
        characterBodyScale;
    canvas.drawImageRect(
      images['actors-roll']!,
      src,
      ui.Rect.fromLTWH(
        feet.dx - anchor.dx * scale * characterWidthScale,
        feet.dy - anchor.dy * scale * heroHeightScale,
        src.width * scale * characterWidthScale,
        src.height * scale * heroHeightScale,
      ),
      _rollPaint,
    );
  }

  void prop(ui.Canvas canvas, WorldProp prop, {double opacity = 1}) {
    if (prop.kind == 'blacksmith-forge' || prop.kind == 'village-cottage') {
      final image = images[prop.kind];
      if (image == null) return;
      final feet = prop.body.bottomCenter;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(
          feet.dx - prop.drawSize.width / 2,
          feet.dy - prop.drawSize.height,
          prop.drawSize.width,
          prop.drawSize.height,
        ),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
          ..filterQuality = ui.FilterQuality.medium,
      );
      return;
    }
    if (DesertTempleArt.supports(prop.kind)) {
      DesertTempleArt.draw(
        canvas,
        images[DesertTempleArt.imageKey],
        prop,
        opacity: opacity,
      );
      return;
    }
    if (prop.kind.startsWith('ruin-')) {
      final image = images['ruin-props'];
      if (image == null) return;
      final index = int.parse(prop.kind.substring(5)),
          side = prop.drawSize.height;
      final feet = prop.body.bottomCenter;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          index % 4 * image.width / 4,
          index ~/ 4 * image.height / 2,
          image.width / 4,
          image.height / 2,
        ),
        ui.Rect.fromLTWH(
          feet.dx - side / 2,
          feet.dy - side * .9375,
          side,
          side,
        ),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
          ..filterQuality = ui.FilterQuality.medium,
      );
      return;
    }
    if (prop.kind.startsWith('city-')) {
      cityProp(
        canvas,
        int.parse(prop.kind.substring(5)),
        prop.body.bottomCenter,
        prop.drawSize.height,
        opacity: opacity,
      );
      return;
    }
    if (prop.kind == 'ruin' || prop.kind == 'relay') {
      landmark(
        canvas,
        prop.kind == 'relay' ? 5 : 1,
        prop.body.bottomCenter,
        prop.drawSize.height,
        themed: true,
        opacity: opacity,
      );
      return;
    }

    final image =
            images[prop.kind == 'cactus' ? 'world-desert' : 'world-forest']!,
        cell = image.width / 4;
    final index = prop.kind == 'tree'
        ? 8
        : prop.kind == 'cactus'
        ? 1
        : 10;
    final feet = prop.body.bottomCenter;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
      ui.Rect.fromLTWH(
        feet.dx - prop.drawSize.width / 2,
        feet.dy - prop.drawSize.height * .88,
        prop.drawSize.width,
        prop.drawSize.height,
      ),
      ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  bool face(ui.Canvas canvas, HeroClass heroClass, ui.Rect destination) {
    final image = images['class-selection'];
    if (image == null) return false;
    final ratio = image.width / 1536;
    final source = heroClass == HeroClass.warrior
        ? const ui.Rect.fromLTWH(285, 20, 330, 380)
        : const ui.Rect.fromLTWH(945, 30, 330, 380);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTRB(
        source.left * ratio,
        source.top * ratio,
        source.right * ratio,
        source.bottom * ratio,
      ),
      destination,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    return true;
  }

  void control(ui.Canvas canvas, String key, ui.Rect destination) {
    final v = controls[key] as List;
    canvas.drawImageRect(
      images['controls']!,
      ui.Rect.fromLTWH(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      ),
      destination,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  void text(
    ui.Canvas canvas,
    String value,
    ui.Offset at, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    final key = (value, size, color);
    final paragraph =
        _labels.remove(key) ?? layoutText(value, size: size, color: color);
    _labels[key] = paragraph;
    if (_labels.length > _labelLimit) {
      _labels.remove(_labels.keys.first)!.dispose();
    }
    canvas.drawParagraph(paragraph, at - const ui.Offset(80, 0));
  }

  ui.Paragraph layoutText(
    String value, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: 'Guardian',
              fontSize: size,
              textAlign: ui.TextAlign.center,
            ),
          )
          ..pushStyle(
            ui.TextStyle(color: color, fontWeight: ui.FontWeight.bold),
          )
          ..addText(value);
    return builder.build()..layout(const ui.ParagraphConstraints(width: 160));
  }
}

class TerrainArt {
  TerrainArt(this.world, this.art);
  final AdventureWorld world;
  final GameArt art;
  final cache = <String, ui.Picture>{};
  late final questScenery = QuestScenery(world);
  late final fieldLandscape = FieldLandscape(world);
  late final propGrounding = PropGrounding(world.propBuckets);
  late final ui.Path waterPath = ui.Path.combine(
    ui.PathOperation.difference,
    [...world.lakes, world.river]
        .map((region) => region.path)
        .reduce((a, b) => ui.Path.combine(ui.PathOperation.union, a, b)),
    ui.Path()..addRect(world.settlement),
  );
  late final ui.Path dryGroundPath = ui.Path.combine(
    ui.PathOperation.difference,
    ui.Path()..addRect(ui.Offset.zero & worldSize),
    waterPath,
  );
  ui.Picture sector(int col, int row) {
    final key = '$col:$row';
    final cached = cache.remove(key);
    if (cached != null) {
      cache[key] = cached;
      return cached;
    }
    final recorder = ui.PictureRecorder(),
        c = ui.Canvas(recorder),
        // Record a complete opaque surface beyond the logical cell. Skwasm
        // can round adjacent Picture clips apart at fractional camera offsets.
        // Replaying the full ground stack in this guard band replaces the
        // previous surface, so translucent tints are not accumulated twice.
        area = ui.Rect.fromLTWH(
          col * 512.0,
          row * 512.0,
          512,
          512,
        ).inflate(2);
    c.clipRect(area, doAntiAlias: false);
    final base = world.stage.baseMaterial;
    final road = world.stage.roadMaterial;
    c.drawRect(
      area,
      ui.Paint()
        ..isAntiAlias = false
        ..shader = art.materials[base],
    );
    if (world.stage.groundTint.a > 0) {
      c.drawRect(
        area,
        ui.Paint()
          ..isAntiAlias = false
          ..color = world.stage.groundTint,
      );
    }
    for (final wood in world.woods) {
      if (!wood.bounds.overlaps(area.inflate(80))) continue;
      c.drawPath(wood.path, ui.Paint()..shader = art.materials[1]);
      c.drawPath(
        wood.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 50
          ..color = const ui.Color(0x22335336),
      );
    }
    for (final clearing in world.clearings) {
      if (clearing.bounds.overlaps(area)) {
        c.drawPath(clearing.path, ui.Paint()..shader = art.materials[base]);
      }
    }
    for (final sand in world.sandFields) {
      if (sand.bounds.overlaps(area)) {
        c.drawPath(
          sand.path,
          ui.Paint()
            ..shader =
                art.materials[world.stage == WorldStage.tombs
                    ? 3
                    : world.stage == WorldStage.sands
                    ? 6
                    : 2],
        );
      }
    }
    fieldLandscape.paintGround(
      c,
      area,
      macroColors: fieldPalettes[world.stage.name],
      details: art.fieldMaterials,
    );
    final nearWater = [
      ...world.lakes,
      world.river,
    ].any((region) => region.bounds.overlaps(area.inflate(40)));
    if (nearWater) {
      c.drawPath(
        waterPath,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 42
          ..shader = art.materials[3],
      );
      c.drawPath(waterPath, ui.Paint()..shader = art.materials[4]);
      c.drawPath(
        waterPath,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const ui.Color(0x999ce0c4),
      );
    }
    c.save();
    c.clipPath(dryGroundPath, doAntiAlias: false);
    questScenery.paintGround(c, area, stoneTexture: art.materials[5]);
    c.restore();
    c.save();
    if (nearWater) c.clipPath(dryGroundPath, doAntiAlias: false);
    c.save();
    fieldLandscape.clipHardTrailGround(c);
    for (final t in world.trails) {
      if (!t.bounds.inflate(t.width / 2 + 2).overlaps(area)) continue;
      c.drawPath(
        t.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = t.width + 26
          ..color = const ui.Color(0x55917d50),
      );
    }
    for (final t in world.trails) {
      if (!t.bounds.inflate(t.width / 2 + 2).overlaps(area)) continue;
      c.drawPath(
        t.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = t.width
          ..shader = art.materials[road],
      );
    }
    c.restore();
    fieldLandscape.paintSandTrails(
      c,
      area,
      art.fieldMaterials.length == 4
          ? art.fieldMaterials[FieldGround.desert.index]
          : art.materials[base],
    );
    c.restore();
    // One complete root-garden scene blends into its real approaches. Other
    // objectives have independent ground compositions beneath the roads.
    final rootGarden = art.images['quest-root-garden'];
    if (rootGarden != null &&
        questScenery.patches.any(
          (patch) => patch.usesDedicatedImage && patch.bounds.overlaps(area),
        )) {
      c.save();
      c.clipPath(dryGroundPath, doAntiAlias: false);
      questScenery.paintDedicated(c, rootGarden, area);
      c.restore();
    }
    for (final bridge in world.bridges) {
      if (!bridge.overlaps(area)) continue;
      c.drawImageRect(
        art.images['landscape-bridge']!,
        const ui.Rect.fromLTWH(50, 112, 1880, 540),
        bridge,
        ui.Paint(),
      );
    }
    final settlement = art.images[world.authoredSettlement.imageKey];
    if (settlement != null && world.settlement.overlaps(area)) {
      c.drawImageRect(
        settlement,
        ui.Rect.fromLTWH(
          0,
          0,
          settlement.width.toDouble(),
          settlement.height.toDouble(),
        ),
        world.settlement,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    }
    // Ground-plane shading stays below every depth-sorted actor and prop.
    // Bake only this sector's indexed supports; do not shade lake surfaces.
    c.save();
    c.clipPath(dryGroundPath, doAntiAlias: false);
    propGrounding.paintSector(c, col, row);
    c.restore();
    // Deterministic dappled light is presentation-only and never consumes gameplay RNG.
    // Regenerate neighboring lights in the same world coordinates, so sector
    // clipping cannot cut a warm patch off at a 512px cache boundary.
    for (var lightRow = row - 1; lightRow <= row + 1; lightRow++) {
      for (var lightCol = col - 1; lightCol <= col + 1; lightCol++) {
        final random = math.Random(
          lightCol * 739 + lightRow * 838 + world.seed,
        );
        for (var i = 0; i < 5; i++) {
          final p = ui.Offset(
            lightCol * 512 + random.nextDouble() * 512,
            lightRow * 512 + random.nextDouble() * 512,
          );
          if (!ui.Rect.fromCircle(center: p, radius: 100).overlaps(area)) {
            continue;
          }
          c.drawCircle(
            p,
            100,
            ui.Paint()
              ..shader = ui.Gradient.radial(p, 100, [
                const ui.Color(0x0ff1d393),
                const ui.Color(0x00f1d393),
              ]),
          );
        }
      }
    }
    final picture = recorder.endRecording();
    cache[key] = picture;
    if (cache.length > 24) {
      final old = cache.keys.first;
      cache.remove(old)?.dispose();
    }
    return picture;
  }

  void render(ui.Canvas canvas, ui.Rect view) {
    final transform = canvas.getTransform();
    final pixelRatio =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    final scaleX = transform[0], scaleY = transform[5];
    final translateX = transform[12], translateY = transform[13];
    final alignClips =
        transform[1].abs() < 1e-6 &&
        transform[4].abs() < 1e-6 &&
        scaleX.isFinite &&
        scaleY.isFinite &&
        scaleX > 0 &&
        scaleY > 0 &&
        pixelRatio.isFinite &&
        pixelRatio > 0;
    double align(double value, double scale, double translation) =>
        (((value * scale + translation) * pixelRatio).roundToDouble() /
                pixelRatio -
            translation) /
        scale;
    for (
      var y = (view.top / 512).floor();
      y <= (view.bottom / 512).floor();
      y++
    ) {
      for (
        var x = (view.left / 512).floor();
        x <= (view.right / 512).floor();
        x++
      ) {
        final cell = ui.Rect.fromLTWH(x * 512.0, y * 512.0, 512, 512);
        final clip = alignClips
            ? ui.Rect.fromLTRB(
                align(cell.left, scaleX, translateX),
                align(cell.top, scaleY, translateY),
                align(cell.right, scaleX, translateX),
                align(cell.bottom, scaleY, translateY),
              )
            : cell;
        // Only replay each cell's interior. Its recorded guard band keeps
        // path/vertex clip artifacts outside this shared, pixel-aligned edge.
        // Adjacent cells use the exact same edge without moving world art.
        canvas.save();
        canvas.clipRect(clip, doAntiAlias: false);
        canvas.drawPicture(sector(x, y));
        canvas.restore();
      }
    }
  }

  void dispose() {
    for (final picture in cache.values) {
      picture.dispose();
    }
    cache.clear();
  }
}
