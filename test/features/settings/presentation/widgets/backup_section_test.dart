// Widget tests for the M7 settings screen's backup section: export/share
// buttons call through to the (faked) BackupService and show a success/error
// snackbar, and the import button shows a merge-semantics confirm dialog
// before actually restoring anything.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/backup/backup_service.dart';
import 'package:hebrew_calendar/features/settings/application/backup_providers.dart';
import 'package:hebrew_calendar/features/settings/presentation/widgets/backup_section.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';

import '../../../../test_support/fake_backup_service.dart';

final AppLocalizationsHe _l10n = AppLocalizationsHe();

Widget _wrap(FakeBackupService service) {
  return ProviderScope(
    overrides: <Override>[backupServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      locale: const Locale('he'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: BackupSection()),
    ),
  );
}

void main() {
  testWidgets('export button calls the service and shows a success snackbar', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService();
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupExportButton));
    await tester.pumpAndSettle();

    expect(service.exportToFileCallCount, 1);
    expect(find.text(_l10n.settingsBackupExportSuccessMessage), findsOneWidget);
  });

  testWidgets('export failure shows an error snackbar', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService()
      ..exportResult = const BackupExportResult(
        status: BackupExportStatus.failure,
      );
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupExportButton));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.settingsBackupExportErrorMessage), findsOneWidget);
  });

  testWidgets('share icon calls shareBackup', (WidgetTester tester) async {
    final FakeBackupService service = FakeBackupService();
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();

    expect(service.shareBackupCallCount, 1);
    expect(service.exportToFileCallCount, 0);
  });

  testWidgets('import button shows a merge-semantics confirm dialog first', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService();
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupImportButton));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.settingsBackupImportConfirmMessage), findsOneWidget);
    expect(service.importFromFileCallCount, 0);
  });

  testWidgets('cancelling the confirm dialog never imports', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService();
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupImportButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.commonCancel));
    await tester.pumpAndSettle();

    expect(service.importFromFileCallCount, 0);
  });

  testWidgets('confirming restores and shows a created/updated summary', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService()
      ..importResult = const BackupImportResult(
        status: BackupImportStatus.success,
        createdCount: 3,
        updatedCount: 5,
      );
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupImportButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(_l10n.settingsBackupImportConfirmButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.importFromFileCallCount, 1);
    expect(
      find.text(_l10n.settingsBackupImportSuccessMessage(3, 5)),
      findsOneWidget,
    );
  });

  testWidgets('an unsupported backup version shows the dedicated message', (
    WidgetTester tester,
  ) async {
    final FakeBackupService service = FakeBackupService()
      ..importResult = const BackupImportResult(
        status: BackupImportStatus.unsupportedVersion,
      );
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text(_l10n.settingsBackupImportButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(_l10n.settingsBackupImportConfirmButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(_l10n.settingsBackupImportUnsupportedVersionMessage),
      findsOneWidget,
    );
  });
}
