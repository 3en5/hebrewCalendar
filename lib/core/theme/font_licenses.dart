import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The bundled Rubik font's SIL Open Font License (ARCHITECTURE.md §13).
const String rubikLicenseAsset = 'assets/fonts/OFL-Rubik.txt';

/// M25: the daily halacha's study schedule comes from @hebcal/learning
/// (BSD 2-Clause), whose notice must go with it.
const String hebcalLearningLicenseAsset =
    'assets/licenses/hebcal-learning-BSD-2.txt';

/// M26: Noto Serif Hebrew (OFL) draws the Torah's cantillation marks, and
/// the weekly portion's aliyot come from @hebcal/leyning (BSD 2-Clause).
const String notoSerifHebrewLicenseAsset =
    'assets/fonts/OFL-NotoSerifHebrew.txt';
const String hebcalLeyningLicenseAsset =
    'assets/licenses/hebcal-leyning-BSD-2.txt';

/// Adds the bundled fonts' and data's licenses to Flutter's licenses page,
/// as the OFL and BSD licenses require.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final String text = await rootBundle.loadString(rubikLicenseAsset);
    yield LicenseEntryWithLineBreaks(const <String>['Rubik'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final String text = await rootBundle.loadString(hebcalLearningLicenseAsset);
    yield LicenseEntryWithLineBreaks(const <String>[
      'Hebcal Learning (לוח הלימוד של ההלכה היומית)',
    ], text);
  });
  LicenseRegistry.addLicense(() async* {
    final String text = await rootBundle.loadString(
      notoSerifHebrewLicenseAsset,
    );
    yield LicenseEntryWithLineBreaks(const <String>['Noto Serif Hebrew'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final String text = await rootBundle.loadString(hebcalLeyningLicenseAsset);
    yield LicenseEntryWithLineBreaks(const <String>[
      'Hebcal Leyning (חלוקת העליות של פרשת השבוע)',
    ], text);
  });
}
