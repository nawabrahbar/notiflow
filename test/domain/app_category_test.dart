import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/domain/engine/app_category.dart';
import 'package:notification_handler/platform/notification_platform_interface.dart';

DiscoveredAppInfo _app(
  String name,
  String pkg, {
  bool system = false,
  int category = -1,
}) =>
    DiscoveredAppInfo(
      packageName: pkg,
      displayName: name,
      isSystemApp: system,
      androidCategory: category,
    );

void main() {
  test('unmatched user apps are "other", not "system"', () {
    expect(appCategoryFor(_app('8 Ball Pool', 'com.miniclip.eightballpool')), 'other');
    expect(appCategoryFor(_app('AJIO', 'com.ril.ajio')), 'other');
  });

  test('only apps flagged as system by Android land in "system"', () {
    expect(appCategoryFor(_app('Airtel Alert', 'com.oneplus.airtel', system: true)), 'system');
  });

  test('preinstalled apps with a known category keep that category', () {
    expect(appCategoryFor(_app('Gmail', 'com.google.android.gm', system: true)), 'productivity');
    expect(appCategoryFor(_app('Messages', 'com.google.android.apps.messaging', system: true)), 'messaging');
  });

  test("Android's own category is used when keywords don't match", () {
    expect(appCategoryFor(_app('Threads', 'com.instagram.barcelona', category: 4)), 'social');
    expect(appCategoryFor(_app('Docs', 'com.google.android.apps.docs', category: 7)), 'productivity');
    expect(appCategoryFor(_app('Lens', 'com.example.lens', category: 4)), 'social');
  });

  test('messaging keywords win over Android social category', () {
    expect(appCategoryFor(_app('WhatsApp', 'com.whatsapp', category: 4)), 'messaging');
  });
}
