import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../widgets/stitch_header.dart';
import 'app_details_screen.dart';

/// Add Apps screen matching Stitch Obsidian Signal redesign.
/// Features live search, category pills (ALL APPS, MESSAGING, SOCIAL, PRODUCTIVITY, SYSTEM),
/// and batch app addition.
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
    if (lower.contains('chat') || lower.contains('whatsapp') || lower.contains('telegram') || lower.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lower.contains('slack') || lower.contains('team') || lower.contains('meet')) {
      return Icons.workspaces_rounded;
    }
    if (lower.contains('mail') || lower.contains('gmail') || lower.contains('outlook')) {
      return Icons.mail_rounded;
    }
    if (lower.contains('insta') || lower.contains('photo') || lower.contains('camera')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('tweet') || lower.contains('twitter') || lower.contains('x')) {
      return Icons.tag_rounded;
    }
    return Icons.apps_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

    final query = _searchController.text.trim().toLowerCase();
    final managedPackageNames = widget.repository.managedApps.map((a) => a.packageName).toSet();

    final filteredApps = _installedApps.where((app) {
      final matchesQuery = query.isEmpty ||
          app.displayName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);

      final category = _getAppCategory(app.displayName, app.packageName);
      final matchesCategory = _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.isEmbedded ? null : const StitchHeader(title: 'Add Apps'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 14, color: textMain),
                      decoration: InputDecoration(
                        hintText: 'Search applications...',
                        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: textMuted, size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('all', 'ALL APPS', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('messaging', 'MESSAGING', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('social', 'SOCIAL', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('productivity', 'PRODUCTIVITY', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('system', 'SYSTEM', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Discovered Applications Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discovered Applications',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${filteredApps.length} AVAILABLE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // App list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: amber),
                    )
                  : filteredApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, color: textMuted, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                'No matching applications found',
                                style: GoogleFonts.inter(color: textMain, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final isManaged = managedPackageNames.contains(app.packageName);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: app.iconBytes != null
                                        ? Image.memory(
                                            app.iconBytes!,
                                            width: 42,
                                            height: 42,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            _getDefaultIconForApp(app.displayName),
                                            color: textMain,
                                            size: 22,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app.displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: textMain,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getAppCategory(app.displayName, app.packageName).toUpperCase(),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isManaged) ...[
                                    OutlinedButton(
                                      onPressed: () {
                                        final matches = widget.repository.managedApps.where(
                                          (a) => a.packageName == app.packageName,
                                        );
                                        if (matches.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AppDetailsScreen(
                                                repository: widget.repository,
                                                app: matches.first,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: amber,
                                        side: BorderSide(
                                          color: amber.withValues(alpha: isDark ? 0.6 : 0.8),
                                          width: 1.2,
                                        ),
                                        backgroundColor: isDark
                                            ? const Color(0xFF272014)
                                            : const Color(0xFFFEF3C7),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        'Manage',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    ElevatedButton(
                                      onPressed: () async {
                                        final newApp = await widget.repository.addAppFromPackage(
                                          packageName: app.packageName,
                                          displayName: app.displayName,
                                          iconBytes: app.iconBytes,
                                          category: _getAppCategory(app.displayName, app.packageName),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added "${app.displayName}" to Focus Shield!'),
                                            backgroundColor: amber,
                                          ),
                                        );
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AppDetailsScreen(
                                              repository: widget.repository,
                                              app: newApp,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: amber,
                                        foregroundColor: const Color(0xFF09090B),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        '+ Add',
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, bool isDark) {
    final isSelected = _selectedCategory == id;
    final amber = const Color(0xFFF59E0B);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? amber : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? amber : borderCol),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF09090B) : textMain,
          ),
        ),
      ),
    );
  }
}
