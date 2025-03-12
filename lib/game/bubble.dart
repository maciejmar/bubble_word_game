import 'dart:math';
import 'package:flutter/material.dart';

class Bubble {
  double x;
  double y;
  String letter;
  bool toBeRemoved = false;
  
  Bubble({required this.x, required this.y, required this.letter});
}

class BubbleGenerator {
  final Random random = Random();
  
  Bubble generateBubble(double screenWidth, double screenHeight) {
    return Bubble(
      x: random.nextDouble() * screenWidth,
      y: screenHeight,
      letter: String.fromCharCode(65 + random.nextInt(26)),
    );
  }
}
