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
    _audioPlayer = AudioPlayer(); // initialize audio player for this screen
    // _audioPlayer.setVolume(1.0);
    // _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // 1) Load the dictionary.
    _initGame();

    // 2) Setup top->bottom reveal animation.
    _controller = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

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
    //_audioPlayer = AudioPlayer();
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
        // respawn bubble.
        sb.y = 700 + rng.nextDouble() * 200;
        sb.x = rng.nextDouble() * 400;
        sb.radius = 5 + rng.nextDouble() * 15;
        sb.speed = 0.5 + rng.nextDouble() * 1.5;
        sb.color = Colors.primaries[rng.nextInt(Colors.primaries.length)]
            .withOpacity(rng.nextDouble() * 0.5 + 0.4);
        // Optionally play a sound when a bubble respawns:
        // _audioPlayer.play(AssetSource('assets/bubble_sound.ogg')).then((result) {
        //   print('Play result: $result');
        // }).catchError((error) {
        //   print('Audio play error: $error');
        // });
        _audioPlayer.play(AssetSource('assets/success-letter.ogg'));
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
  final List<_BubbleExplosion> _explosions = [];
  final Random random = Random();
  late AudioPlayer _audioPlayer;
  bool errorInCollectedLetters = false;
  late Ticker ticker;
  int score = 0;
  int timeLeft = 30;
  Timer? _clearTimer;
  Timer? _fadeTimer;
  Timer? _errorTimer;
  Timer? _successTimer;
  final List<String> collectedLetters = [];
  bool ambiguousMatch = false; // Flag for ambiguous (extended) match.
  bool wordSuccess = false;
  String lastTappedLetter = '';
  double letterOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer(); // initialize audio player for this screen
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
      // Play sound effect for new bubble appearance.
      // (You may want to adjust so it doesn't play too often.)
      // Uncomment the next line if desired:
      final result = _audioPlayer.play(AssetSource('assets/bubble_sound.ogg'));
      print(result);
       //_audioPlayer.play(AssetSource('assets/bubble_sound.ogg'));
    }
  }
  
  void _onBubbleTap(Bubble bubble) {
    // 1) Generate a unique key for this explosion:
  final expKey = UniqueKey();

  // 2) Create the explosion, referring only to expKey in onComplete:
  final explosion = _BubbleExplosion(
    key: expKey,
    x: bubble.x + 25,  // center of a 50×50 bubble
    y: bubble.y + 25,
    letter: bubble.letter,
    onComplete: () {
      // when the animation completes, remove by matching key
      setState(() {
        _explosions.removeWhere((e) => e.key == expKey);
      });
    },
  );

    setState(() {
      
      collectedLetters.add(bubble.letter);
      lastTappedLetter = bubble.letter;
      letterOpacity = 1.0;
      bubble.toBeRemoved = true;
      _explosions.add(explosion);
      ambiguousMatch = false; // Reset ambiguous flag.
      _checkForWords();
    });
    // Play tap sound.
    // (Assuming you have a tap sound asset.)
    _audioPlayer.play(AssetSource('assets/success-letter.ogg'));
    
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
      // Play bad letter sound.
      _audioPlayer.play(AssetSource('assets/bad-letter.ogg'));
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
  
    if (globalWordChecker.isValidWord(wordToCheck)) {
      // Check for ambiguous longer matches.
      final longerMatches = globalWordChecker.dictionary
          .where((w) => w.startsWith(wordToCheck) && w.length > wordToCheck.length)
          .toList();
      if (longerMatches.isNotEmpty) {
        // Ambiguous case: current word is valid but can be extended.
        setState(() {
          ambiguousMatch = true;
        });
        // Do not trigger success until user taps the ambiguous check.
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
  
  // Called when user taps the ambiguous check button.
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
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                        offset: Offset(3, 3),
                      ),
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
      timeLeft = 30;
      collectedLetters.clear();
      bubbles.clear();
      lastTappedLetter = '';
      letterOpacity = 0.0;
    });
    ticker.start();
    _startTimer();
  }
  
  // Build widget to show collected letters with ambiguous check button.
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
        if (ambiguousMatch) ...[
          SizedBox(width: 8),
          GestureDetector(
            onTap: _acceptAmbiguousWord,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color.fromARGB(255, 247, 84, 220),
                  width: 3,
                ),
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
        clipBehavior: Clip.hardEdge, // any overflow is clipped
        children: [
          // Background.
          // Container(
          //   color: const Color.fromARGB(255, 237, 240, 219),
            Positioned.fill(
              child: Image.asset(
                'assets/canyon_river_background.png',
                fit: BoxFit.cover,   // preserves aspect ratio & fills, cropping as needed
              ),
            ),

          //),
          // Top info panel (time, score, etc.).
          // If GameUI displays collectedLetters, consider removing that portion from GameUI.
          GameUI(
            score: score,
            timeLeft: timeLeft,
            collectedLetters: collectedLetters, // You can remove this parameter if GameUI is modified.
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
              ..._explosions,
          // Optional: Big single letter fade on the right (remove if redundant).
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

//// Spawns a quick “letter shatter” at (x,y).
class _BubbleExplosion extends StatefulWidget {
  final double x, y;
  final String letter;
  final VoidCallback onComplete;
  const _BubbleExplosion({
    super.key,
    required this.x,
    required this.y,
    required this.letter,
    required this.onComplete,
  }) 

  @override
  __BubbleExplosionState createState() => __BubbleExplosionState();
}

class __BubbleExplosionState extends State<_BubbleExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Offset> _pieces;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    // 16 fragments, offsets up to ±60px
    _pieces = List.generate(
      16,
      (_) => Offset(
        _rng.nextDouble() * 120 - 60,
        _rng.nextDouble() * 120 - 60,
      ),
    );
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      })
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(_ctrl.value);
    return Positioned(
      left: widget.x - 20,
      top: widget.y - 20,
      child: CustomPaint(
        size: Size(40, 40),
        painter: _ExplosionPainter(_pieces, t, widget.letter, _ctrl.value),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class _ExplosionPainter extends CustomPainter {
  final List<Offset> pieces;
  final double t, progress;
  final String letter;

  _ExplosionPainter(this.pieces, this.t, this.letter, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // draw flying letter fragments in white fading 50%→0%
    final textStyle = TextStyle(
      fontSize: 14,
      fontFamily: 'Arco',
      color: Colors.white.withOpacity((1 - progress) * 0.5),
    );

    for (var offset in pieces) {
      final pos = center + offset * t;
      final tp = TextPainter(
        text: TextSpan(text: letter, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter old) => true;
}