import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'bubble.dart';
import 'word_checker.dart';
import 'game_ui.dart';

void main() {
  runApp(BubbleWordGame());
}

class FlashingGameOverText extends StatefulWidget {
  @override
  _FlashingGameOverTextState createState() => _FlashingGameOverTextState();
}

class _FlashingGameOverTextState extends State<FlashingGameOverText> {
  bool isVisible = true;

  @override
  void initState() {
    super.initState();
    _startFlashing();
  }

  void _startFlashing() {
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isVisible = !isVisible;
        });
        _startFlashing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.2,
        duration: Duration(milliseconds: 500),
        child: Column(
          children: [
            Text(
              "GAME OVER",
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                decoration: TextDecoration.none,
                fontFamily: 'Arco',
                shadows: [
                  Shadow(blurRadius: 10, color: Colors.black, offset: Offset(3, 3)),
                ],
              ),
            ),
            SizedBox(height: 20),
            // GestureDetector(
            //   onTap: () {
            //     Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
            //     Future.delayed(Duration(milliseconds: 100), () {
            //       (context.findAncestorStateOfType<_BubbleGameScreenState>())?._restartGame();
            //     });
            //   },
            //   child: Text(
            //     "PLAY AGAIN",
            //     style: TextStyle(
            //       fontSize: 40,
            //       fontWeight: FontWeight.bold,
            //       color: Colors.green,
            //       fontFamily: 'Arco',
            //       decoration: TextDecoration.none,
            //       shadows: [
            //         Shadow(blurRadius: 10, color: Colors.black, offset: Offset(3, 3)),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
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

class BubbleGameScreen extends StatefulWidget {
  @override
  _BubbleGameScreenState createState() => _BubbleGameScreenState();
}

class _BubbleGameScreenState extends State<BubbleGameScreen> with SingleTickerProviderStateMixin {
  final List<Bubble> bubbles = [];
  final Random random = Random();
  late Ticker ticker;
  int score = 0;
  int timeLeft = 10;
  final List<String> collectedLetters = [];
  final WordChecker wordChecker = WordChecker();
  bool wordSuccess = false;
  String lastTappedLetter = '';
  double letterOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker((_) {
      setState(() {
        _updateBubbles();
      });
    });
    ticker.start();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (timeLeft == 0) {
        ticker.stop();
        _showGameOverDialog();
      } else {
        setState(() {
          timeLeft--;
        });
        _startTimer();
      }
    });
  }

  void _updateBubbles() {
    for (var bubble in bubbles) {
      bubble.y -= 2;
      if (bubble.y < 0) {
        bubble.toBeRemoved = true;
      }
    }
    bubbles.removeWhere((b) => b.toBeRemoved);
    if (random.nextDouble() < 0.05) {
      bubbles.add(Bubble(
        x: random.nextDouble() * 300,
        y: 600,
        letter: String.fromCharCode(65 + random.nextInt(26)),
      ));
    }
  }

  void _onBubbleTap(Bubble bubble) {
    if (timeLeft == 0) return;
    setState(() {
      collectedLetters.add(bubble.letter);
      lastTappedLetter = bubble.letter;
      letterOpacity = 1.0;
      bubble.toBeRemoved = true;
      _checkForWords();
    });
    Future.delayed(Duration(seconds: 1), () {
    if (mounted) {
      setState(() {
        letterOpacity = 0.0;
      });
    }
  });

  }

  void _checkForWords() {
    if (collectedLetters.isEmpty) return;
    String wordToCheck = collectedLetters.join();
    if (!wordChecker.dictionary.any((word) => word.startsWith(wordToCheck))) {
      setState(() {
        collectedLetters.clear();
      });
      return;
    }
    if (wordChecker.isValidWord(wordToCheck)) {
      setState(() {
        score += wordToCheck.length * 10;
        wordSuccess = true;
      });
      _triggerSuccessAnimation();
      Future.delayed(Duration(milliseconds: 700), () {
        setState(() {
          collectedLetters.clear();
          wordSuccess = false;
        });
      });
    }
  }

  void _triggerSuccessAnimation() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.7),
            ),
            child: Center(
              child: Text(
                "BOOM!",
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arco',
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(Duration(milliseconds: 500), () {
      Navigator.of(context).pop();
    });
  }

  void _showGameOverDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlashingGameOverText(),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop(); 
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted) _restartGame(); 
                  });
                }
              },
              child: Text(
                "PLAY AGAIN",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontFamily: 'Arco',
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(blurRadius: 10, color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  void _restartGame() {
    setState(() {
      score = 0;
      timeLeft = 10;
      collectedLetters.clear();
      bubbles.clear();
      ticker.start();
      _startTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: const Color.fromARGB(255, 237, 240, 219),
         ),
          GameUI(score: score, timeLeft: timeLeft, collectedLetters: collectedLetters, wordSuccess: wordSuccess),
          Positioned(
            top: 100, // Ustawienie litery pod wynikiem
            right: 50,
            child: AnimatedOpacity(
              opacity: letterOpacity,
              duration: Duration(milliseconds: 500), // Efekt fade-in i fade-out
              child: Text(
                lastTappedLetter,
                style: TextStyle(
                  fontSize: 100, // 4x większa czcionka
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Arco',
                ),
              ),
            ),
          ),

          ...bubbles.map((bubble) => Positioned(
                left: bubble.x,
                top: bubble.y,
                child: GestureDetector(
                  onTap: () => _onBubbleTap(bubble),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/bubble-4.png',
                        width: 50,
                        height: 50,
                      ),
                      Text(
                        bubble.letter,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromARGB(255, 72, 23, 100),
                          fontFamily: 'Arco',
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
