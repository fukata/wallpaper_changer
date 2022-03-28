
import 'package:flutter_test/flutter_test.dart';
import 'package:wallpaper_changer/helpers/TimerUtil.dart';

void main() {
  group("convertDurationToSeconds", () {
    test("return 0 if input invalid format", () {
      expect(convertDurationToSeconds("dummy"), 0);
    });
    test("return 60 seconds if input 60s", () {
      expect(convertDurationToSeconds("60s"), 60);
    });
    test("return 600 seconds if input 10m", () {
      expect(convertDurationToSeconds("10m"), 600);
    });
    test("return 7200 seconds if input 2h", () {
      expect(convertDurationToSeconds("2h"), 7200);
    });
    test("return 86400 seconds if input 1d", () {
      expect(convertDurationToSeconds("1d"), 86400);
    });
  });
}