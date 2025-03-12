class WordChecker {
  // A sample dictionary of valid words
  final Set<String> dictionary = {
    "CAT", "DOG", "BAT", "HAT", "MAT", "RAT", "SUN", "FUN", "RUN", "CAR"
  };

  bool isValidWord(String word) {
    return dictionary.contains(word.toUpperCase());
  }
}