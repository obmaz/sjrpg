import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_art.dart';

const entryBrass = Color(0xffaa9979), entryCream = Color(0xffe1dccb);

enum EntryPiece { crest, frame, nameplate, action, progress, selected }

/// Source rectangles use the original 1536×1024 atlas coordinates.
/// Borders are sliced so narrow and wide layouts retain the same corner craft.
class EntryChrome extends CustomPainter {
  const EntryChrome(this.art, this.piece);
  final GameArt art;
  final EntryPiece piece;
  static const sources = {
    EntryPiece.crest: Rect.fromLTRB(108, 198, 373, 502),
    EntryPiece.frame: Rect.fromLTRB(503, 118, 984, 584),
    EntryPiece.nameplate: Rect.fromLTRB(1008, 281, 1507, 425),
    EntryPiece.action: Rect.fromLTRB(17, 675, 692, 871),
    EntryPiece.progress: Rect.fromLTRB(715, 729, 1274, 827),
    EntryPiece.selected: Rect.fromLTRB(1317, 683, 1502, 877),
  };
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['entry-ui'];
    if (image == null) return;
    final ratio = image.width / 1536;
    final source = sources[piece]!;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    void draw(Rect src, Rect dst) => canvas.drawImageRect(
      image,
      Rect.fromLTRB(
        src.left * ratio,
        src.top * ratio,
        src.right * ratio,
        src.bottom * ratio,
      ),
      dst,
      paint,
    );
    if (piece == EntryPiece.crest || piece == EntryPiece.selected) {
      final fitted = applyBoxFit(BoxFit.contain, source.size, size);
      draw(
        source,
        Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      );
      return;
    }
    final sx = source.width * (piece == EntryPiece.frame ? .19 : .22);
    final sy = source.height * .22;
    final dx = math.min(
      piece == EntryPiece.frame ? 15.0 : 27.0,
      size.width / 3,
    );
    final dy = math.min(
      piece == EntryPiece.frame ? 15.0 : 13.0,
      size.height / 3,
    );
    final xs = [source.left, source.left + sx, source.right - sx, source.right];
    final ys = [source.top, source.top + sy, source.bottom - sy, source.bottom];
    final xd = [0.0, dx, size.width - dx, size.width];
    final yd = [0.0, dy, size.height - dy, size.height];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        draw(
          Rect.fromLTRB(xs[col], ys[row], xs[col + 1], ys[row + 1]),
          Rect.fromLTRB(xd[col], yd[row], xd[col + 1], yd[row + 1]),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant EntryChrome old) =>
      old.art != art || old.piece != piece;
}

class EntryAction extends StatelessWidget {
  const EntryAction(
    this.label, {
    required this.art,
    required this.onTap,
    this.height = 62,
    super.key,
  });
  final String label;
  final GameArt art;
  final VoidCallback onTap;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: EntryChrome(art, EntryPiece.action),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: entryCream,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
