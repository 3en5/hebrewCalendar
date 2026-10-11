import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The bundled Rubik font's SIL Open Font License (ARCHITECTURE.md §13).
const String rubikLicenseAsset = 'assets/fonts/OFL-Rubik.txt';

/// Adds the bundled fonts' licenses to Flutter's licenses page, as the OFL
/// requires when the font ships inside the app.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final String text = await rootBundle.loadString(rubikLicenseAsset);
    yield LicenseEntryWithLineBreaks(const <String>['Rubik'], text);
  });
}
