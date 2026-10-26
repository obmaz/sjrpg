import 'dart:ui';

class ActorFrame {
  const ActorFrame(this.source, this.anchor, this.mirrored);
  final Rect source;
  final Offset anchor;
  final bool mirrored;
}

class ActorAtlas {
  const ActorAtlas._(this.frames, this.heights);
  factory ActorAtlas.fromJson(Map<String, dynamic> record) {
    final anchors = record['feet'] as List?,
        mirrors = record['mirrors'] as List?;
    return ActorAtlas._(
      List.unmodifiable([
        for (final (index, raw) in (record['frames'] as List).indexed)
          _frame(
            raw as List,
            anchors?[index] as List?,
            mirrors?[index] == true,
          ),
      ]),
      List.unmodifiable([
        for (final size in record['sizes'] as List)
          ((size as List)[1] as num).toDouble(),
      ]),
    );
  }

  static ActorFrame _frame(List raw, List? anchor, bool mirrored) {
    final source = Rect.fromLTWH(
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
      (raw[2] as num).toDouble(),
      (raw[3] as num).toDouble(),
    );
    return ActorFrame(
      source,
      anchor == null
          ? Offset(source.width / 2, source.height)
          : Offset(
              (anchor[0] as num).toDouble() - source.left,
              (anchor[1] as num).toDouble() - source.top,
            ),
      mirrored,
    );
  }

  final List<ActorFrame> frames;
  final List<double> heights;
}
