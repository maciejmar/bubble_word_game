import 'dart:math';
import 'package:flutter/material.dart';

class Bubble {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  String letter;
  bool toBeRemoved = false;

  Bubble({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.letter,
  });
}

class BubbleGenerator {
  final Random random = Random();
  
  Bubble generateBubble(double screenWidth, double screenHeight) {
    final angle = (random.nextDouble() * pi / 3) + (pi / 3); 
    // random between 60° and 120° (so roughly upward)
    final speed = 2 + random.nextDouble() * 2; 
    return Bubble(
      x: random.nextDouble() * screenWidth,
      y: screenHeight + 20,
      vx: speed * cos(angle),
      vy: -speed * sin(angle),
      radius: 30,
      letter: String.fromCharCode(65 + random.nextInt(26)),
    );
  }
}
