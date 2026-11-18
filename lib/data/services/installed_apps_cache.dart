
import 'package:flutter/foundation.dart';

import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';

/// One app-wide list of installed apps, shared by every screen.
///
/// Names load once (fast, no icons). Icons are fetched only for the packages a
/// screen asks for and kept for the session. On resume only changed packages
/// are refreshed. See `docs/installed-apps-cache.md`.
class InstalledAppsCache extends ChangeNotifier {
  InstalledAppsCache._();

  static final InstalledAppsCache instance = InstalledAppsCache._();

  NotificationPlatformInterface get _platform =>
      PlatformFactory.createPlatformService();

  List<DiscoveredAppInfo> _apps = const [];
  Map<String, DiscoveredAppInfo> _byPackage = const {};
  final Map<String, Uint8List> _icons = {};
  final Set<String> _noIcon = {};
  final Set<String> _iconsInFlight = {};
  final Map<String, bool> _installed = {};
  Future<void>? _loading;
  bool _loaded = false;
  int? _sequenceNumber;

  /// Whether the app list has finished loading at least once.
  bool get isLoaded => _loaded;

  /// Installed launcher apps sorted by name. Icons are not included; use [iconFor].
  List<DiscoveredAppInfo> get apps => _apps;

  DiscoveredAppInfo? appFor(String packageName) => _byPackage[packageName];

  Uint8List? iconFor(String packageName) => _icons[packageName];

  /// True only when the package is known to be uninstalled. Unknown counts as installed,
  /// so nothing is greyed out before the list has loaded.
  bool isUninstalled(String packageName) =>
      _loaded && _installed[packageName] == false;

  /// Loads the app list once; later calls reuse the same load.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final platform = _platform;
      _setApps(await platform.getInstalledAppsLite());
      _sequenceNumber = (await platform.getChangedPackages(0))?.sequenceNumber;
    } catch (_) {
      // Leave the list empty; screens fall back to stored names and icons.
    }
    _loaded = true;
    notifyListeners();
  }

  void _setApps(List<DiscoveredAppInfo> apps) {
    _apps = List.unmodifiable(apps);
    _byPackage = {for (final a in apps) a.packageName: a};
    for (final a in apps) {
      _installed[a.packageName] = true;
      final icon = a.iconBytes;
      if (icon != null) _icons[a.packageName] = icon;
    }
  }

  /// Updates only the packages installed, updated or removed since the last check.
  Future<void> refreshChanges() async {
    if (!_loaded) return ensureLoaded();
    final sequence = _sequenceNumber;
    if (sequence == null) return;
    final platform = _platform;
    final changes = await platform.getChangedPackages(sequence);
    if (changes == null) return;
    _sequenceNumber = changes.sequenceNumber;
    if (changes.packageNames.isEmpty) return;
    for (final pkg in changes.packageNames) {
      _icons.remove(pkg);
      _noIcon.remove(pkg);
      _installed.remove(pkg);
    }
    _setApps(await platform.getInstalledAppsLite());
    final status = await platform.getInstalledStatus(changes.packageNames);
    _installed.addAll(status);
    notifyListeners();
  }

  /// Fetches icons for [packageNames] that are not loaded yet.
  Future<void> loadIcons(Iterable<String> packageNames) async {
    final missing = packageNames
        .where((p) =>
            !_icons.containsKey(p) &&
            !_noIcon.contains(p) &&
            !_iconsInFlight.contains(p))
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    _iconsInFlight.addAll(missing);
    try {
      final icons = await _platform.getAppIcons(missing);
      _icons.addAll(icons);
      _noIcon.addAll(missing.where((p) => !icons.containsKey(p)));
      if (icons.isNotEmpty) notifyListeners();
    } catch (_) {
      // Placeholders stay; a later request retries.
    } finally {
      _iconsInFlight.removeAll(missing);
    }
  }

  /// Asks the platform whether each package is still installed. Packages already
  /// in the launcher list are known to be installed and are skipped unless [force].
  Future<void> checkInstalled(Iterable<String> packageNames,
      {bool force = false}) async {
    await ensureLoaded();
    final toCheck = packageNames
        .where((p) =>
            force || (!_byPackage.containsKey(p) && !_installed.containsKey(p)))
        .toSet()
        .toList();
    if (toCheck.isEmpty) return;
    final status = await _platform.getInstalledStatus(toCheck);
    var changed = false;
    for (final e in status.entries) {
      if (_installed[e.key] != e.value) {
        _installed[e.key] = e.value;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Clears everything in place (listeners are kept). Used by tests.
  void resetForTest() {
    _apps = const [];
    _byPackage = const {};
    _icons.clear();
    _noIcon.clear();
    _iconsInFlight.clear();
    _installed.clear();
    _loading = null;
    _loaded = false;
    _sequenceNumber = null;
  }
}
