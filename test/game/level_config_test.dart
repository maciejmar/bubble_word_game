import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bubble_word_game/game/level_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('level 8 selects its own packaged background', () async {
    const background = 'assets/treeCoast-level-8.png';

    expect(GameLevelConfig.backgroundAssetForLevel(8), background);
    await rootBundle.load(background);
  });

  test('level 8 increases movement and spawn difficulty over level 7', () {
    expect(
      GameLevelConfig.speedMultiplierForLevel(8),
      greaterThan(GameLevelConfig.speedMultiplierForLevel(7)),
    );
    expect(
      GameLevelConfig.spawnProbabilityForDelta(8, 1 / 60),
      greaterThan(GameLevelConfig.spawnProbabilityForDelta(7, 1 / 60)),
    );
  });

  test('the final level does not advance into a missing level 9', () {
    expect(GameLevelConfig.shouldAdvanceLevel(350, 7), isTrue);
    expect(GameLevelConfig.shouldAdvanceLevel(400, 8), isFalse);
  });
}
