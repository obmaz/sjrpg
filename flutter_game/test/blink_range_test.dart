import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/sorceress_rules.dart';

void main() {
  test(
    'blink starts at half its previous rank-one reach and keeps each increment',
    () {
      double reach(int rank) => SorceressRules.evaluate(
        'blink',
        rank: rank,
        hardRanks: const {},
      ).range;
      expect(reach(1), 225);
      for (var rank = 2; rank <= 20; rank++) {
        expect(reach(rank) - reach(rank - 1), closeTo(150 / 19, 1e-9));
      }
      expect(reach(20), 375);
      expect(
        SorceressRules.evaluate(
          'telekinesis',
          rank: 1,
          hardRanks: const {},
        ).range,
        greaterThan(225),
      );
    },
  );
}
