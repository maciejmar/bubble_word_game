import 'package:flutter/material.dart';

class GameUI extends StatelessWidget {
  final int score;
  final int timeLeft;
  final List<String> collectedLetters;
  final bool wordSuccess;

  const GameUI({
    Key? key,
    required this.score,
    required this.timeLeft,
    required this.collectedLetters,
    required this.wordSuccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 20,
          left: 20,
          child: Text("Time: $timeLeft", style: TextStyle(fontSize: 20, fontFamily: "Arco", color: const Color.fromARGB(255, 6, 48, 70))),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Text(
            "Score: $score",
            style: TextStyle(
              fontSize: 24,
              fontFamily: "Arco",
              color: Colors.white,
              shadows: [
                Shadow(blurRadius: 3, color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 50,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: wordSuccess ? 1.0 : 0.8,
            duration: Duration(milliseconds: 500),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 77, 2, 60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  collectedLetters.join(" "),
                  style: TextStyle(fontSize: 24, color: const Color.fromARGB(255, 77, 2, 60)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
