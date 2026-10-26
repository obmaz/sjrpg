import 'dart:async';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const _sourceArtwork = <String, ExactAssetImage>{
  'primary': ExactAssetImage('assets/images/ui-button-primary.webp', scale: 3),
  'secondary': ExactAssetImage(
    'assets/images/ui-button-secondary.webp',
    scale: 3,
  ),
  'disabled': ExactAssetImage(
    'assets/images/ui-button-disabled.webp',
    scale: 3,
  ),
  'tablet': ExactAssetImage('assets/images/skill-tablet.webp'),
};
final _loadedArtwork = <String, ImageProvider<Object>>{};
Future<void>? _sourceLoading;

ImageProvider<Object> _artwork(String key) =>
    _loadedArtwork[key] ?? _sourceArtwork[key]!;
ImageProvider<Object> buttonArtwork({
  bool enabled = true,
  bool primary = false,
}) => _artwork(
  !enabled
      ? 'disabled'
      : primary
      ? 'primary'
      : 'secondary',
);
ImageProvider<Object> get skillTabletArtwork => _artwork('tablet');
Iterable<ImageProvider<Object>> get interfaceArtworkProviders =>
    _sourceArtwork.keys.map(_artwork);

Future<void> _loadSources() async {
  final entries = await Future.wait(
    _sourceArtwork.entries.map((entry) async {
      final data = await rootBundle.load(entry.value.assetName);
      // A live page can still open its UI after that release leaves the server.
      return MapEntry<String, ImageProvider<Object>>(
        entry.key,
        MemoryImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          scale: entry.value.scale,
        ),
      );
    }),
  );
  _loadedArtwork.addEntries(entries);
}

Future<void> prepareInterfaceArtwork() async {
  try {
    await (_sourceLoading ??= _loadSources());
    await Future.wait(interfaceArtworkProviders.map(_decode));
  } catch (_) {
    _loadedArtwork.clear();
    _sourceLoading = null;
    rethrow;
  }
}

Future<void> _decode(ImageProvider<Object> provider) {
  final ready = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronous) {
      if (!ready.isCompleted) ready.complete();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        info.dispose();
        stream.removeListener(listener);
      });
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      if (!ready.isCompleted) ready.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return ready.future;
}
