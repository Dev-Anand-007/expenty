import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes generated files to a temp folder and hands them to the system
/// share sheet (WhatsApp, mail, Drive, …).
class ShareService {
  ShareService._();

  /// Test hook — when set, sharing is routed here instead of the platform
  /// share sheet so widget tests never hit a platform channel.
  static Future<void> Function(String filename, List<int> bytes)?
  debugOverride;

  static Future<void> shareCsv({
    required String filename,
    required String content,
  }) {
    return shareFile(
      filename: filename,
      bytes: utf8.encode(content),
      mimeType: 'text/csv',
    );
  }

  static Future<void> shareFile({
    required String filename,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final override = debugOverride;
    if (override != null) {
      await override(filename, bytes);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, name: filename, mimeType: mimeType)]),
    );
  }
}
