import 'package:flutter/material.dart';
import 'game/game_screen.dart';

void main() {
  print("DEBUG: Starting SplashScreen!");
  // Keep ONLY ONE runApp call:
  runApp(SplashScreenApp());
}

// No second runApp call here!

/// We define the same classes you used:
class BubbleWordGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BubbleGameScreen(),
    );
  }
}
