import 'dart:ui';

import 'stage_content.dart';

/// Walkable tops and their open stair/ramp edge, authored in 768px art cells.
/// Cliff faces stop ground movement; only validated airborne movement skips them.
class LandmarkTerrace {
  const LandmarkTerrace(
    this.outline,
    this.entrance, {
    this.faces = const [],
    this.solids = const [],
  });
  final List<Offset> outline;
  final int entrance;
  final List<List<Offset>> faces, solids;

  Iterable<List<Offset>> get ledges sync* {
    yield* faces;
    for (var i = 0; i < outline.length; i++) {
      if (i == entrance) continue;
      final a = outline[i], b = outline[(i + 1) % outline.length];
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance * 4;
      yield [a + n, b + n, b - n, a - n];
    }
  }

  static LandmarkTerrace? forArt(WorldStage stage, int index) =>
      switch ((stage, index)) {
        (WorldStage.forest, 1) => const LandmarkTerrace(
          [
            Offset(160, 425),
            Offset(210, 390),
            Offset(405, 375),
            Offset(550, 450),
            Offset(430, 520),
            Offset(235, 475),
          ],
          0,
          faces: [
            [
              Offset(235, 475),
              Offset(430, 520),
              Offset(550, 450),
              Offset(664, 626),
              Offset(532, 708),
              Offset(310, 720),
              Offset(142, 633),
              Offset(142, 510),
            ],
          ],
          solids: [
            [
              Offset(295, 245),
              Offset(480, 205),
              Offset(627, 285),
              Offset(650, 430),
              Offset(550, 450),
              Offset(450, 370),
              Offset(300, 365),
            ],
          ],
        ),
        (WorldStage.forest, 2) => const LandmarkTerrace(
          [
            Offset(150, 480),
            Offset(215, 440),
            Offset(405, 425),
            Offset(540, 490),
            Offset(460, 565),
            Offset(280, 555),
          ],
          0,
          faces: [
            [
              Offset(280, 555),
              Offset(460, 565),
              Offset(540, 490),
              Offset(628, 640),
              Offset(526, 695),
              Offset(336, 696),
              Offset(172, 626),
            ],
          ],
          solids: [
            [
              Offset(175, 275),
              Offset(315, 325),
              Offset(280, 430),
              Offset(160, 435),
            ],
          ],
        ),
        (WorldStage.forest, 3) => const LandmarkTerrace(
          [
            Offset(270, 655),
            Offset(390, 675),
            Offset(540, 605),
            Offset(550, 535),
            Offset(440, 490),
            Offset(300, 515),
            Offset(220, 590),
          ],
          0,
          solids: [
            [
              Offset(240, 310),
              Offset(510, 310),
              Offset(510, 490),
              Offset(260, 515),
            ],
          ],
        ),
        (WorldStage.sands, 0) => const LandmarkTerrace(
          [
            Offset(215, 555),
            Offset(315, 600),
            Offset(525, 495),
            Offset(505, 430),
            Offset(345, 380),
            Offset(200, 465),
          ],
          0,
          solids: [
            [
              Offset(290, 220),
              Offset(490, 220),
              Offset(505, 430),
              Offset(345, 410),
            ],
          ],
        ),
        (WorldStage.past, 0) => const LandmarkTerrace(
          [
            Offset(300, 650),
            Offset(440, 650),
            Offset(570, 560),
            Offset(555, 460),
            Offset(400, 390),
            Offset(245, 440),
            Offset(190, 540),
          ],
          0,
          solids: [
            [
              Offset(210, 260),
              Offset(555, 260),
              Offset(555, 430),
              Offset(245, 415),
            ],
          ],
        ),
        (WorldStage.past, 2) => const LandmarkTerrace(
          [
            Offset(440, 660),
            Offset(535, 620),
            Offset(470, 500),
            Offset(350, 440),
            Offset(230, 470),
            Offset(235, 560),
          ],
          0,
          solids: [
            [
              Offset(250, 240),
              Offset(420, 260),
              Offset(420, 430),
              Offset(260, 450),
            ],
          ],
        ),
        (WorldStage.past, 3) => const LandmarkTerrace(
          [
            Offset(265, 635),
            Offset(395, 660),
            Offset(560, 550),
            Offset(530, 450),
            Offset(400, 420),
            Offset(220, 500),
          ],
          0,
          solids: [
            [
              Offset(285, 250),
              Offset(530, 250),
              Offset(530, 450),
              Offset(400, 455),
            ],
          ],
        ),
        (WorldStage.tombs, 0) => const LandmarkTerrace(
          [
            Offset(235, 650),
            Offset(345, 685),
            Offset(560, 560),
            Offset(500, 460),
            Offset(310, 420),
            Offset(185, 525),
          ],
          0,
          solids: [
            [
              Offset(270, 210),
              Offset(530, 250),
              Offset(530, 470),
              Offset(315, 505),
            ],
          ],
        ),
        (WorldStage.tombs, 3) => const LandmarkTerrace(
          [
            Offset(250, 665),
            Offset(350, 690),
            Offset(535, 465),
            Offset(430, 420),
            Offset(325, 480),
          ],
          0,
          solids: [
            [
              Offset(430, 200),
              Offset(510, 210),
              Offset(510, 420),
              Offset(440, 435),
            ],
          ],
        ),
        (WorldStage.convergence, 1) => const LandmarkTerrace(
          [
            Offset(540, 550),
            Offset(600, 505),
            Offset(485, 400),
            Offset(345, 390),
            Offset(190, 475),
            Offset(320, 540),
            Offset(455, 570),
          ],
          0,
          faces: [
            [
              Offset(190, 475),
              Offset(320, 540),
              Offset(455, 570),
              Offset(540, 550),
              Offset(520, 665),
              Offset(300, 690),
              Offset(160, 600),
            ],
          ],
          solids: [
            [
              Offset(295, 230),
              Offset(465, 245),
              Offset(485, 390),
              Offset(325, 420),
            ],
          ],
        ),
        (WorldStage.convergence, 2) => const LandmarkTerrace(
          [
            Offset(245, 650),
            Offset(345, 675),
            Offset(540, 500),
            Offset(450, 445),
            Offset(300, 475),
            Offset(205, 550),
          ],
          0,
          solids: [
            [
              Offset(190, 260),
              Offset(330, 255),
              Offset(330, 460),
              Offset(200, 490),
            ],
          ],
        ),
        (WorldStage.convergence, 3) => const LandmarkTerrace(
          [
            Offset(255, 665),
            Offset(380, 690),
            Offset(550, 550),
            Offset(480, 470),
            Offset(345, 465),
            Offset(200, 565),
          ],
          0,
          solids: [
            [
              Offset(250, 240),
              Offset(520, 260),
              Offset(520, 475),
              Offset(345, 495),
            ],
          ],
        ),
        _ => null,
      };
}
