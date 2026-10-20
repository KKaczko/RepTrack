import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/app/app_info.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('wersja w kopii zapasowej zgadza się z pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    expect(appVersionName, pubspec['version']);
  });
}
