int tangledScore(int a, int b, int c) {
  var score = 0;
  if (a > 0) {
    if (b > 0) {
      if (c > 0) {
        if (a > b) {
          if (b > c) {
            score = a + b + c;
          }
        }
      }
    }
  }
  return score;
}
