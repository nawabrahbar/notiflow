import 'package:flutter/material.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/restricted_settings_sheet.dart';
import '../widgets/stitch_header.dart';
import 'main_navigation_shell.dart';

/// Permission Paused / Action Required screen faithfully implemented from Stitch UX.
class PermissionScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isInitialSetup;

  const PermissionScreen({
    super.key,
    required this.repository,
    this.isInitialSetup = false,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  late final NotificationPlatformInterface _platform;
  bool _isChecking = true;
  bool _isSupported = true;
  bool _isOemAccordionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platform = PlatformFactory.createPlatformService();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    final supported = await _platform.isPlatformSupported();
    final granted = await _platform.isNotificationAccessGranted();

    if (!mounted) return;

    setState(() {
      _isSupported = supported;
      _isChecking = false;
    });

    if (granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Restored · Focus Shield Online'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainNavigationShell(
            repository: widget.repository,
            showRestorationBanner: true,
          ),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    await _platform.openNotificationAccessSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text('Platform Limitation'),
          backgroundColor: AppTheme.surface,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, size: 64, color: AppTheme.tertiaryAmber),
              const SizedBox(height: 20),
              const Text(
                'Notification Scheduling on iOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const Text(
                'Apple iOS enforces strict app sandboxing and does not provide public system APIs for intercepting or canceling notifications from third-party apps.\n\nNotification Handler respects Apple privacy policies and operates 100% locally on supported Android devices.',
                style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final managedApps = widget.repository.managedApps;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: StitchHeader(
        title: 'Permission Required',
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppTheme.tertiaryAmber),
            tooltip: 'Restricted Settings Guide (Android 13+)',
            onPressed: () => RestrictedSettingsSheet.show(context, _platform),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          children: [
            const SizedBox(height: 12),

            // Status Hero & Emblem
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.tertiaryAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTION REQUIRED · ACCESS PAUSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppTheme.tertiaryAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Emblem: Paused Bell Shield
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_paused_rounded, size: 32, color: AppTheme.tertiaryAmber),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppTheme.tertiaryAmber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.priority_high_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Center(
              child: Text(
                'Notification Access is paused',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Without Notification Access, Notification Handler cannot evaluate schedules or quiet incoming alerts. All apps are currently passing through standard Android ringers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Impact / Consequence Overview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ENGINE STATUS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.onSurfaceVariant),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Offline · Zero Background Access',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text(
                        'Inactive',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '(0 alerts silenced)',
                        style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    managedApps.isEmpty
                        ? 'Your schedule rules are preserved safely, but cannot be evaluated.'
                        : 'Your ${managedApps.length} custom rules (${managedApps.take(3).map((a) => a.displayName).join(", ")}) are safely preserved, but cannot be enforced.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.35),
                  ),
                  if (managedApps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: managedApps.take(3).map((app) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.tertiaryAmber),
                              const SizedBox(width: 6),
                              Text(
                                '${app.displayName} (Paused)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step-by-Step Recovery Guide (3-Step Reconnection)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '3-Step Reconnection',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                ),
                Text(
                  'Takes ~15 seconds',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildReconnectionStep('1', 'Open Android Settings', 'Use the primary button below to jump straight to the system access screen.'),
            const SizedBox(height: 8),
            _buildReconnectionStep('2', 'Find ‘Notification Handler’', 'In Device & app notifications, tap on this app\'s entry.'),
            const SizedBox(height: 8),
            _buildReconnectionStep('3', 'Turn Switch ON & Confirm', 'Switch the permission toggle to Allow. Your schedule resumes instantly.'),
            const SizedBox(height: 16),

            // Privacy & System Architecture Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRIVACY & SYSTEM ARCHITECTURE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  _buildPrivacyRow(Icons.security_rounded, 'Why Notification Access?', 'Android mandates the listener service permission to detect incoming banners and suppress ringers during your defined quiet windows.'),
                  const SizedBox(height: 12),
                  _buildPrivacyRow(Icons.lock_rounded, '100% Offline & Private', 'Alert evaluation runs strictly in your local device sandbox. Senders, message text, and chat contents are never stored, tracked, or sent online.'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // OEM Battery Assistant Accordion
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _isOemAccordionExpanded = !_isOemAccordionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.battery_charging_full_rounded, size: 20, color: AppTheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Using Samsung, Xiaomi, or OnePlus?',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                            ),
                          ),
                          Icon(
                            _isOemAccordionExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOemAccordionExpanded)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom battery managers on One UI, MIUI, and OxygenOS aggressively terminate dormant listener services during deep sleep.',
                            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryTeal),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Set App Battery Usage to ‘Unrestricted’',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Restricted Settings Helper Card for Sideloaded APKs
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_open_rounded, color: AppTheme.primaryTeal, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Installed via APK? Allow Restricted Settings',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'On Android 13+, sideloaded apps require unlocking "Allow restricted settings" in App Info before notification access can be toggled.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => RestrictedSettingsSheet.show(context, _platform),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text('Open 2-Step APK Permission Guide', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            // Interactive Action Buttons
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openSettings,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Open Android Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.onSurface,
                side: const BorderSide(color: AppTheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _checkPermission,
              child: _isChecking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Re-check Permission Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Android NotificationListenerService API standard. You can manage or revoke access anytime from Android System Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.outline),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectionStep(String step, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
