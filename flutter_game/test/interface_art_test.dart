import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/interface_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async {
    art = await GameArt.load();
  });
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });
  testWidgets(
    'generated UI is decoded before play and the tablet paints on its first frame',
    (tester) async {
      final providers = interfaceArtworkProviders.toList();
      expect(providers.length, 4);
      for (final provider in providers) {
        final key = await provider.obtainKey(ImageConfiguration.empty);
        final status = PaintingBinding.instance.imageCache.statusForKey(key);
        expect(status.pending, false);
        expect(status.keepAlive, true);
      }
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Image(image: skillTabletArtwork),
        ),
      );
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'UI survives decoded-cache eviction when its source files become unavailable',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var assetReads = 0;
      messenger.setMockMessageHandler('flutter/assets', (_) async {
        assetReads++;
        return null;
      });
      try {
        await tester.runAsync(prepareInterfaceArtwork);
        expect(assetReads, 0);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Image(image: skillTabletArtwork),
          ),
        );
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        expect(tester.takeException(), null);
      } finally {
        messenger.setMockMessageHandler('flutter/assets', null);
      }
    },
  );
}
