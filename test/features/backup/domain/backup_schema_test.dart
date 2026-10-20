import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/backup/domain/backup_format.dart';

/// `docs/backup-format.schema.json` jest generowany z opisu formatu.
/// Po zmianie formatu: `REPTRACK_WRITE_SCHEMA=1 flutter test` dla tego pliku.
void main() {
  test('JSON Schema w docs zgadza się z opisem formatu', () {
    const path = 'docs/backup-format.schema.json';
    final generated =
        '${const JsonEncoder.withIndent('  ').convert(backupJsonSchema())}\n';
    if (Platform.environment['REPTRACK_WRITE_SCHEMA'] == '1') {
      File(path).writeAsStringSync(generated);
    }
    expect(
      File(path).readAsStringSync().replaceAll('\r\n', '\n'),
      generated,
      reason: 'Wygeneruj ponownie: REPTRACK_WRITE_SCHEMA=1 flutter test $path',
    );
  });
}
