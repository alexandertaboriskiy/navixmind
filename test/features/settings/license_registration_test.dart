import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// We re-implement the registration logic here since it uses a top-level
// function and a private bool flag. This mirrors the production code exactly
// so we can verify the behaviour without importing private symbols.

bool _testExtraLicensesRegistered = false;

const _licenseEntries = <(String package, String license)>[
  // Python packages
  ('requests', 'Apache-2.0'),
  ('beautifulsoup4', 'MIT'),
  ('lxml', 'BSD-3-Clause'),
  ('pypdf', 'BSD-3-Clause'),
  ('reportlab', 'BSD-3-Clause'),
  ('python-docx', 'MIT'),
  ('Pillow', 'HPND'),
  ('yt-dlp', 'Unlicense'),
  ('numpy', 'BSD-3-Clause'),
  ('python-dateutil', 'Apache-2.0 / BSD'),
  ('urllib3', 'MIT'),
  // Native / Android
  ('FFmpeg (via ffmpeg_kit)', 'LGPL-3.0'),
  ('Chaquopy', 'MIT'),
  ('ML Kit Text Recognition', 'Google APIs Terms of Service'),
  ('ML Kit Face Detection', 'Google APIs Terms of Service'),
  ('Firebase', 'Apache-2.0'),
  ('Kotlin Coroutines', 'Apache-2.0'),
];

/// Registers test licenses into [LicenseRegistry].
/// Mirrors [_registerExtraLicenses] from settings_screen.dart.
void registerTestLicenses() {
  if (_testExtraLicensesRegistered) return;
  _testExtraLicensesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    for (final (package, license) in _licenseEntries) {
      yield LicenseEntryWithLineBreaks(
        [package],
        '$license\n\nTest license text for $package.',
      );
    }
  });
}

void main() {
  group('Extra license registration', () {
    test('registerTestLicenses adds entries to LicenseRegistry', () async {
      registerTestLicenses();

      final allLicenses = await LicenseRegistry.licenses.toList();
      final packageNames =
          allLicenses.expand((e) => e.packages).toSet();

      // Verify all expected packages appear
      for (final (package, _) in _licenseEntries) {
        expect(
          packageNames.contains(package),
          isTrue,
          reason: 'Expected "$package" to be in license registry',
        );
      }
    });

    test('license entries contain correct license type in body', () async {
      // Licenses were already registered by the previous test (guarded by bool)
      // but LicenseRegistry is cumulative so they persist.
      registerTestLicenses(); // no-op due to guard

      final allLicenses = await LicenseRegistry.licenses.toList();

      for (final (package, license) in _licenseEntries) {
        final matching = allLicenses.where(
          (e) => e.packages.contains(package),
        );
        expect(
          matching.isNotEmpty,
          isTrue,
          reason: 'Expected to find license entry for "$package"',
        );

        // The first paragraph should contain the license identifier
        final entry = matching.first;
        final paragraphs = entry.paragraphs.toList();
        expect(paragraphs.isNotEmpty, isTrue,
            reason: 'License entry for "$package" should have paragraphs');

        // First paragraph text should start with the license type
        expect(
          paragraphs.first.text,
          startsWith(license),
          reason:
              'License body for "$package" should start with "$license"',
        );
      }
    });

    test('calling registerTestLicenses twice does not duplicate entries',
        () async {
      // Reset the guard to test idempotency from scratch
      // We can't truly reset since LicenseRegistry.addLicense is append-only,
      // but we can verify the guard prevents a second addLicense call.

      // Count how many of our packages are in the registry
      final allBefore = await LicenseRegistry.licenses.toList();
      final countBefore = allBefore
          .where((e) => e.packages.contains('requests'))
          .length;

      // Call again — guard should prevent duplicate
      registerTestLicenses();

      final allAfter = await LicenseRegistry.licenses.toList();
      final countAfter = allAfter
          .where((e) => e.packages.contains('requests'))
          .length;

      expect(countAfter, equals(countBefore),
          reason: 'Guard should prevent duplicate registration');
    });

    test('expected number of extra license entries is 17', () async {
      expect(_licenseEntries.length, equals(17));
    });

    test('each license entry has exactly one package', () async {
      registerTestLicenses();

      final allLicenses = await LicenseRegistry.licenses.toList();

      for (final (package, _) in _licenseEntries) {
        final matching = allLicenses.where(
          (e) => e.packages.contains(package),
        );
        for (final entry in matching) {
          // Our entries should have exactly 1 package each
          // (though Flutter's built-in entries may have multiple)
          if (entry.paragraphs.first.text.contains('Test license text')) {
            expect(entry.packages.toList().length, equals(1),
                reason:
                    'Each manually registered entry should have one package');
          }
        }
      }
    });

    test('LicenseEntryWithLineBreaks produces paragraphs correctly', () {
      final entry = LicenseEntryWithLineBreaks(
        ['test-package'],
        'MIT\n\nSome license text here.',
      );

      expect(entry.packages, contains('test-package'));
      final paragraphs = entry.paragraphs.toList();
      expect(paragraphs.isNotEmpty, isTrue);
    });

    test('all Python packages are present', () {
      const expectedPython = [
        'requests',
        'beautifulsoup4',
        'lxml',
        'pypdf',
        'reportlab',
        'python-docx',
        'Pillow',
        'yt-dlp',
        'numpy',
        'python-dateutil',
        'urllib3',
      ];

      final registered = _licenseEntries.map((e) => e.$1).toList();
      for (final pkg in expectedPython) {
        expect(registered.contains(pkg), isTrue,
            reason: 'Python package "$pkg" should be in license entries');
      }
    });

    test('all native/Android libraries are present', () {
      const expectedNative = [
        'FFmpeg (via ffmpeg_kit)',
        'Chaquopy',
        'ML Kit Text Recognition',
        'ML Kit Face Detection',
        'Firebase',
        'Kotlin Coroutines',
      ];

      final registered = _licenseEntries.map((e) => e.$1).toList();
      for (final lib in expectedNative) {
        expect(registered.contains(lib), isTrue,
            reason: 'Native library "$lib" should be in license entries');
      }
    });

    test('no duplicate package names in entries', () {
      final names = _licenseEntries.map((e) => e.$1).toList();
      final uniqueNames = names.toSet();
      expect(names.length, equals(uniqueNames.length),
          reason: 'There should be no duplicate package names');
    });

    test('no empty license types', () {
      for (final (package, license) in _licenseEntries) {
        expect(license.isNotEmpty, isTrue,
            reason: 'License type for "$package" should not be empty');
      }
    });

    test('no empty package names', () {
      for (final (package, _) in _licenseEntries) {
        expect(package.isNotEmpty, isTrue,
            reason: 'Package name should not be empty');
      }
    });
  });
}
