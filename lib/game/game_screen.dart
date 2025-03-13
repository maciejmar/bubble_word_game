import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'bubble.dart';
import 'word_checker.dart';
import 'game_ui.dart';

/// ------------------------------
///  Splash Screen and main()
/// ------------------------------
void main() {
  runApp(SplashScreenApp());
}

/// This is the app that first shows the splash screen, then navigates to BubbleWordGame.
class SplashScreenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // We'll define the splash below
    );
  }
}

/// The splash screen that:
/// 1) Displays "Webaby presents"
/// 2) Shows webaby-logo.png
/// 3) Shows webaby-bubble-ad.png
/// 4) Over 2 seconds, it does a top-to-bottom reveal
/// 5) Navigates to BubbleWordGame
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // We'll animate from 1.0 to 0.0 over 2 seconds,
    // "sliding" the splash off the screen from top to bottom
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    // After 2 seconds, we run the animation, then go to the main game
    Future.delayed(Duration(seconds: 4), () {
      _controller.forward().then((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => BubbleWordGame()),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We shrink the Column from full heightFactor=1 down to 0
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: _animation.value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Webaby presents",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Arco',
                  ),
                ),
                SizedBox(height: 20),
                // your actual logo
                Image.asset(
                  'assets/webaby-logo.png',
                  width: 150,
                  height: 150,
                ),
                SizedBox(height: 20),
                // your advertisement
                Image.asset(
                  'assets/webaby-bubble-ad.png',
                  width: 300,
                  height: 200,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// -----------------------------------------
/// Your original code: BubbleWordGame
/// (unchanged except we don't run it from main)
/// -----------------------------------------
class BubbleWordGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BubbleGameScreen(),
    );
  }
}

// Your blinking GAME OVER widget
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
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // If you want to re-enable a "PLAY AGAIN" line, do so here
          ],
        ),
      ),
    );
  }
}

class BubbleGameScreen extends StatefulWidget {
  @override
  _BubbleGameScreenState createState() => _BubbleGameScreenState();
}

class _BubbleGameScreenState extends State<BubbleGameScreen>
    with SingleTickerProviderStateMixin {
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
      bubbles.add(
        Bubble(
          x: random.nextDouble() * 300,
          y: 600,
          letter: String.fromCharCode(65 + random.nextInt(26)),
        ),
      );
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
    // Fade out letter after 1 second
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
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                        offset: Offset(3, 3),
                      ),
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
      lastTappedLetter = '';
      letterOpacity = 0.0;
    });
    ticker.start();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The background color
          Container(
            color: const Color.fromARGB(255, 237, 240, 219),
          ),
          // Score/time UI
          GameUI(
            score: score,
            timeLeft: timeLeft,
            collectedLetters: collectedLetters,
            wordSuccess: wordSuccess,
          ),
          // The letter that fades in/out after tapping a bubble
          Positioned(
            top: 100,
            right: 50,
            child: AnimatedOpacity(
              opacity: letterOpacity,
              duration: Duration(milliseconds: 500),
              child: Text(
                lastTappedLetter,
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Arco',
                ),
              ),
            ),
          ),
          // The floating bubbles
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
