import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Wymiana plików z resztą systemu (spec. 6): zapis i odczyt przez
/// systemowy wybór pliku (bez uprawnień do całej pamięci) oraz arkusz
/// udostępniania.
abstract interface class FileExchange {
  /// Zapis pliku w miejscu wybranym przez użytkownika. False po anulowaniu.
  Future<bool> save({
    required String fileName,
    required String content,
    required String mimeType,
  });

  /// Odczyt pliku tekstowego wybranego przez użytkownika; null po anulowaniu.
  /// Rzuca [FormatException], gdy plik nie jest tekstem UTF-8.
  Future<String?> pickText();

  /// Udostępnienie pliku przez systemowy arkusz.
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  });

  /// Udostępnienie samego tekstu.
  Future<void> shareText(String text, {String? subject});
}

final class PlatformFileExchange implements FileExchange {
  const PlatformFileExchange();

  @override
  Future<bool> save({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<String?> pickText() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: mimeType,
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: subject,
      ),
    );
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

final fileExchangeProvider = Provider<FileExchange>(
  (ref) => const PlatformFileExchange(),
);
