String convertDuration(Duration input) {
  if (input.inHours > 0) {
    return input.toString().split('.')[0];
  }
  return input.toString().split('.')[0].substring(2);
}