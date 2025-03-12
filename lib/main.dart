import 'package:flutter/material.dart';
import 'game/game_screen.dart';

void main() {
  runApp(BubbleWordGame());
}

class BubbleWordGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BubbleGameScreen(),
    );
  }
}
