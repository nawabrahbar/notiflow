import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/import_summary_sheet.dart';
import 'main_navigation_shell.dart';

/// Onboarding step three: optional .notiflow backup import.
class ImportRulesScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const ImportRulesScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ImportRulesScreen> createState() => _ImportRulesScreenState();
}

class _ImportRulesScreenState extends State<ImportRulesScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccessMessage = true;

  Future<void> _handlePickFromDevice() async {
    final rawContent = await widget.repository.pickBackupRawContent();
    if (!mounted || rawContent == null) return;
    if (rawContent.trim().isEmpty) {
      AppToast.show(
        context,
        message: 'Selected backup file is empty.',
        type: AppToastType.error,
      );
      return;
    }
    await _processBackupContent(rawContent);
  }

  Future<void> _processBackupContent(String rawContent) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    final uninstalled =
        await widget.repository.detectUninstalledAppsInBackup(rawContent);
    bool excludeUninstalled = false;

    if (uninstalled.isNotEmpty && mounted) {
      final choice = await showUninstalledBackupChoiceSheet(context, uninstalled);
      if (choice == null) {
        setState(() => _isProcessing = false);
        return;
      }
      excludeUninstalled = (choice == 'exclude');
    }

    final report = await widget.repository.importRulesWithReport(
      rawContent,
      replaceAll: true,
      vaultUninstalled: !excludeUninstalled,
      excludeUninstalled: excludeUninstalled,
    );

    if (!mounted) return;
    final success = report != null;
    setState(() {
      _isProcessing = false;
      if (success) {
        _statusMessage =
            'Rules successfully restored from .notiflow backup file!';
        _isSuccessMessage = true;
      } else {
        _statusMessage =
            'Invalid .notiflow backup file. Please select a valid backup exported from Notiflow.';
        _isSuccessMessage = false;
      }
    });

    if (success) {
      final viewRules = await showImportSummarySheet(context, report,
          repository: widget.repository);
      await _finishFlow(
        initialIndex: viewRules
            ? MainNavigationShell.rulesTab
            : MainNavigationShell.dashboardTab,
      );
    } else {
      AppToast.show(
        context,
        message: 'Invalid .notiflow backup file.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _finishFlow({
    int initialIndex = MainNavigationShell.dashboardTab,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_onboarding_completed', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationShell(
          repository: widget.repository,
          initialIndex: initialIndex,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _handlePasteBackupJson() async {
    final controller = TextEditingController();
    String? content;
    try {
      content = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Paste Backup JSON'),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste your exported .notiflow JSON',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    if (content != null && content.trim().isNotEmpty) {
      await _processBackupContent(content);
    }
  }

  Widget _buildImportPage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted =
        isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimary = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final border = isDark
        ? AppTheme.darkOutlineVariant.withValues(alpha: 0.45)
        : AppTheme.lightPrimaryContainer.withValues(alpha: 0.45);
    final stepColor = isDark
        ? AppTheme.darkSecondaryContainer
        : const Color(0xFFFAEDCD);
    final stepTextColor = isDark
        ? AppTheme.darkOnSecondaryContainer
        : const Color(0xFF9C5B28);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: isTablet ? 28 : 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notiflow',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: stepColor,
                            borderRadius: BorderRadius.circular(999),
                            border: isDark
                                ? Border.all(
                                    color: AppTheme.darkSecondary
                                        .withValues(alpha: 0.22),
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTablet) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.darkSecondary
                                        : AppTheme.lightSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                              ],
                              Text(
                                isTablet
                                    ? 'STEP 3 OF 3 · RULES IMPORT'
                                    : 'STEP 3 OF 3',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.55,
                                  color: stepTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: isTablet ? 42 : 46,
                        bottom: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Import Rules',
                            style: GoogleFonts.newsreader(
                              fontSize: isTablet ? 38 : 32,
                              height: 1.2,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Restore rules from an exported backup or start fresh with defaults.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isTablet ? 17 : 15.5,
                              height: 1.55,
                              color: textMuted,
                            ),
                          ),
                          SizedBox(height: isTablet ? 42 : 34),
                          _buildImportCard(
                            isTablet: isTablet,
                            isDark: isDark,
                            textMain: textMain,
                            textMuted: textMuted,
                            primary: primary,
                            onPrimary: onPrimary,
                            border: border,
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isSuccessMessage
                                    ? (isDark
                                        ? const Color(0xFF173124)
                                        : const Color(0xFFE7F2E4))
                                    : (isDark
                                        ? const Color(0xFF3A211F)
                                        : const Color(0xFFFCE9E6)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isSuccessMessage
                                      ? AppTheme.signalSuccess
                                      : AppTheme.signalError,
                                ),
                              ),
                              child: Text(
                                _statusMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: textMain,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isTablet) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'You can always configure filters, apps, and silent alerts later in Settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: isTablet ? 24 : 18,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _finishFlow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.darkPrimaryContainer
                              : AppTheme.lightPrimaryContainer,
                          foregroundColor: isDark
                              ? AppTheme.darkOnPrimary
                              : AppTheme.lightOnPrimaryContainer,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Done',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              isTablet
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded,
                              size: 21,
                            ),
                          ],
                        ),
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

  Widget _buildImportCard({
    required bool isTablet,
    required bool isDark,
    required Color textMain,
    required Color textMuted,
    required Color primary,
    required Color onPrimary,
    required Color border,
  }) {
    final card = Container(
      height: isTablet ? null : 300,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 24,
        vertical: isTablet ? 32 : 24,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLow
            : AppTheme.lightSurfaceContainerLow,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.035),
            blurRadius: isDark ? 28 : 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isTablet ? 88 : 80,
            height: isTablet ? 88 : 80,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkPrimary.withValues(alpha: 0.16)
                  : const Color(0xFFFFF3DF),
              borderRadius:
                  BorderRadius.circular(isTablet ? 44 : 20),
              border: Border.all(
                color: primary.withValues(alpha: isDark ? 0.36 : 0.6),
              ),
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              color: primary,
              size: isTablet ? 42 : 38,
            ),
          ),
          SizedBox(height: isTablet ? 22 : 28),
          Text(
            'Import .notiflow Backup File',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTablet ? 20 : 19,
              fontWeight: FontWeight.w700,
              color: textMain,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isTablet
                ? 'Select an exported .notiflow backup file from your device storage to restore rules.'
                : 'Tap to browse device storage or restore your exported focus rules',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.55,
              color: textMuted,
            ),
          ),
          if (isTablet) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handlePickFromDevice,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Select .notiflow File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isProcessing ? null : _handlePasteBackupJson,
                    icon: Icon(
                      Icons.data_object_rounded,
                      color: isDark
                          ? AppTheme.darkSecondary
                          : AppTheme.lightSecondary,
                    ),
                    label: const Text('Or Paste Backup JSON'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMain,
                      side: BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );

    if (isTablet) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isProcessing ? null : _handlePickFromDevice,
        borderRadius: BorderRadius.circular(24),
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildImportPage(context);
}

/// Settings import: opens the system file picker and restores the chosen
/// .notiflow backup directly. Returns true when the backup was restored.
Future<bool> restoreBackupFromFile(
  BuildContext context,
  ScheduleRepository repository,
) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  void toast(String message, {required bool success}) {
    AppToast.showOn(
      overlay,
      message: message,
      type: success ? AppToastType.success : AppToastType.error,
    );
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  var progressVisible = false;
  void showProgress() {
    if (progressVisible || !context.mounted) return;
    progressVisible = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const _ImportProgressDialog(),
    );
  }

  void hideProgress() {
    if (!progressVisible) return;
    progressVisible = false;
    navigator.pop();
  }

  try {
    // Shown before the picker so it is already visible while the chosen
    // file is read once the picker closes.
    showProgress();
    final rawContent = await repository.pickBackupRawContent();
    if (rawContent == null || !context.mounted) return false;
    if (rawContent.trim().isEmpty) {
      hideProgress();
      toast('Selected backup file is empty.', success: false);
      return false;
    }

    final uninstalled =
        await repository.detectUninstalledAppsInBackup(rawContent);
    var excludeUninstalled = false;
    if (uninstalled.isNotEmpty) {
      hideProgress();
      if (!context.mounted) return false;
      final choice =
          await showUninstalledBackupChoiceSheet(context, uninstalled);
      if (choice == null) return false;
      excludeUninstalled = choice == 'exclude';
      showProgress();
    }

    final report = await repository.importRulesWithReport(
      rawContent,
      replaceAll: true,
      vaultUninstalled: !excludeUninstalled,
      excludeUninstalled: excludeUninstalled,
    );
    hideProgress();
    if (report == null) {
      toast('Invalid .notiflow backup file.', success: false);
      return false;
    }
    if (context.mounted) {
      final shell = MainNavigationShell.of(context);
      final viewRules = await showImportSummarySheet(context, report,
          repository: repository);
      if (viewRules) shell?.switchTab(MainNavigationShell.rulesTab);
    }
    return true;
  } finally {
    hideProgress();
  }
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted =
        isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: primary),
              ),
              const SizedBox(width: 18),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importing backup…',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Restoring your apps and rules. Please wait.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: textMuted,
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
  }
}

Future<String?> showUninstalledBackupChoiceSheet(
  BuildContext context,
  List<ManagedApp> uninstalled,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isDark
      ? AppTheme.darkSurfaceContainerLow
      : AppTheme.lightSurfaceContainerLow;
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
  final borderCol = isDark
      ? AppTheme.darkOutlineVariant.withOpacity(0.3)
      : AppTheme.lightOutlineVariant.withOpacity(0.35);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.apps_outage_rounded,
                    color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uninstalled Apps (${uninstalled.length})',
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    Text(
                      'Detected in backup, but not installed on this device',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark
                      ? AppTheme.darkSurfaceContainer
                      : AppTheme.lightSurfaceContainer)
                  .withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            child: Text(
              'Apps: ${uninstalled.map((a) => a.displayName).take(5).join(', ')}${uninstalled.length > 5 ? ' ...and ${uninstalled.length - 5} more' : ''}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Option 1: Keep in Vault (Recommended)
          InkWell(
            onTap: () => Navigator.pop(ctx, 'vault'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: secContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: (isDark
                            ? AppTheme.darkSecondary
                            : AppTheme.lightSecondary)
                        .withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: onSecContainer, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Keep in Vault',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: secContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: onSecContainer,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keep rules in local database. Hidden from Rules page now, and auto-applied when you install the app.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: onSecContainer),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Option 2: Exclude Apps
          InkWell(
            onTap: () => Navigator.pop(ctx, 'exclude'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.lightSurfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline_rounded,
                      color: textMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exclude These Apps',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Discard rules for uninstalled apps and only import rules for apps installed on this device.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
