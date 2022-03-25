final reDuration = RegExp(r'([0-9]+)(s|m|h|d)');

/// 10mなどの値を秒数に変換して返す。
///
/// @param duration 10s, 10m, 1h, 1d
/// @result 秒数
int convertDurationToSeconds(String duration) {
  final match = reDuration.firstMatch(duration);
  if (match == null) {
    return 0;
  }

  int result = 0;

  final number = int.parse(match.group(1)!);
  final period = match.group(2)!;

  switch(period) {
    case "s":
      result = number;
      break;
    case "m":
      result = number * Duration.secondsPerMinute;
      break;
    case "h":
      result = number * Duration.secondsPerHour;
      break;
    case "d":
      result = number * Duration.secondsPerDay;
      break;
  }

  return result;
}