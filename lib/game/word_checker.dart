import 'package:flutter/services.dart' show rootBundle;

class WordChecker {
  final Set<String> dictionary = <String>{};

  Future<void> loadDictionary() async {
  final rawData = await rootBundle.loadString('assets/english_dict/eng.csv');
  final lines = rawData.split(RegExp(r'\r?\n'));
  for (var line in lines) {
    final word = line.trim();
    if (word.isNotEmpty) {
      dictionary.add(word.toUpperCase());
    }
  }
  print("DEBUG: WordChecker loaded ${dictionary.length} words from CSV");
  // Print a sample of words:
  print("DEBUG: Sample words: ${dictionary.take(20).toList()}");
  // Debug: List all words starting with 'C'
  final cWords = dictionary.where((w) => w.startsWith("C")).toList();
  print("DEBUG: Words list long list starting with 'C': $cWords");
}
  bool isValidWord(String word) {
    return dictionary.contains(word.toUpperCase());
  }

  /// Add this method so that "_checkForWords()" can call `startsAnyWord`
 bool startsAnyWord(String partial) {
  final up = partial.toUpperCase();
  final matches = dictionary.where((entry) => entry.startsWith(up)).toList();
  print("DEBUG: Looking for words starting with '$up', found ${matches.length} matches: $matches");
  return matches.isNotEmpty;
 }
}