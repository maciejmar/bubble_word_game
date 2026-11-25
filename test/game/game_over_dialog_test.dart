import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bubble_word_game/game/game_screen.dart';

void main() {
  testWidgets('shows final score before game-over actions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BubbleGameScreen()));
    await tester.pump(const Duration(seconds: 31));

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('FINAL SCORE: 0'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsNothing);
    expect(find.text('QUIT'), findsNothing);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('QUIT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
