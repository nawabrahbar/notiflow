import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/main.dart';

void main() {
  test('phones are locked to portrait', () {
    expect(allowedOrientations(390), [DeviceOrientation.portraitUp]);
  });

  test('tablets can rotate', () {
    expect(allowedOrientations(800), DeviceOrientation.values);
  });
}
