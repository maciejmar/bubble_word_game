import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import 'bubble.dart';
import 'word_checker.dart';
import 'game_ui.dart';

////////////////////////////////////////////////////////////////////////
// WORD CHECKER (unchanged for your dictionary CSV logic, if any)
////////////////////////////////////////////////////////////////////////
final WordChecker globalWordChecker = WordChecker();

////////////////////////////////////////////////////////////////////////
// SPLASH SCREEN + RANDOM SMALL BUBBLES + RANDOM SOUNDS
////////////////////////////////////////////////////////////////////////

void main() {
  runApp(SplashScreenApp());
}

/// The splash screen app that shows "Webaby presents" + random soda bubbles
/// with multiple bubble sounds played at random intervals.
class SplashScreenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

// A model for your smaller "soda" bubble.
class SplashSmallBubble {
  double x;
  double y;
  double radius;
  double speed;
  Color color;

  SplashSmallBubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.color,
  });
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Ticker _bubbleTicker;
  final Random rng = Random();
  final List<SplashSmallBubble> sodaBubbles = [];
  late AudioPlayer _audioPlayer;

  final List<String> bubbleSounds = [
    'assets/bubble_sound.ogg',
    'assets/bubble_sound-2.ogg',
    'assets/bubble_sound-3.ogg',
  ];

  double _timeAccumulator = 0.0;
  double _nextSoundDelay = 2.0;

  @override
  void initState() {
    super.initState();

    // 1) Load the dictionary.
    _initGame();

    // 2) Setup top->bottom reveal animation.
    _controller = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    // After 2 seconds, start animation then go to main game.
    Future.delayed(Duration(seconds: 2), () {
      _controller.forward().then((_) {
        _audioPlayer.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => BubbleWordGame()),
        );
      });
    });

    // 3) Initialize soda bubbles.
    _initSodaBubbles();

    // 4) Ticker for bubble motion + random sound logic.
    DateTime? lastUpdate;
    _bubbleTicker = createTicker((now) {
      final current = DateTime.now();
      if (lastUpdate == null) {
        lastUpdate = current;
        return;
      }
      final dtSeconds =
          current.difference(lastUpdate!).inMicroseconds / 1e6;
      lastUpdate = current;
      setState(() {
        _updateSodaBubbles();
      });
      _handleRandomSounds(dtSeconds);
    });
    _bubbleTicker.start();

    // 5) Create your AudioPlayer.
    _audioPlayer = AudioPlayer();
  }

  Future<void> _initGame() async {
    await globalWordChecker.loadDictionary();
    print("Dictionary loaded in Splash!");
  }

  void _initSodaBubbles() {
    for (int i = 0; i < 20; i++) {
      sodaBubbles.add(SplashSmallBubble(
        x: rng.nextDouble() * 400,
        y: 700 + rng.nextDouble() * 200,
        radius: 5 + rng.nextDouble() * 15,
        speed: 0.5 + rng.nextDouble() * 1.5,
        color: Colors.primaries[rng.nextInt(Colors.primaries.length)]
            .withOpacity(rng.nextDouble() * 0.5 + 0.4),
      ));
    }
  }

  void _updateSodaBubbles() {
    for (var sb in sodaBubbles) {
      sb.y -= sb.speed;
      if (sb.y < -sb.radius * 2) {
        sb.y = 700 + rng.nextDouble() * 200;
        sb.x = rng.nextDouble() * 400;
        sb.radius = 5 + rng.nextDouble() * 15;
        sb.speed = 0.5 + rng.nextDouble() * 1.5;
        sb.color = Colors.primaries[rng.nextInt(Colors.primaries.length)]
            .withOpacity(rng.nextDouble() * 0.5 + 0.4);
      }
    }
  }

  void _handleRandomSounds(double dt) {
    _timeAccumulator += dt;
    if (_timeAccumulator >= _nextSoundDelay) {
      final soundIndex = rng.nextInt(bubbleSounds.length);
      final soundPath = bubbleSounds[soundIndex];
      _audioPlayer.play(AssetSource(soundPath));
      _timeAccumulator = 0.0;
      _nextSoundDelay = 0.5 + rng.nextDouble() * 1.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bubbleTicker.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: _animation.value,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  Center(
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
                        Container(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/webaby-logo.png',
                            width: 150,
                            height: 150,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          color: Colors.blue[50],
                          child: Image.asset(
                            'assets/webaby-bubble-ad.png',
                            width: 300,
                            height: 200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...sodaBubbles.map((sb) => Positioned(
                        left: sb.x,
                        top: sb.y,
                        child: Container(
                          width: sb.radius * 2,
                          height: sb.radius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sb.color,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////
// BUBBLE WORD GAME
////////////////////////////////////////////////////////////////////////

class BubbleWordGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BubbleGameScreen(),
    );
  }
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
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
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
  bool errorInCollectedLetters = false;
  late Ticker ticker;
  int score = 0;
  int timeLeft = 30;
  Timer? _clearTimer;
  Timer? _fadeTimer;
  Timer? _errorTimer;
  Timer? _successTimer;
  final List<String> collectedLetters = [];
  bool ambiguousMatch = false; // New flag for ambiguous (extended) match.
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
    print("DEBUG: Global dictionary size: ${globalWordChecker.dictionary.length}");
  }
  
  @override
  void dispose() {
    ticker.dispose();
    _clearTimer?.cancel();
    _fadeTimer?.cancel();
    _errorTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    Timer(Duration(seconds: 1), () {
      if (!mounted) return;
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
      // Reset ambiguous flag on new letter tap.
      ambiguousMatch = false;
      _checkForWords();
    });
    _fadeTimer = Timer(Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        letterOpacity = 0.0;
      });
    });
  }
  
  void _checkForWords() {
    if (collectedLetters.isEmpty) return;
    final wordToCheck = collectedLetters.join().toUpperCase();
    print("Word to check: $wordToCheck");
    print("startsAnyWord returns: ${globalWordChecker.startsAnyWord(wordToCheck)}");
  
    if (!globalWordChecker.startsAnyWord(wordToCheck)) {
      print("Clearing collectedLetters because no word starts with $wordToCheck");
      setState(() {
        errorInCollectedLetters = true;
      });
      _errorTimer = Timer(Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          collectedLetters.clear();
          errorInCollectedLetters = false;
        });
      });
      return;
    }
  
    // If the current letters form a valid word, check for ambiguous (extended) possibility.
    if (globalWordChecker.isValidWord(wordToCheck)) {
      // Check if there exists any longer word starting with wordToCheck.
      final longerMatches = globalWordChecker.dictionary
          .where((w) => w.startsWith(wordToCheck) && w.length > wordToCheck.length)
          .toList();
      if (longerMatches.isNotEmpty) {
        // There is a possibility to extend the word.
        setState(() {
          ambiguousMatch = true;
        });
        // Do not trigger success until the user taps the ambiguous check button.
        return;
      } else {
        // No longer word exists; accept word immediately.
        print("$wordToCheck is a valid word!");
        setState(() {
          score += wordToCheck.length * 10;
          wordSuccess = true;
        });
        _triggerSuccessAnimation();
        _successTimer = Timer(Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() {
            collectedLetters.clear();
            wordSuccess = false;
          });
        });
      }
    }
  }
  
  // Called when the ambiguous check button is tapped.
  void _acceptAmbiguousWord() {
    final wordToCheck = collectedLetters.join().toUpperCase();
    setState(() {
      score += wordToCheck.length * 10;
      wordSuccess = true;
      ambiguousMatch = false;
    });
    _triggerSuccessAnimation();
    _successTimer = Timer(Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        collectedLetters.clear();
        wordSuccess = false;
      });
    });
  }
  
  void _triggerSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Timer(Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.of(dialogContext).pop();
        });
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
                'BOOM! $score',
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Arco',
                ),
              ),
            ),
          ),
        );
      },
    );
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
                    Timer(Duration(milliseconds: 100), () {
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
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  SystemNavigator.pop();
                },
                child: Text(
                  "QUIT",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 134, 123, 22),
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
      timeLeft = 30;
      collectedLetters.clear();
      bubbles.clear();
      lastTappedLetter = '';
      letterOpacity = 0.0;
    });
    ticker.start();
    _startTimer();
  }
  
  // Build widget to show collected letters with ambiguous check.
  Widget _buildCollectedLetters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          collectedLetters.join(" "),
          style: TextStyle(
            fontSize: 28,
            color: errorInCollectedLetters ? Colors.red : Colors.white,
            fontFamily: 'Arco',
          ),
        ),
        // If ambiguousMatch is true, show a square check button.
        if (ambiguousMatch) ...[
          SizedBox(width: 8),
          GestureDetector(
            onTap: _acceptAmbiguousWord,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(255, 247, 84, 220), width: 3),
              ),
              child: Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),
        ],
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    print("collectedLetters: $collectedLetters");
    return Scaffold(
      body: Stack(
        children: [
          // Background.
          Container(
            color: const Color.fromARGB(255, 237, 240, 219),
          ),
          // Top info panel (time, score, etc.).
          // Remove duplicate collectedLetters display from GameUI if needed.
          GameUI(
            score: score,
            timeLeft: timeLeft,
            collectedLetters: collectedLetters, // If GameUI displays these, consider removing.
            wordSuccess: wordSuccess,
          ),
          // Floating bubbles (interactive).
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
          // (Optional) Remove this big single letter widget if it's redundant.
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
          // Bottom panel showing the collected letters and ambiguous check button.
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                // You can add a background color if desired.
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: _buildCollectedLetters(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
