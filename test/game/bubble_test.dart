import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bubble_word_game/game/bubble.dart';

void main() {
  test('bubble movement is independent of frame rate', () {
    final bubbleAt60Hz = Bubble(
      x: 10,
      y: 20,
      vx: 120,
      vy: -240,
      radius: 30,
      letter: 'A',
    );
    final bubbleAt120Hz = Bubble(
      x: 10,
      y: 20,
      vx: 120,
      vy: -240,
      radius: 30,
      letter: 'A',
    );

    for (var frame = 0; frame < 60; frame++) {
      bubbleAt60Hz.advanceBy(1 / 60);
    }
    for (var frame = 0; frame < 120; frame++) {
      bubbleAt120Hz.advanceBy(1 / 120);
    }

    expect(bubbleAt60Hz.x, closeTo(130, 1e-8));
    expect(bubbleAt60Hz.y, closeTo(-220, 1e-8));
    expect(bubbleAt120Hz.x, closeTo(bubbleAt60Hz.x, 1e-8));
    expect(bubbleAt120Hz.y, closeTo(bubbleAt60Hz.y, 1e-8));
  });

  test('generated bubble speed preserves the original 2–4 px/frame feel at 60Hz', () {
    final bubble = BubbleGenerator().generateBubble(400, 800);
    final speed = sqrt(bubble.vx * bubble.vx + bubble.vy * bubble.vy);

    expect(speed, inInclusiveRange(120, 240));
    expect(bubble.vy, lessThan(0));
  });
}
