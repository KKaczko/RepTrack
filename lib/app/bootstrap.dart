import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/database_providers.dart';
import '../core/domain/local_date.dart';

/// Przygotowanie aplikacji przed pierwszą klatką: strefy czasowe, licencje
/// zasobów i baza danych.
ProviderContainer bootstrap() {
  ensureTimeZonesLoaded();
  LicenseRegistry.addLicense(_assetLicenses);
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(AppDatabase.open())],
  );
}

Stream<LicenseEntry> _assetLicenses() async* {
  final inter = await rootBundle.loadString('assets/fonts/Inter-OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter (font)'], inter);
}
