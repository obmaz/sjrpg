import 'dart:ui';

const worldScale = .75;

enum WorldStage { forest, sands, past, future }

enum TimePath { past, future }

class TimeQuestGiver {
  const TimeQuestGiver(this.path, this.name, this.actor, this.offset);
  final TimePath path;
  final String name, actor;
  final Offset offset;
  Offset get at => WorldStage.sands.spawn + offset;
  String get destination =>
      path == TimePath.past ? '제3-1장 고대 왕국' : '제3-2장 사이버펑크';
}

const timeQuestGivers = [
  TimeQuestGiver(TimePath.past, '기록관', 'villager', Offset(-180, -50)),
  TimeQuestGiver(TimePath.future, '통신관', 'gunner', Offset(180, -50)),
];

extension WorldStageInfo on WorldStage {
  bool get hasNextStage =>
      this == WorldStage.forest || this == WorldStage.sands;
  String get title => [
    '제1장 · 십자로의 숲',
    '제2장 · 모래시계의 유적',
    '제3-1장 · 태초의 왕국',
    '제3-2장 · 네온의 심연',
  ][index];
  String get theme => ['숲과 초원', '사막과 폐허', '고대 왕국', '사이버펑크'][index];
  Color get sanctuaryColor => const [
    Color(0xffa9d5ae),
    Color(0xffedc98e),
    Color(0xffd3d5bc),
    Color(0xff7fe5ea),
  ][index];
  String get bossName => ['숲의 파수꾼', '모래시계 감시자', '태초의 석상왕', '중앙 방어 코어'][index];
  String get bossActor =>
      ['golem', 'sand-warden', 'ancient-king', 'cyber-core'][index];
  int get killGoal => [120, 160, 180, 180][index];
  Offset get spawn => authoredSpawn * worldScale;
  Offset get authoredSpawn => [
    const Offset(3840, 3055),
    const Offset(7200, 8600),
    const Offset(22800, 17200),
    const Offset(12400, 24200),
  ][index];
  String get commission => [
    '숲의 현자: 세 성소를 정화하고 깨어난 파수꾼을 멈춰 주게.',
    '시간 연구단: 유적의 균열이 두 시대를 가리킵니다. 한 시대만 추적할 수 있습니다.',
    '왕국의 기록관: 이곳은 숲이 생겨나기 전의 왕국입니다. 세 봉인을 되찾아 석상왕의 폭주를 막아 주세요.',
    '저항군 연락책: 균열 너머 도시는 방어 코어에 잠식됐어. 세 중계기를 복구하고 코어를 정지시켜 줘.',
  ][index];
}

class QuestSite {
  const QuestSite(
    this.id,
    this.name,
    this.hint,
    this.at,
    this.color, {
    this.artIndex = 0,
  });
  final String id, name, hint;
  final Offset at;
  final Color color;
  final int artIndex;
  QuestSite scaled() =>
      QuestSite(id, name, hint, at * worldScale, color, artIndex: artIndex);
  Rect get body =>
      Rect.fromCenter(center: at - const Offset(0, 42), width: 60, height: 42);
}

class CommissionDef {
  const CommissionDef(
    this.id,
    this.path,
    this.step,
    this.title,
    this.story,
    this.goal,
    this.site,
  );
  final String id, title, story;
  final TimePath path;
  final int step, goal;
  final QuestSite site;
}

const authoredTimeCommissions = [
  CommissionDef(
    'past-1',
    TimePath.past,
    0,
    '모래에 묻힌 어제',
    '시간 연구단의 의뢰. 사막의 사냥감을 물리치고 오래된 모래 우물에서 첫 기록을 찾으세요. 수락하면 미래 의뢰는 잠깁니다.',
    24,
    QuestSite(
      'past-1',
      '모래 우물',
      '야영지 동쪽, 첫 과거의 흔적',
      Offset(12000, 11000),
      Color(0xffffd184),
      artIndex: 0,
    ),
  ),
  CommissionDef(
    'past-2',
    TimePath.past,
    1,
    '사라진 왕의 이름',
    '우물의 기록은 아직 태어나지 않은 숲의 왕을 가리킵니다. 기록의 제단에서 왕의 이름을 복원하세요.',
    30,
    QuestSite(
      'past-2',
      '기록의 제단',
      '남서부 폐허의 기록',
      Offset(10000, 24000),
      Color(0xffffb786),
      artIndex: 1,
    ),
  ),
  CommissionDef(
    'past-3',
    TimePath.past,
    2,
    '거꾸로 도는 태양',
    '왕이 봉인한 시계가 뒤로 움직입니다. 해시계 주변을 확보하고 태양의 인장을 회수하세요.',
    36,
    QuestSite(
      'past-3',
      '황혼의 해시계',
      '남부 순례길의 해시계',
      Offset(26000, 28000),
      Color(0xffffe39e),
      artIndex: 2,
    ),
  ),
  CommissionDef(
    'past-4',
    TimePath.past,
    3,
    '태초로 향하는 문',
    '인장을 문에 돌려놓으면 숲보다 더 오래된 왕국으로 갈 수 있습니다. 감시자를 쓰러뜨려 시대의 길을 여세요.',
    45,
    QuestSite(
      'past-4',
      '태초의 문',
      '북동쪽 협곡의 호박빛 문',
      Offset(39000, 13000),
      Color(0xffffd184),
      artIndex: 3,
    ),
  ),
  CommissionDef(
    'future-1',
    TimePath.future,
    0,
    '아직 오지 않은 신호',
    '시간 연구단의 의뢰. 사막의 위협을 제거하고 푸른 우물에서 정체불명의 신호를 읽으세요. 수락하면 과거 의뢰는 잠깁니다.',
    24,
    QuestSite(
      'future-1',
      '신호의 우물',
      '북쪽 오아시스, 푸른 빛',
      Offset(16000, 4000),
      Color(0xff88e8ef),
      artIndex: 4,
    ),
  ),
  CommissionDef(
    'future-2',
    TimePath.future,
    1,
    '별에서 떨어진 금속',
    '신호는 미래 도시의 구조 요청입니다. 추락한 중계기를 찾아 손상된 좌표를 복구하세요.',
    30,
    QuestSite(
      'future-2',
      '추락 중계기',
      '북동쪽 모래 절벽 아래',
      Offset(33000, 7500),
      Color(0xff97dcff),
      artIndex: 5,
    ),
  ),
  CommissionDef(
    'future-3',
    TimePath.future,
    2,
    '번개를 담은 샘',
    '중계기의 동력이 부족합니다. 전류의 샘 주변을 확보하고 시간 전지를 충전하세요.',
    36,
    QuestSite(
      'future-3',
      '전류의 샘',
      '남동쪽 결정 사구',
      Offset(39000, 23000),
      Color(0xffb8a3ff),
      artIndex: 6,
    ),
  ),
  CommissionDef(
    'future-4',
    TimePath.future,
    3,
    '내일을 여는 문',
    '도시의 신호가 선명해졌습니다. 시간의 문을 안정시키고 감시자를 물리쳐 네온 도시로 향하세요.',
    45,
    QuestSite(
      'future-4',
      '내일의 문',
      '남부 잊힌 관측소',
      Offset(22000, 29000),
      Color(0xff88e8ef),
      artIndex: 7,
    ),
  ),
];

const authoredAncientSites = [
  QuestSite(
    'crown',
    '왕관의 성소',
    '북서부 왕의 묘역',
    Offset(9000, 8000),
    Color(0xffffdc96),
    artIndex: 1,
  ),
  QuestSite(
    'sunfire',
    '태양의 화로',
    '북동부 태양 신전',
    Offset(39000, 6500),
    Color(0xffffbf75),
    artIndex: 2,
  ),
  QuestSite(
    'origin',
    '태초의 봉인',
    '남부 계곡의 시간문',
    Offset(30000, 28500),
    Color(0xffffe5ae),
    artIndex: 3,
  ),
];
const authoredNeonSites = [
  QuestSite(
    'uplink',
    '업링크',
    '북서부 폐쇄 지구',
    Offset(9000, 8000),
    Color(0xff88e8ef),
    artIndex: 6,
  ),
  QuestSite(
    'relay',
    '중계 코일',
    '동부 공장 지구',
    Offset(36500, 12000),
    Color(0xffb8a3ff),
    artIndex: 1,
  ),
  QuestSite(
    'gate',
    '코어 게이트',
    '남동부 중앙 관제소',
    Offset(30000, 30000),
    Color(0xff88e8ef),
    artIndex: 7,
  ),
];

final timeCommissions = List<CommissionDef>.unmodifiable(
  authoredTimeCommissions.map(
    (q) => CommissionDef(
      q.id,
      q.path,
      q.step,
      q.title,
      q.story,
      q.goal,
      q.site.scaled(),
    ),
  ),
);
final ancientSites = List<QuestSite>.unmodifiable(
  authoredAncientSites.map((s) => s.scaled()),
);
final neonSites = List<QuestSite>.unmodifiable(
  authoredNeonSites.map((s) => s.scaled()),
);
