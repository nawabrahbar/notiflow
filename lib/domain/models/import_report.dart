import 'managed_app.dart';

/// One app in an [ImportReport] and how many of its rules came with it.
class ImportReportApp {
  final ManagedApp app;
  final int ruleCount;

  const ImportReportApp({required this.app, required this.ruleCount});
}

/// What a .notiflow backup import did, shown in the import summary sheet.
class ImportReport {
  /// Installed apps whose rules are now active.
  final List<ImportReportApp> imported;

  /// Uninstalled apps kept in the vault; rules apply once the app is installed.
  final List<ImportReportApp> waiting;

  /// Uninstalled apps the user chose to exclude; nothing was imported for them.
  final List<ImportReportApp> skipped;

  /// Names of the saved rules (templates) included in the backup.
  final List<String> savedRules;

  const ImportReport({
    this.imported = const [],
    this.waiting = const [],
    this.skipped = const [],
    this.savedRules = const [],
  });

  int get importedRuleCount =>
      imported.fold(0, (sum, a) => sum + a.ruleCount);
}
