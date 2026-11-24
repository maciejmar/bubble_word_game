import 'dart:math';

class GameLevelConfig {
  static const int maxLevel = 8;

  static int normalizeLevel(int level) {
    if (level < 1) return 1;
    if (level > maxLevel) return maxLevel;
    return level;
  }

  static String backgroundAssetForLevel(int level) {
    final normalizedLevel = normalizeLevel(level);
    if (normalizedLevel == 1) return 'assets/canyon_river_background.png';
    return 'assets/treeCoast-level-$normalizedLevel.png';
  }

  static double speedMultiplierForLevel(int level) {
    return 1 + (normalizeLevel(level) - 1) * 0.05;
  }

  static double spawnProbabilityForDelta(int level, double deltaSeconds) {
    if (deltaSeconds <= 0) return 0;

    final normalizedLevel = normalizeLevel(level);
    final probabilityPer60HzFrame = 0.05 + (normalizedLevel - 1) * 0.005;
    return (1 - pow(1 - probabilityPer60HzFrame, deltaSeconds * 60)).toDouble();
  }

  static bool shouldAdvanceLevel(int score, int currentLevel) {
    final normalizedLevel = normalizeLevel(currentLevel);
    return normalizedLevel < maxLevel && score >= normalizedLevel * 50;
  }
}
