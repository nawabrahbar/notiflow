import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/engine/app_category.dart';
import '../../domain/models/managed_app.dart';
import '../../platform/android_notification_platform.dart';
import '../../platform/notification_platform_interface.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import '../widgets/app_toast.dart';
import 'app_details_screen.dart';
import 'schedule_editor_screen.dart';

/// Add Apps screen adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive: Single column on phone (< 600dp), 2-Column Responsive Card Grid on tablet (>= 600dp)
/// - Live search bar & category filter chips (ALL APPS, MESSAGING, SOCIAL, PRODUCTIVITY, SYSTEM)
/// - Real native app icons from PackageManager
/// - Quick "Add Rule" or "Configured" indicator
class AddAppsScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isEmbedded;
  final bool historyManagement;

  const AddAppsScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
    this.historyManagement = false,
  });

  @visibleForTesting
  static void clearInstalledAppsCache() =>
      InstalledAppsCache.instance.resetForTest();

  @override
  State<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends State<AddAppsScreen> {
  final Set<String> _busyPackages = {};
  // Space kept free at the end of the list so the last app can scroll
  // fully above the floating search bar.
  static const double _searchBarReserve = 72;

  // Fast scrolls (pixels per frame) skip icon fetching for rows flying past.
  static const double _flingDelta = 60;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final InstalledAppsCache _cache = InstalledAppsCache.instance;
  String _selectedCategory = 'all';

  // Icon batching: icons are requested for [_iconStart, _iconEnd) of the
  // filtered list, about two screens at a time. See docs/installed-apps-cache.md.
  List<DiscoveredAppInfo> _shownApps = const [];
  String _shownKey = '';
  int _iconStart = 0;
  int _iconEnd = 0;
  double _viewportHeight = 0;
  bool _tabletLayout = false;
  late List<DiscoveredAppInfo> _lastApps;
  late bool _cacheLoaded;
  final Set<String> _pendingIconPackages = {};
  bool _loadingIcons = false;

  @override
  void initState() {
    super.initState();
    _lastApps = _cache.apps;
    _cacheLoaded = _cache.isLoaded;
    _cache.addListener(_onCacheChanged);
    _cache.ensureLoaded();
    _searchController.addListener(() => setState(() {}));
    widget.repository.addListener(_onRepositoryChanged);
  }

  void _onCacheChanged() {
    if (!mounted ||
        (identical(_lastApps, _cache.apps) &&
            _cacheLoaded == _cache.isLoaded)) {
      return;
    }
    setState(() {
      _lastApps = _cache.apps;
      _cacheLoaded = _cache.isLoaded;
    });
  }

  double get _rowExtent => _tabletLayout ? 92 : 80;
  int get _columns => _tabletLayout ? 2 : 1;
  int get _perScreen =>
      math.max(1, (_viewportHeight / _rowExtent).ceil()) * _columns;

  void _requestIcons(int from, int to) {
    final apps = _shownApps;
    if (apps.isEmpty) return;
    final start = from.clamp(0, apps.length);
    final end = to.clamp(start, apps.length);
    if (start >= end) return;
    _iconStart = start;
    _iconEnd = end;
    _pendingIconPackages
      ..clear()
      ..addAll(apps.sublist(start, end).map((a) => a.packageName));
    if (!_loadingIcons) _loadIconBatches();
  }

  Future<void> _loadIconBatches() async {
    _loadingIcons = true;
    try {
      while (mounted && _pendingIconPackages.isNotEmpty) {
        final batch = _pendingIconPackages.take(8).toList();
        _pendingIconPackages.removeAll(batch);
        await _cache.loadIcons(batch);
        if (mounted && _pendingIconPackages.isNotEmpty) {
          await WidgetsBinding.instance.endOfFrame;
        }
      }
    } finally {
      _loadingIcons = false;
    }
  }

  (int, int) _visibleRange(ScrollMetrics m) {
    final first = (m.pixels / _rowExtent).floor() * _columns;
    final last =
        ((m.pixels + m.viewportDimension) / _rowExtent).ceil() * _columns;
    return (math.max(0, first), last);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final (first, last) = _visibleRange(n.metrics);
    if (n is ScrollUpdateNotification) {
      if ((n.scrollDelta ?? 0).abs() > _flingDelta) return false;
      if (last > (_iconStart + _iconEnd) / 2 || first < _iconStart) {
        _requestIcons(first, last + 2 * _perScreen);
      }
    } else if (n is ScrollEndNotification) {
      _requestIcons(first, last + _perScreen);
    }
    return false;
  }

  /// Search, category or list changes restart batching from what is on screen.
  void _syncShownApps(List<DiscoveredAppInfo> apps, String key) {
    _shownApps = apps;
    if (key == _shownKey) return;
    _shownKey = key;
    _iconStart = 0;
    _iconEnd = 0;
    _pendingIconPackages.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || key != _shownKey) return;
      final offset =
          _scrollController.hasClients ? _scrollController.offset : 0.0;
      final first = (offset / _rowExtent).floor() * _columns;
      _requestIcons(first, first + 2 * _perScreen);
    });
  }

  @override
  void didUpdateWidget(covariant AddAppsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      widget.repository.addListener(_onRepositoryChanged);
    }
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _cache.removeListener(_onCacheChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  IconData _getDefaultIconForApp(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chat') ||
        lower.contains('whatsapp') ||
        lower.contains('telegram') ||
        lower.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lower.contains('slack') ||
        lower.contains('team') ||
        lower.contains('meet')) {
      return Icons.workspaces_rounded;
    }
    if (lower.contains('mail') ||
        lower.contains('gmail') ||
        lower.contains('outlook')) {
      return Icons.mail_rounded;
    }
    if (lower.contains('insta') ||
        lower.contains('photo') ||
        lower.contains('camera')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('tweet') ||
        lower.contains('twitter') ||
        lower.contains('x')) {
      return Icons.tag_rounded;
    }
    return Icons.widgets_rounded;
  }

  Future<void> _runAppAction(String packageName, Future<void> Function() action) async {
    if (_busyPackages.contains(packageName)) return;
    setState(() => _busyPackages.add(packageName));
    try {
      await action();
    } catch (error, stack) {
      debugPrint('App action failed for $packageName: $error\n$stack');
      if (!mounted) return;
      AppToast.show(
        context,
        message: error is PlatformException
            ? error.message ?? 'Could not update this app. Please try again.'
            : 'Could not update this app. Please try again.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _busyPackages.remove(packageName));
    }
  }

  Future<String?> _chooseAction(
    String title,
    List<({String id, String label, IconData icon})> actions, {
    String? description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withValues(alpha: 0.3)
        : AppTheme.lightOutlineVariant.withValues(alpha: 0.35);
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          key: const ValueKey('app-action-sheet'),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderCol),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceContainerHigh
                            : AppTheme.lightSurfaceContainerHigh,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.45,
                        color: textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.lightSurfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: borderCol),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey('history-action-${action.id}'),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: secContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(action.icon,
                                size: 22, color: onSecContainer),
                          ),
                          title: Text(
                            action.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 20, color: textMuted),
                          onTap: () => Navigator.pop(context, action.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordHistory(DiscoveredAppInfo app) async {
    await widget.repository.startHistoryOnly(
      packageName: app.packageName,
      displayName: app.displayName,
      iconBytes: _cache.iconFor(app.packageName) ?? app.iconBytes,
    );
    if (!mounted) return;
    AppToast.show(context, message: 'History on for ${app.displayName}');
  }

  Future<void> _addApp(DiscoveredAppInfo app) async {
    final action = await _chooseAction(
      app.displayName,
      [
        (id: 'rules', label: 'Set up rules', icon: Icons.schedule_rounded),
        (id: 'history', label: 'Record history only', icon: Icons.history_rounded),
      ],
      description: 'Save this app\'s notification history without setting up rules. '
          'Quick Mute still applies.',
    );
    if (!mounted || action == null) return;
    if (action == 'history') {
      await _recordHistory(app);
      return;
    }
    await _cache.loadIcons([app.packageName]);
    final managedApp = await widget.repository.addAppFromPackage(
      displayName: app.displayName,
      packageName: app.packageName,
      iconBytes: _cache.iconFor(app.packageName) ?? app.iconBytes,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppDetailsScreen(
          repository: widget.repository,
          app: managedApp,
        ),
      ),
    );
  }

  Future<void> _manageHistory(ManagedApp app) async {
    final action = await _chooseAction(
      app.displayName,
      [
        (id: 'add-rules', label: 'Add rules', icon: Icons.schedule_rounded),
        (id: 'stop', label: 'Stop recording', icon: Icons.pause_rounded),
        (id: 'delete', label: 'Delete recorded history', icon: Icons.delete_outline),
      ],
      description: 'History on. Quick Mute still applies.',
    );
    if (!mounted || action == null) return;
    if (action == 'add-rules') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScheduleEditorScreen(
            repository: widget.repository,
            targetApp: app,
          ),
        ),
      );
    } else if (action == 'stop') {
      await widget.repository.stopHistoryOnly(app.id);
      if (!mounted) return;
      AppToast.show(context, message: 'Recording stopped. Existing history is kept.');
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete history for ${app.displayName}?'),
          content: const Text(
            'Deletes notifications recorded in History-only mode, including their '
            'digest entries. Recording stays on. Other activity is kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('history-delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await AndroidNotificationPlatform.deleteHistoryForApp(app.packageName);
      if (!mounted) return;
      AppToast.show(context, message: 'Recorded history deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final container = isDark
        ? AppTheme.darkSurfaceContainer
        : AppTheme.lightSurfaceContainer;
    final containerLow = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final containerHigh = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withOpacity(0.3)
        : AppTheme.lightOutlineVariant.withOpacity(0.35);
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    final query = _searchController.text.trim().toLowerCase();
    final managedPackageNames =
        widget.repository.managedApps.map((a) => a.packageName).toSet();

    final installedPackages = _cache.apps.map((a) => a.packageName).toSet();
    final apps = [
      ..._cache.apps,
      if (widget.historyManagement)
        for (final app in widget.repository.historyApps)
          if (!installedPackages.contains(app.packageName))
            DiscoveredAppInfo(
              packageName: app.packageName,
              displayName: app.displayName,
              iconBytes: app.iconBytes,
            ),
    ];
    final filteredApps = apps.where((app) {
      final matchesQuery = query.isEmpty ||
          app.displayName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);

      final category = appCategoryFor(app);
      final matchesCategory =
          _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
    _syncShownApps(filteredApps,
        '$query|$_selectedCategory|${filteredApps.length}|${_cache.apps.length}');

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.isEmbedded
          ? null
          : StitchHeader(title: widget.historyManagement ? 'Manage history apps' : 'Add Apps'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 1200 : 600,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      if (widget.historyManagement) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Choose apps to record without setting up rules. '
                            'Quick Mute still applies. Unchecking keeps existing history.',
                          ),
                        ),
                      ],
                      // Filter Chips Controls
                      Column(
                        children: [
                          // Category Filter Chips Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            // Let chips scroll under the page padding up to the screen edges.
                            clipBehavior: Clip.none,
                            child: Row(
                              children: [
                                _buildCategoryChip('all', 'ALL APPS', isDark),
                                const SizedBox(width: 8),
                                _buildCategoryChip(
                                    'messaging', 'MESSAGING', isDark),
                                const SizedBox(width: 8),
                                _buildCategoryChip('social', 'SOCIAL', isDark),
                                const SizedBox(width: 8),
                                _buildCategoryChip(
                                    'productivity', 'PRODUCTIVITY', isDark),
                                const SizedBox(width: 8),
                                _buildCategoryChip('other', 'OTHER', isDark),
                                const SizedBox(width: 8),
                                _buildCategoryChip('system', 'SYSTEM', isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                              Flexible(
                                child: Text(
                                'Discovered Applications',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: secContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${filteredApps.length} AVAILABLE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: onSecContainer,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Applications list scrolls under a frosted search bar,
                      // fading out at both edges like the launcher app drawer.
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: HeaderScrollTransition(
                                child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) {
                                  final h = bounds.height <= 0 ? 1.0 : bounds.height;
                                  double at(double px) =>
                                      (px / h).clamp(0.0, 1.0).toDouble();
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: const [
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: [
                                      0,
                                      at(h - _searchBarReserve - 8),
                                      at(h - 12),
                                    ],
                                  ).createShader(bounds);
                                },
                                child: !_cache.isLoaded
                            ? Center(
                                child: CircularProgressIndicator(color: primary),
                              )
                            : filteredApps.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_rounded,
                                            color: textMuted, size: 40),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No matching applications found',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: textMain,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, listConstraints) {
                                    _viewportHeight = listConstraints.maxHeight;
                                    _tabletLayout = isTablet;
                                    return NotificationListener<ScrollNotification>(
                                    onNotification: _onScroll,
                                    child: isTablet
                                    ? GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: _searchBarReserve),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 12,
                                          mainAxisExtent: 80,
                                        ),
                                        itemCount: filteredApps.length,
                                        itemBuilder: (context, index) {
                                          return _buildAppItem(
                                            context,
                                            app: filteredApps[index],
                                            isManaged:
                                                managedPackageNames.contains(
                                                    filteredApps[index]
                                                        .packageName),
                                            isDark: isDark,
                                            container: container,
                                            containerLow: containerLow,
                                            containerHigh: containerHigh,
                                            borderCol: borderCol,
                                            textMain: textMain,
                                            textMuted: textMuted,
                                            primary: primary,
                                            secContainer: secContainer,
                                            onSecContainer: onSecContainer,
                                          );
                                        },
                                      )
                                    : ListView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: _searchBarReserve),
                                        itemCount: filteredApps.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _buildAppItem(
                                              context,
                                              app: filteredApps[index],
                                              isManaged:
                                                  managedPackageNames.contains(
                                                      filteredApps[index]
                                                          .packageName),
                                              isDark: isDark,
                                              container: container,
                                              containerLow: containerLow,
                                              containerHigh: containerHigh,
                                              borderCol: borderCol,
                                              textMain: textMain,
                                              textMuted: textMuted,
                                              primary: primary,
                                              secContainer: secContainer,
                                              onSecContainer: onSecContainer,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                    },
                                  ),
                              ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                        decoration: BoxDecoration(
                          color: containerLow.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: borderCol, width: 1.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: textMain,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: textMuted, size: 20),
                            prefixIconConstraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: textMuted, size: 18),
                                    onPressed: () =>
                                        _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label, bool isDark) {
    final isSelected = _selectedCategory == catKey;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final containerLow = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = catKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primary : containerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark
                    ? AppTheme.darkOutlineVariant.withOpacity(0.3)
                    : AppTheme.lightOutlineVariant.withOpacity(0.35)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? (isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary)
                : textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAppItem(
    BuildContext context, {
    required DiscoveredAppInfo app,
    required bool isManaged,
    required bool isDark,
    required Color container,
    required Color containerLow,
    required Color containerHigh,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
    required Color primary,
    required Color secContainer,
    required Color onSecContainer,
  }) {
    final historyApp = widget.repository.historyApps
        .where((a) => a.packageName == app.packageName)
        .firstOrNull;
    final busy = _busyPackages.contains(app.packageName);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Native App Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: containerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: _AppIcon(
              key: ValueKey('app-icon-${app.packageName}'),
              app: app,
              placeholder: Icon(
                _getDefaultIconForApp(app.displayName),
                color: textMain,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // App Name and Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  app.displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  historyApp != null
                      ? (historyApp.isDormantVault ? 'Waiting for install' : 'History on')
                      : widget.historyManagement && isManaged
                          ? 'Using rules'
                          : appCategoryFor(app).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Add / Configured Action
          if (!isManaged && widget.historyManagement) ...[
            Checkbox(
              key: ValueKey('history-toggle-${app.packageName}'),
              value: historyApp != null,
              onChanged: busy ? null : (selected) => _runAppAction(app.packageName, () async {
                if (selected == true) {
                  await _recordHistory(app);
                } else if (historyApp != null) {
                  await widget.repository.stopHistoryOnly(historyApp.id);
                  if (!context.mounted) return;
                  AppToast.show(context,
                      message: 'Recording stopped. Existing history is kept.');
                }
              }),
            ),
            if (historyApp != null)
              IconButton(
                key: ValueKey('history-manage-${app.packageName}'),
                tooltip: 'Manage history',
                onPressed: busy ? null : () => _runAppAction(
                  app.packageName, () => _manageHistory(historyApp)),
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ] else if (historyApp != null) ...[
            TextButton(
              key: ValueKey('history-manage-${app.packageName}'),
              onPressed: busy ? null : () => _runAppAction(
                app.packageName, () => _manageHistory(historyApp)),
              child: const Text('Manage'),
            ),
          ] else if (isManaged) ...[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF181F1B) : container,
                foregroundColor:
                    isDark ? const Color(0xFFD5C3B4) : textMuted,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E3932)
                        : Colors.transparent,
                  ),
                ),
              ),
              onPressed: () {
                final managedApp = widget.repository.managedApps
                    .where((a) => a.packageName == app.packageName)
                    .firstOrNull;
                if (managedApp == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppDetailsScreen(
                      repository: widget.repository,
                      app: managedApp,
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: isDark
                        ? const Color(0xFFA7D4A3)
                        : const Color(0xFF5C6145),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Manage',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isDark ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton(
              key: ValueKey('add-app-${app.packageName}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkPrimaryContainer
                    : AppTheme.lightPrimaryContainer,
                foregroundColor: isDark
                    ? const Color(0xFF2B1700)
                    : AppTheme.lightOnPrimaryContainer,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: busy ? null : () => _runAppAction(
                app.packageName, () => _addApp(app)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded,
                      size: MediaQuery.sizeOf(context).width >= 600 ? 18 : 16),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppIcon extends StatefulWidget {
  final DiscoveredAppInfo app;
  final Widget placeholder;

  const _AppIcon({
    super.key,
    required this.app,
    required this.placeholder,
  });

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  final InstalledAppsCache _cache = InstalledAppsCache.instance;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _cache.iconFor(widget.app.packageName) ?? widget.app.iconBytes;
    _cache.addListener(_onIconChanged);
  }

  void _onIconChanged() {
    final bytes = _cache.iconFor(widget.app.packageName) ?? widget.app.iconBytes;
    if (identical(bytes, _bytes)) return;
    setState(() => _bytes = bytes);
  }

  @override
  void didUpdateWidget(covariant _AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bytes = _cache.iconFor(widget.app.packageName) ?? widget.app.iconBytes;
  }

  @override
  void dispose() {
    _cache.removeListener(_onIconChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return bytes == null
        ? widget.placeholder
        : Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover);
  }
}
