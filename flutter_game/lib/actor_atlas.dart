import 'dart:ui';

class ActorFrame {
  const ActorFrame(this.source, this.anchor, this.mirrored);
  final Rect source;
  final Offset anchor;
  final bool mirrored;
}

class ActorAtlas {
  const ActorAtlas._(
    this.frames,
    this.heights,
    this.motion,
    this.projectedOrigin,
    this.action,
  );
  factory ActorAtlas.fromJson(Map<String, dynamic> record) {
    final anchors = record['feet'] as List?,
        mirrors = record['mirrors'] as List?;
    final mode = record['anchorMode'];
    if (mode != null && mode != 'projected-origin') {
      throw const FormatException('Unknown actor anchor mode');
    }
    final projected = mode == 'projected-origin';
    final opted =
        projected || record['motion'] != null || record['action'] != null;
    if (opted &&
        (anchors == null ||
            anchors.length != (record['frames'] as List).length)) {
      throw const FormatException(
        'Opt-in frames require an explicit anchor for every source',
      );
    }
    final frames = List<ActorFrame>.unmodifiable([
      for (final (index, raw) in (record['frames'] as List).indexed)
        _frame(raw as List, anchors?[index] as List?, mirrors?[index] == true),
    ]);
    final heights = List<double>.unmodifiable([
      for (final size in record['sizes'] as List)
        ((size as List)[1] as num).toDouble(),
    ]);
    if (opted &&
        (frames.isEmpty ||
            heights.isEmpty ||
            heights.any((height) => !height.isFinite || height <= 0))) {
      throw const FormatException(
        'Opt-in actors require finite positive reference heights',
      );
    }
    if (opted &&
        frames.any((frame) {
          final source = frame.source;
          return frame.mirrored ||
              !frame.anchor.dx.isFinite ||
              !frame.anchor.dy.isFinite ||
              !source.left.isFinite ||
              !source.top.isFinite ||
              !source.width.isFinite ||
              !source.height.isFinite ||
              source.left < 0 ||
              source.top < 0 ||
              source.width <= 0 ||
              source.height <= 0;
        })) {
      throw const FormatException(
        'Opt-in actors need finite positive sources and finite unmirrored anchors',
      );
    }
    return ActorAtlas._(
      frames,
      heights,
      record['motion'] == null
          ? null
          : ActorRunClip.fromJson(
              record['motion'] as Map<String, dynamic>,
              frames,
            ),
      projected,
      record['action'] == null
          ? null
          : ActorActionClip.fromJson(
              record['action'] as Map<String, dynamic>,
              frames,
            ),
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
  final ActorRunClip? motion;
  final bool projectedOrigin;
  final ActorActionClip? action;
}

enum ActorRunLayout { phaseMajor, directionMajor }

/// Opt-in true sixteen-direction movement. Old two-frame atlases have no clip.
class ActorRunClip {
  const ActorRunClip._(
    this.framesPerDirection,
    this.runOffset,
    this.idleOffset,
    this.layout,
  );
  static const directions = 16;
  factory ActorRunClip.fromJson(
    Map<String, dynamic> record,
    List<ActorFrame> frames,
  ) {
    final count = record['runFrames'],
        run = record['runOffset'],
        idle = record['idleOffset'];
    final layout = switch (record['layout']) {
      'phase-major' => ActorRunLayout.phaseMajor,
      'direction-major' => ActorRunLayout.directionMajor,
      _ => null,
    };
    if (record['directions'] != directions ||
        count is! int ||
        count < 4 ||
        count > 8 ||
        run is! int ||
        idle is! int ||
        run < 0 ||
        idle < 0 ||
        layout == null) {
      throw const FormatException(
        'A true movement clip needs16 directions,4–8 run frames, offsets and a known layout',
      );
    }
    if (run > frames.length || idle > frames.length) {
      throw const FormatException(
        'Movement offsets must lie within the atlas before adding spans',
      );
    }
    final runEnd = run + directions * count, idleEnd = idle + directions;
    if (runEnd > frames.length ||
        idleEnd > frames.length ||
        !(idleEnd <= run || runEnd <= idle)) {
      throw const FormatException(
        'Idle and run blocks must be separate complete atlas ranges',
      );
    }
    final sources = <Rect>{};
    for (final index in [
      for (var i = idle; i < idleEnd; i++) i,
      for (var i = run; i < runEnd; i++) i,
    ]) {
      final frame = frames[index];
      if (frame.mirrored || !sources.add(frame.source)) {
        throw const FormatException(
          'True movement cannot alias or mirror neighboring direction/phase images',
        );
      }
    }
    return ActorRunClip._(count, run, idle, layout);
  }
  final int framesPerDirection, runOffset, idleOffset;
  final ActorRunLayout layout;

  int frameIndex(int direction, int phase, {required bool moving}) {
    if (direction < 0 || direction >= directions) {
      throw RangeError.range(direction, 0, directions - 1, 'direction');
    }
    if (!moving) return idleOffset + direction;
    final wrapped = phase % framesPerDirection;
    return runOffset +
        (layout == ActorRunLayout.phaseMajor
            ? wrapped * directions + direction
            : direction * framesPerDirection + wrapped);
  }
}

/// Real action poses use simulation progress independently of the run gait.
class ActorActionClip {
  const ActorActionClip._(this.framesPerDirection, this.layout);
  factory ActorActionClip.fromJson(
    Map<String, dynamic> record,
    List<ActorFrame> frames,
  ) {
    final count = record['frames'];
    final layout = switch (record['layout']) {
      'phase-major' => ActorRunLayout.phaseMajor,
      'direction-major' => ActorRunLayout.directionMajor,
      _ => null,
    };
    if (record['directions'] != 16 ||
        count is! int ||
        count < 6 ||
        count > 8 ||
        layout == null ||
        frames.length != count * 16) {
      throw const FormatException(
        'Action clips require16 directions and6–8 complete phases',
      );
    }
    final sources = <Rect>{};
    if (frames.any((frame) => frame.mirrored || !sources.add(frame.source))) {
      throw const FormatException(
        'Action poses cannot alias or mirror another frame',
      );
    }
    return ActorActionClip._(count, layout);
  }
  final int framesPerDirection;
  final ActorRunLayout layout;

  int frameIndex(int direction, double progress) {
    if (direction < 0 || direction >= 16) {
      throw RangeError.range(direction, 0, 15, 'direction');
    }
    final safe = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final phase = (safe * framesPerDirection).floor().clamp(
      0,
      framesPerDirection - 1,
    );
    return layout == ActorRunLayout.phaseMajor
        ? phase * 16 + direction
        : direction * framesPerDirection + phase;
  }
}
