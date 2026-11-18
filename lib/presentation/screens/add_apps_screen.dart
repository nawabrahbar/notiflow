import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../platform/notification_platform_interface.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import 'app_details_screen.dart';

/// Add Apps screen adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive: Single column on phone (< 600dp), 2-Column Responsive Card Grid on tablet (>= 600dp)
/// - Live search bar & category filter chips (ALL APPS, MESSAGING, SOCIAL, PRODUCTIVITY, SYSTEM)
/// - Real native app icons from PackageManager
/// - Quick "Add Rule" or "Configured" indicator
class AddAppsScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isEmbedded;

  const AddAppsScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @visibleForTesting
  static void clearInstalledAppsCache() =>
      InstalledAppsCache.instance.resetForTest();

  @override
  State<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends State<AddAppsScreen> {
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

  @override
  void initState() {
    super.initState();
    _cache.addListener(_onCacheChanged);
    _cache.ensureLoaded();
    _searchController.addListener(() => setState(() {}));
    widget.repository.addListener(_onRepositoryChanged);
  }

  void _onCacheChanged() {
    if (mounted) setState(() {});
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
    _cache.loadIcons(apps.sublist(start, end).map((a) => a.packageName));
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

  String _getAppCategory(String name, String packageName) {
    final combined = '${name.toLowerCase()} ${packageName.toLowerCase()}';
    if (combined.contains('whatsapp') ||
        combined.contains('telegram') ||
        combined.contains('signal') ||
        combined.contains('message') ||
        combined.contains('chat') ||
        combined.contains('sms')) {
      return 'messaging';
    }
    if (combined.contains('insta') ||
        combined.contains('facebook') ||
        combined.contains('twitter') ||
        combined.contains('x.com') ||
        combined.contains('tiktok') ||
        combined.contains('youtube') ||
        combined.contains('snapchat') ||
        combined.contains('reddit')) {
      return 'social';
    }
    if (combined.contains('slack') ||
        combined.contains('teams') ||
        combined.contains('meet') ||
        combined.contains('zoom') ||
        combined.contains('jira') ||
        combined.contains('notion') ||
        combined.contains('trello') ||
        combined.contains('gmail') ||
        combined.contains('outlook') ||
        combined.contains('mail')) {
      return 'productivity';
    }
    return 'system';
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

    final filteredApps = _cache.apps.where((app) {
      final matchesQuery = query.isEmpty ||
          app.displayName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);

      final category = _getAppCategory(app.displayName, app.packageName);
      final matchesCategory =
          _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
    _syncShownApps(filteredApps,
        '$query|$_selectedCategory|${filteredApps.length}|${_cache.apps.length}');

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.isEmbedded ? null : const StitchHeader(title: 'Add Apps'),
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
                                      Colors.transparent,
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: [
                                      0,
                                      at(14),
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
    final iconBytes = _cache.iconFor(app.packageName) ?? app.iconBytes;
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
            child: iconBytes != null
                ? Image.memory(
                    iconBytes,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Icon(
                    _getDefaultIconForApp(app.displayName),
                    color: textMain,
                    size: 22,
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
                  _getAppCategory(app.displayName, app.packageName).toUpperCase(),
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
          if (isManaged) ...[
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
              onPressed: () async {
                await _cache.loadIcons([app.packageName]);
                final managedApp = await widget.repository.addAppFromPackage(
                  displayName: app.displayName,
                  packageName: app.packageName,
                  iconBytes: _cache.iconFor(app.packageName) ?? app.iconBytes,
                );
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppDetailsScreen(
                        repository: widget.repository,
                        app: managedApp,
                      ),
                    ),
                  );
                }
              },
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
