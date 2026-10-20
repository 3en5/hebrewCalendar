// The licenses page lists the bundled font and the daily halacha's study
// schedule (@hebcal/learning, BSD 2-Clause), whose notices must ship.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/theme/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Rubik and the study schedule are on the licenses page', () async {
    registerFontLicenses();
    final List<LicenseEntry> entries = await LicenseRegistry.licenses.toList();
    final Iterable<String> packages = entries.expand(
      (LicenseEntry e) => e.packages,
    );
    expect(packages, contains('Rubik'));
    expect(packages.any((String p) => p.startsWith('Hebcal Learning')), isTrue);
    // M26: the Torah font and the weekly portion's aliyot.
    expect(packages, contains('Noto Serif Hebrew'));
    expect(packages.any((String p) => p.startsWith('Hebcal Leyning')), isTrue);
    final LicenseEntry hebcal = entries.firstWhere(
      (LicenseEntry e) => e.packages.any((String p) => p.startsWith('Hebcal')),
    );
    expect(
      hebcal.paragraphs.map((LicenseParagraph p) => p.text).join(' '),
      contains('BSD 2-Clause'),
    );
  });
}
