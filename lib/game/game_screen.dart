// lib/game_screen.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:ui';
import 'bubble.dart';
import 'word_checker.dart';
import 'game_ui.dart';

////////////////////////////////////////////////////////////////////////
// WORD CHECKER (unchanged for your dictionary CSV logic, if any)
////////////////////////////////////////////////////////////////////////
final WordChecker globalWordChecker = WordChecker();



////////////////////////////////////////////////////////////////////////
// SOAP BUBBLE MODEL (unchanged)
////////////////////////////////////////////////////////////////////////
class SoapBubble {
  double initialX;    // horizontal center for oscillation
  double x;
  double y;
  double radius;
  double speed;       // vertical speed (px/s)
  double phase;       // phase offset for sine-wave
  double amplitude;   // horizontal oscillation amplitude

  SoapBubble({
    required this.initialX,
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.amplitude,
  });
}
////////////////////////////////////////////////////////////////////////
// WELCOME SCREEN WITH SOAP BUBBLES + MUTE/UNMUTE
////////////////////////////////////////////////////////////////////////

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isMuted = true;

  late Ticker _ticker;
  final List<SoapBubble> _bubbles = [];
  final Random _rng = Random();
  double _screenWidth = 0;
  double _screenHeight = 0;

  @override
  void initState() {
    super.initState();

    // 1) Audio setup (loop), but do NOT auto-play until user taps icon.
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    // 2) Start a Ticker to advance bubble positions ~60FPS.
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_isPlaying) {
      _audioPlayer.stop().catchError((_) {});
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Populate exactly 12 soap bubbles. Requires _screenWidth/_screenHeight > 0.
  void _initializeBubbles() {
    for (int i = 0; i < 12; i++) {
      _bubbles.add(_createNewBubble());
    }
  }

  /// Create a single SoapBubble starting well below the bottom.
  SoapBubble _createNewBubble() {
    // - Random horizontal “center” across full width
    final double initialX = _rng.nextDouble() * _screenWidth;
    // - Start Y = screenHeight + [0..screenHeight], so definitely off-screen
    final double startY = _screenHeight + 50 + _rng.nextDouble() * _screenHeight;
    // - Radius between 40..80 px
    final double radius = 40 + _rng.nextDouble() * 40;
    // - Vertical speed: 100..180 px/s (rise speed)
    final double speed = 100 + _rng.nextDouble() * 80;
    // - Random sine‐wave phase
    final double phase = _rng.nextDouble() * 2 * pi;
    // - Horizontal oscillation ±(20..50) px
    final double amplitude = 20 + _rng.nextDouble() * 30;

    return SoapBubble(
      initialX: initialX,
      x: initialX,
      y: startY,
      radius: radius,
      speed: speed,
      phase: phase,
      amplitude: amplitude,
    );
  }

  /// Called ~60×/second by the Ticker. Move each bubble upward & zig-zag.
  void _onTick(Duration elapsed) {
    const double dt = 1 / 60; // seconds per tick

    for (int i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];

      // Move upward by speed * dt
      b.y -= b.speed * dt;

      // Horizontal zig-zag: one full sine oscillation ≈ every 200 px vertical
      const double freq = 2 * pi / 200;
      b.x = b.initialX + b.amplitude * sin(freq * b.y + b.phase);

      // If bubble is completely off the top, respawn it below again
      if (b.y + b.radius < 0) {
        _bubbles[i] = _createNewBubble();
      }
    }

    // Rebuild to show updated positions
    setState(() {});
  }

  /// Toggle mute/unmute, starting or stopping the looped “welcome-melody.ogg”
  void _toggleMute() {
    if (_isMuted) {
      _audioPlayer
          .play(AssetSource('welcome-melody.ogg'))
          .catchError((_) {});
      setState(() {
        _isPlaying = true;
        _isMuted = false;
      });
    } else {
      _audioPlayer.stop().catchError((_) {});
      setState(() {
        _isPlaying = false;
        _isMuted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) Get current screen size from MediaQuery
    final size = MediaQuery.of(context).size;
    if (size.width > 0 && size.height > 0) {
      // If width/height just became non-zero & bubbles not yet initialized:
      if (_screenWidth == 0 && _screenHeight == 0) {
        _screenWidth = size.width;
        _screenHeight = size.height;
        _initializeBubbles();
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Audio is only toggled via the icon, not by tapping anywhere else.
      child: Scaffold(
        body: Stack(
          children: [
            // 1) Fullscreen background
            Positioned.fill(
              child: Image.asset(
                'assets/baby-background.png',
                fit: BoxFit.cover,
              ),
            ),

            // 2) Draw each soap bubble (fish-eye + dimming)
            for (var b in _bubbles)
              Positioned(
                left: b.x - b.radius,
                top: b.y - b.radius,
                child: ClipOval(
                  child: SizedBox(
                    width: b.radius * 2,
                    height: b.radius * 2,
                    child: Stack(
                      children: [
                        // a) Fish-eye transform:
                        Transform(
                          transform: Matrix4.identity()
                            ..translate(b.radius, b.radius)
                            ..scale(1.2, 1.2)             // zoom factor
                            ..translate(-b.x, -b.y),
                          child: Image.asset(
                            'assets/baby-background.png',
                            width: _screenWidth,
                            height: _screenHeight,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // b) Dim the bubble interior by overlaying 30%-black
                        Container(
                          width: b.radius * 2,
                          height: b.radius * 2,
                          color: Colors.black.withValues(alpha:0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 3) “Are you want to play?” + YES/NO buttons at ~1/3 down
            Align(
              alignment: Alignment(0, -0.53),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.black54,
                    padding:
                        EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Text(
                      'Are you want to play?',
                      style: TextStyle(
                        fontSize: 28,
                        color: const Color.fromARGB(255, 245, 188, 3),
                        fontFamily: 'Arco',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Stop the melody if playing
                          if (_isPlaying) {
                            _audioPlayer.stop().catchError((_) {});
                          }
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => SplashScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Arco',
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      ElevatedButton(
                        onPressed: () {
                          if (_isPlaying) {
                            _audioPlayer.stop().catchError((_) {});
                          }
                          SystemNavigator.pop();
                        },
                        child: Text(
                          'NO',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Arco',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4) Mute/Speaker icon in top-right
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                iconSize: 32,
                color: const Color.fromARGB(255, 3, 233, 3),
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                ),
                onPressed: _toggleMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
///////////////////////////////////////////////////////////////////////
// SPARK MODEL (for logo sparkles)
////////////////////////////////////////////////////////////////////////
class _Spark {
  /// Relative position in [0..1] × [0..1] over the 150×150 logo.
  final double rx, ry;
  /// UniqueKey used to track its AnimationController.
  final UniqueKey key;

  _Spark({ required this.rx, required this.ry }) : key = UniqueKey();
}

////////////////////////////////////////////////////////////////////////
// SMALL “SODA” BUBBLE MODEL (unchanged from before)
////////////////////////////////////////////////////////////////////////
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

////////////////////////////////////////////////////////////////////////
// SPLASH SCREEN WITH SPARKS + SODA BUBBLES + RANDOM SOUNDS
////////////////////////////////////////////////////////////////////////

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation for top‐to‐bottom reveal
  late AnimationController _controller;
  late Animation<double> _animation;

  // “Soda” bubbles
  late Ticker _bubbleTicker;
  final Random rng = Random();
  final List<SplashSmallBubble> sodaBubbles = [];
  late AudioPlayer _audioPlayer;
  final List<String> bubbleSounds = [
    'bubble_sound.ogg',
    'bubble_sound-2.ogg',
    'bubble_sound-3.ogg',
  ];
  double _timeAccumulator = 0.0;
  double _nextSoundDelay = 2.0;
  bool _audioAllowed = false;

  // Sparks over the Webaby logo
  late Ticker _sparkTicker;
  final List<_Spark> _sparks = [];
  final Map<UniqueKey, AnimationController> _sparkControllers = {};

  @override
  void initState() {
    super.initState();

    // 1) Audio setup (loop) for splash sounds; do not auto-play
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    // 2) Load dictionary
    _initGame();

    // 3) Top-to-bottom reveal animation
    _controller = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    Future.delayed(Duration(seconds: 2), () {
      _controller.forward().then((_) {
        _audioPlayer.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => BubbleWordGame()),
        );
      });
    });

    // 4) Initialize soda bubbles
    _initSodaBubbles();

    // 5) Ticker to update soda bubbles & random sounds
    DateTime? lastUpdate;
    _bubbleTicker = createTicker((now) {
      final current = DateTime.now();
      if (lastUpdate == null) {
        lastUpdate = current;
        return;
      }
      final dtSeconds = current.difference(lastUpdate!).inMicroseconds / 1e6;
      lastUpdate = current;
      setState(() {
        _updateSodaBubbles();
      });
      _handleRandomSounds(dtSeconds);
    });
    _bubbleTicker.start();

    // 6) Ticker to spawn & fade sparks
    _sparkTicker = createTicker((_) {
      // a) 15% chance per tick to spawn a new spark
      if (rng.nextDouble() < 0.15) {
        _spawnSpark();
      }
      // b) Remove any finished sparks
      final finished = _sparkControllers.entries
          .where((e) => e.value.status == AnimationStatus.completed)
          .map((e) => e.key)
          .toList();
      for (var key in finished) {
        _sparkControllers[key]?.dispose();
        _sparkControllers.remove(key);
        _sparks.removeWhere((s) => s.key == key);
      }
      setState(() {});
    });
    _sparkTicker.start();
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
            .withValues(alpha:rng.nextDouble() * 0.5 + 0.4),
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
            .withValues(alpha:rng.nextDouble() * 0.5 + 0.4);
        if (_audioAllowed) {
          _audioPlayer
              .play(AssetSource('success-word.ogg'))
              .catchError((_) {});
        }
      }
    }
  }

  void _handleRandomSounds(double dt) {
    _timeAccumulator += dt;
    if (_timeAccumulator >= _nextSoundDelay) {
      final soundPath = bubbleSounds[rng.nextInt(bubbleSounds.length)];
      if (_audioAllowed) {
        _audioPlayer.play(AssetSource(soundPath)).catchError((_) {});
      }
      _timeAccumulator = 0.0;
      _nextSoundDelay = 0.5 + rng.nextDouble() * 1.5;
    }
  }

  /// Spawn a single spark at a random relative position (rx,ry) inside 150×150 logo,
  /// then animate its opacity from 1→0 over 300ms.
  void _spawnSpark() {
    final double rx = rng.nextDouble();
    final double ry = rng.nextDouble();
    final spark = _Spark(rx: rx, ry: ry);
    _sparks.add(spark);

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )
      ..addListener(() => setState(() {}))
      ..forward();

    _sparkControllers[spark.key] = controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    _bubbleTicker.dispose();
    for (var ctrl in _sparkControllers.values) {
      ctrl.dispose();
    }
    _sparkControllers.clear();
    _sparkTicker.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleAudioAllowed() {
    if (!_audioAllowed) {
      _audioAllowed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleAudioAllowed,
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 6, 17, 22),
        body: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return FractionallySizedBox(
              alignment: Alignment.topCenter,
              heightFactor: _animation.value,
              child: Container(
                color: const Color.fromARGB(255, 6, 17, 22),
                child: Stack(
                  children: [
                    // 1) Background image
                    Positioned.fill(
                      child: Image.asset(
                        'assets/treeCoast.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    // 2) Center column: "Webaby presents" + logo + ad
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
                          const SizedBox(height: 20),

                          // ─── Webaby logo with spark overlay ───
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: Stack(
                              children: [
                                // a) The static logo
                                Image.asset(
                                  'assets/webaby-logo.png',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                                // b) Overlay each spark circle
                                for (var spark in _sparks)
                                  Positioned(
                                    left: spark.rx * 150 - 8,
                                    top:  spark.ry * 150 - 8,
                                    child: Opacity(
                                      opacity: 1.0 -
                                          (_sparkControllers[spark.key]?.value ?? 0.0),
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.yellow.withOpacity(0.9),
                                              Colors.orange.withOpacity(0.6),
                                              Colors.transparent,
                                            ],
                                            stops: [0.0, 0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          Image.asset(
                            'assets/webaby-bubble-ad.png',
                            width: 300,
                            height: 200,
                          ),
                        ],
                      ),
                    ),

                    // 3) “Soda” bubbles floating
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
      ),
    );
  }
}
////////////////////////////////////////////////////////////////////////
// BUBBLE WORD GAME WITH PHYSICS AND LEVEL PROGRESSION
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
      if (!mounted) return;
      setState(() => isVisible = !isVisible);
      _startFlashing();
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
  // physics-enabled bubbles
  final List<Bubble> bubbles = [];
  final BubbleGenerator _bubbleGenerator = BubbleGenerator();

  // explosion effects
  final List<_BubbleExplosion> _explosions = [];

  // game state & assets
  late AudioPlayer _audioPlayer;
  late Ticker ticker;
  final Random random = Random();
  int score = 0;
  int timeLeft = 30;
  final List<String> collectedLetters = [];
  bool errorInCollectedLetters = false;
  bool ambiguousMatch = false;
  bool wordSuccess = false;
  String lastTappedLetter = '';
  double letterOpacity = 0.0;
  Timer? _errorTimer, _fadeTimer, _successTimer, _clearTimer;

  // screen dimensions for physics
  late double _screenWidth, _screenHeight;

  // --- NEW: track whether user has tapped at least once ---
  bool _audioAllowed = false;

  // --- NEW: level progression variables ---
  int currentLevel = 1;
  bool isLevelTransition = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    ticker = createTicker((_) => setState(_updateBubbles));
    ticker.start();
    _startTimer();
    globalWordChecker.loadDictionary().then((_) {
      print("Dictionary loaded");
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    _errorTimer?.cancel();
    _fadeTimer?.cancel();
    _successTimer?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    Timer(Duration(seconds: 1), () {
      if (!mounted) return;
      if (timeLeft == 0) {
        ticker.stop();
        _showGameOverDialog();
      } else {
        setState(() => timeLeft--);
        _startTimer();
      }
    });
  }

  void _updateBubbles() {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;

    // 1) Move & wall‐bounce
    for (var b in bubbles) {
      b.x += b.vx;
      b.y += b.vy;

      // left/right walls
      if (b.x - b.radius < 0) {
        b.x = b.radius;
        b.vx = -b.vx;
      } else if (b.x + b.radius > _screenWidth) {
        b.x = _screenWidth - b.radius;
        b.vx = -b.vx;
      }

      // REMOVED top bounce: bubbles now just fly off-screen above

      // remove if below bottom
      if (b.y - b.radius > _screenHeight) {
        b.toBeRemoved = true;
      }
    }

    // 2) Bubble‐to‐bubble collisions
    for (int i = 0; i < bubbles.length; i++) {
      for (int j = i + 1; j < bubbles.length; j++) {
        _resolveCollision(bubbles[i], bubbles[j]);
      }
    }

    // 3) Cleanup off-screen
    bubbles.removeWhere((b) => b.toBeRemoved);

    // 4) Spawn new bubble
    if (random.nextDouble() < 0.05) {
      bubbles.add(_bubbleGenerator.generateBubble(_screenWidth, _screenHeight));
      if (_audioAllowed) {
        _audioPlayer
            .play(AssetSource('bubble_sound.ogg'))
            .catchError((_) {});
      }
    }
  }

  void _resolveCollision(Bubble b1, Bubble b2) {
    final dx = b2.x - b1.x;
    final dy = b2.y - b1.y;
    final dist = sqrt(dx * dx + dy * dy);
    final minDist = b1.radius + b2.radius;
    if (dist >= minDist || dist == 0) return;

    // push apart
    final overlap = 0.5 * (minDist - dist + 0.1);
    final nx = dx / dist;
    final ny = dy / dist;
    b1.x -= overlap * nx;
    b1.y -= overlap * ny;
    b2.x += overlap * nx;
    b2.y += overlap * ny;

    // elastic collision (equal mass)
    final dvx = b1.vx - b2.vx;
    final dvy = b1.vy - b2.vy;
    final relVel = dvx * nx + dvy * ny;
    if (relVel > 0) return;
    final impulse = -2 * relVel / 2;
    b1.vx += impulse * nx;
    b1.vy += impulse * ny;
    b2.vx -= impulse * nx;
    b2.vy -= impulse * ny;
  }

  void _onBubbleTap(Bubble bubble) {
    final expKey = UniqueKey();
    final explosion = _BubbleExplosion(
      key: expKey,
      x: bubble.x + bubble.radius,
      y: bubble.y + bubble.radius,
      letter: bubble.letter,
      onComplete: () {
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
      ambiguousMatch = false;
      _checkForWords();
    });
    if (_audioAllowed) {
      _audioPlayer
          .play(AssetSource('success-word.ogg'))
          .catchError((_) {});
    }
    _fadeTimer = Timer(Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => letterOpacity = 0.0);
    });
  }

  void _checkForWords() {
    if (collectedLetters.isEmpty) return;
    final word = collectedLetters.join().toUpperCase();
    if (!globalWordChecker.startsAnyWord(word)) {
      if (_audioAllowed) {
        _audioPlayer
            .play(AssetSource('bubble_sound-3.ogg'))
            .catchError((_) {});
      }
      setState(() => errorInCollectedLetters = true);
      _errorTimer = Timer(Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          collectedLetters.clear();
          errorInCollectedLetters = false;
        });
      });
      return;
    }
    if (globalWordChecker.isValidWord(word)) {
      final longer = globalWordChecker.dictionary
          .where((w) => w.startsWith(word) && w.length > word.length)
          .toList();
      if (longer.isNotEmpty) {
        setState(() => ambiguousMatch = true);
        return;
      }
      _acceptWord(word);
    }
  }

  void _acceptAmbiguousWord() {
    final word = collectedLetters.join().toUpperCase();
    _acceptWord(word);
  }

  void _acceptWord(String word) {
    setState(() {
      score += word.length * 10;
      wordSuccess = true;
      ambiguousMatch = false;
    });

    // --- UPDATED _checkLevelUp() to trigger on every 50-point multiple ---
    _checkLevelUp();

    _triggerSuccessAnimation();
    _successTimer = Timer(Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        collectedLetters.clear();
        wordSuccess = false;
      });
    });
  }

  void _checkLevelUp() {
    // If score has reached or exceeded currentLevel * 50, advance one level
    if (score >= currentLevel * 50) {
        setState(() {
        isLevelTransition = true;
        currentLevel += 1;

        // play the “level up” sound
        if (_audioAllowed) {
          _audioPlayer
            .play(AssetSource('success-letter.ogg'))
            .catchError((_) {});
        }

        // give the 10-point bonus
        score += 10;
        // reset timer to starting value
        timeLeft = 30;
      });
      ticker.stop();
      Timer(Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          isLevelTransition = false;
        });
        ticker.start();
      });
    }
  }

  void _triggerSuccessAnimation() {
    if (_audioAllowed && timeLeft > 0) {
  _audioPlayer
    .play(AssetSource('word-completed.ogg'))
    .catchError((_) {});
}

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
              color: Colors.green.withValues(alpha:0.7),
            ),
            child: Center(
              child: Text(
                'BOOM! $score',
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontFamily: 'Arco',
                  decoration: TextDecoration.none,
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
                    decoration: TextDecoration.none, // no underline
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
                    color: Color.fromARGB(255, 134, 123, 22),
                    fontFamily: 'Arco',
                    decoration: TextDecoration.none, // no underline
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
      currentLevel = 1;
      isLevelTransition = false;
    });
    ticker.start();
    _startTimer();
  }

  Widget _buildCollectedLetters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          collectedLetters.join(" "),
          style: TextStyle(
            fontSize: 28,
            color: errorInCollectedLetters ? Colors.red : Colors.white.withValues(alpha:1),
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
                  color: Color.fromARGB(255, 247, 84, 220),
                  width: 3,
                ),
              ),
              child: Icon(Icons.check, color: Colors.white.withValues(alpha:1), size: 20),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire game UI in a GestureDetector so the first tap unlocks audio.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_audioAllowed) {
          _audioAllowed = true;
          // OPTIONAL: play a silent asset to fully unlock.
          // _audioPlayer.play(AssetSource('silence.mp3')).catchError((_) {});
        }
      },
      child: Scaffold(
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background changes per level:
            Positioned.fill(
              child: Image.asset(
                currentLevel == 1
                    ? 'assets/canyon_river_background.png'
                    : 'assets/treeCoast-level-$currentLevel.png',
                fit: BoxFit.cover,
              ),
            ),

            // Overlay “Level X” during transition:
            if (isLevelTransition)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      'Level $currentLevel',
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.white.withValues(alpha:0.7),
                        fontFamily: 'Arco',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            GameUI(
              score: score,
              timeLeft: timeLeft,
              collectedLetters: collectedLetters,
              wordSuccess: wordSuccess,
            ),
            ...bubbles.map((b) => Positioned(
                  left: b.x - b.radius,
                  top: b.y - b.radius,
                  child: GestureDetector(
                    onTap: () => _onBubbleTap(b),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/bubble-4.png',
                          width: b.radius * 2,
                          height: b.radius * 2,
                        ),
                        Text(
                          b.letter,
                          style: TextStyle(
                            fontSize: 24,
                            color: Color.fromARGB(255, 72, 23, 100),
                            fontFamily: 'Arco',
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            ..._explosions,
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
                    fontFamily: 'Arco',
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                child: Center(child: _buildCollectedLetters()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  });

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
    _pieces = List.generate(
      16,
      (_) => Offset(_rng.nextDouble() * 120 - 60, _rng.nextDouble() * 120 - 60),
    );
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
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
    final textStyle = TextStyle(
      fontSize: 14,
      fontFamily: 'Arco',
      color: Colors.white.withValues(alpha:(((1 - progress) * 0.5))),
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


// ENTRY POINT

void main() {

  runApp(MaterialApp(

    debugShowCheckedModeBanner: false,

    home: WelcomeScreen(),

  ));

}

