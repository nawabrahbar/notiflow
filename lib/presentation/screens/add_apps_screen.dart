import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
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

  @override
  State<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends State<AddAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final NotificationPlatformInterface _platform;

  List<DiscoveredAppInfo> _installedApps = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _platform = PlatformFactory.createPlatformService();
    _loadInstalledApps();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _platform.getInstalledApplications();
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

    final filteredApps = _installedApps.where((app) {
      final matchesQuery = query.isEmpty ||
          app.displayName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);

      final category = _getAppCategory(app.displayName, app.packageName);
      final matchesCategory =
          _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();

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
                      // Search Bar & Filter Chips Controls
                      Column(
                        children: [
                          // Search Box
                          Container(
                            decoration: BoxDecoration(
                              color: containerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: textMain,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search applications...',
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
                          const SizedBox(height: 12),

                          // Category Filter Chips Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
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
                          Row(
                            children: [
                              Text(
                                'Discovered Applications',
                                style: GoogleFonts.newsreader(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                  letterSpacing: -0.3,
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
                          Row(
                            children: [
                              Icon(Icons.sync_rounded,
                                  size: 14, color: textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Auto-synced',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Applications List / Tablet 2-Column Responsive Grid
                      Expanded(
                        child: _isLoading
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
                                : isTablet
                                    ? GridView.builder(
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 24),
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
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 24),
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
            child: app.iconBytes != null
                ? Image.memory(
                    app.iconBytes!,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: secContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: onSecContainer),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: onSecContainer,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: isDark
                    ? AppTheme.darkOnPrimary
                    : AppTheme.lightOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final managedApp = await widget.repository.addApp(
                  displayName: app.displayName,
                  packageName: app.packageName,
                  iconBytes: app.iconBytes,
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
              child: Text(
                'Add Rule',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
