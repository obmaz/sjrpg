import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

const _families = ['meadow', 'desert', 'stone', 'industrial'];
const _colors = [
  ui.Color(0xff32682e),
  ui.Color(0xffb58e47),
  ui.Color(0xff6b747d),
  ui.Color(0xff455563),
];

Future<ByteData> _texture(ui.Color color, {int side = 768}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(color, ui.BlendMode.src);
  canvas.drawRect(
    const ui.Rect.fromLTWH(257, 123, 1, 1),
    ui.Paint()..color = const ui.Color(0xffff254a),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!;
  } finally {
    image.dispose();
  }
}

class _FieldBundle extends CachingAssetBundle {
  _FieldBundle(this.textures);
  final Map<String, ByteData> textures;
  final reads = <String, int>{};
  String? failure;
  bool offline = false;
  @override
  Future<ByteData> load(String key) async {
    reads.update(key, (count) => count + 1, ifAbsent: () => 1);
    if (offline || key == failure) throw StateError('Source unavailable');
    return textures[key] ?? await rootBundle.load(key);
  }
}

Future<void> _expectFullResolution(ui.Shader shader, ui.Color base) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1536, 256),
    ui.Paint()..shader = shader,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1536, 256);
  picture.dispose();
  try {
    final rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    List<int> at(int x, int y) =>
        rgba.sublist((y * 1536 + x) * 4, (y * 1536 + x) * 4 + 4);
    final needle = at(257, 123);
    expect(
      needle[0],
      greaterThan((base.r * 255).round() + 5),
      reason: 'a weighted single texel survives the full-resolution seam bake',
    );
    expect(
      at(1025, 123),
      at(257, 123),
      reason: 'the shared texture repeats every 768 world pixels',
    );
    final expectedBase = [
      (base.r * 255).round(),
      (base.g * 255).round(),
      (base.b * 255).round(),
      255,
    ];
    for (final x in [258, 449]) {
      final actual = at(x, 123);
      for (var channel = 0; channel < 4; channel++) {
        expect(
          actual[channel],
          closeTo(expectedBase[channel], 2),
          reason: 'one-texel detail stays sharp, with no 192px repetition',
        );
      }
    }
  } finally {
    image.dispose();
  }
}

double _edgeEnergy(Uint8List pixels, int side) {
  var difference = 0;
  for (var i = 0; i < side; i++) {
    for (var channel = 0; channel < 3; channel++) {
      difference +=
          (pixels[(i * side) * 4 + channel] -
                  pixels[(i * side + side - 1) * 4 + channel])
              .abs();
      difference +=
          (pixels[i * 4 + channel] -
                  pixels[((side - 1) * side + i) * 4 + channel])
              .abs();
    }
  }
  return difference / (side * 6);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, ByteData> textures;
  setUpAll(() async {
    textures = {
      for (var i = 0; i < _families.length; i++)
        'assets/images/field-ground-${_families[i]}.webp': await _texture(
          _colors[i],
        ),
    };
  });

  test(
    'full 768px field detail is shared across all seven stage visits and disposed',
    () async {
      final bundle = _FieldBundle(textures);
      final art = await GameArt.loadMenu(bundle: bundle);
      addTearDown(art.dispose);
      expect(art.fieldMaterials, isEmpty);
      expect(
        bundle.reads.keys.any((key) => key.contains('field-ground-')),
        isFalse,
      );
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        previous?.call(image);
        created.add(image);
      };
      try {
        await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      } finally {
        ui.Image.onCreate = previous;
      }
      final consumed = created.where(
        (image) => !art.images.containsValue(image),
      );
      expect(consumed, isNotEmpty);
      expect(
        consumed.every((image) => image.debugDisposed),
        isTrue,
        reason:
            'only baked surfaces remain; raw field sources must be released',
      );
      final shaders = List<ui.Shader>.of(art.fieldMaterials);
      final images = [
        for (final family in _families) art.images['field-ground-$family']!,
      ];
      expect(shaders.length, 4);
      expect(
        images.fold(
          0,
          (bytes, image) => bytes + image.width * image.height * 4,
        ),
        9 * 1024 * 1024,
      );
      for (var i = 0; i < shaders.length; i++) {
        await _expectFullResolution(shaders[i], _colors[i]);
      }
      bundle.offline = true;
      for (final stage in WorldStage.values) {
        await art.ensureStage(stage, heroClass: HeroClass.warrior);
        expect(art.fieldMaterials, orderedEquals(shaders));
        expect([
          for (final family in _families) art.images['field-ground-$family'],
        ], orderedEquals(images));
      }
      for (final key in textures.keys) {
        expect(bundle.reads[key], 1);
      }
      art.dispose();
      expect(shaders.every((shader) => shader.debugDisposed), isTrue);
      expect(images.every((image) => image.debugDisposed), isTrue);
      expect(art.fieldMaterials, isEmpty);
      expect(art.images, isEmpty);
    },
  );

  test(
    'failed field prefetch preserves the menu and a public retry succeeds',
    () async {
      final bundle = _FieldBundle(textures)
        ..failure = 'assets/images/field-ground-stone.webp';
      final art = await GameArt.loadMenu(bundle: bundle);
      addTearDown(art.dispose);
      final before = Map<String, ui.Image>.of(art.images);
      await expectLater(
        art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior),
        throwsStateError,
      );
      expect(art.images, before);
      expect(art.materials, isEmpty);
      expect(art.fieldMaterials, isEmpty);
      expect(before.values.every((image) => !image.debugDisposed), isTrue);
      bundle.failure = null;
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.fieldMaterials.length, 4);
      await _expectFullResolution(art.fieldMaterials[2], _colors[2]);
    },
  );

  test(
    'invalid fourth source rolls back decoded and already-baked images',
    () async {
      final invalid = Map<String, ByteData>.of(textures)
        ..['assets/images/field-ground-industrial.webp'] = await _texture(
          _colors[3],
          side: 192,
        );
      final art = await GameArt.loadMenu(bundle: _FieldBundle(invalid));
      addTearDown(art.dispose);
      final before = Map<String, ui.Image>.of(art.images);
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        previous?.call(image);
        created.add(image);
      };
      try {
        await expectLater(
          art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior),
          throwsFormatException,
        );
      } finally {
        ui.Image.onCreate = previous;
      }
      expect(created, isNotEmpty);
      expect(
        created.every((image) => image.debugDisposed),
        isTrue,
        reason:
            'failed late validation must release decoded and baked surfaces',
      );
      expect(art.images, before);
      expect(art.materials, isEmpty);
      expect(art.fieldMaterials, isEmpty);
      expect(before.values.every((image) => !image.debugDisposed), isTrue);
    },
  );

  test(
    'prepared generated field assets enter the real stage loader at 768px',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.fieldMaterials.length, 4);
      for (final family in _families) {
        final image = art.images['field-ground-$family']!;
        expect(image.width, 768);
        expect(image.height, 768);
        final encoded = await rootBundle.load(
          'assets/images/field-ground-$family.webp',
        );
        final codec = await ui.instantiateImageCodec(
          encoded.buffer.asUint8List(),
        );
        late final ui.Image source;
        try {
          source = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        try {
          final before = _edgeEnergy(
            (await source.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List(),
            768,
          );
          final after = _edgeEnergy(
            (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List(),
            768,
          );
          expect(
            after,
            lessThan(before * .85),
            reason: '$family repeating edges lose the generated checker seam',
          );
        } finally {
          source.dispose();
        }
      }
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder);
      for (var i = 0; i < 4; i++) {
        c.drawRect(
          ui.Rect.fromLTWH(i * 128.0, 0, 128, 128),
          ui.Paint()..shader = art.fieldMaterials[i],
        );
      }
      final picture = recorder.endRecording();
      final output = await picture.toImage(512, 128);
      picture.dispose();
      try {
        final rgba = (await output.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var covered = 0;
        for (var i = 3; i < rgba.length; i += 4) {
          if (rgba[i] > 200) covered++;
        }
        expect(covered, greaterThan(512 * 128 * .95));
      } finally {
        output.dispose();
      }
    },
  );
}
