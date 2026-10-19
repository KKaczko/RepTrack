import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clock.dart';
import '../domain/ids.dart';
import 'app_database.dart';

/// Baza aplikacji. Nadpisywana w `bootstrap` (plik) i w testach (pamięć).
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider musi być nadpisany'),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidV7Generator(),
);
