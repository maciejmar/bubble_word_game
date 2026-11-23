import 'package:flutter/material.dart';
import 'game/game_screen.dart';

void main() {
  print("DEBUG: Starting SplashScreen!");
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    ),
  );
}