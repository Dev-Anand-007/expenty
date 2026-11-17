import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Saves files to a user-chosen location on the device — the system
/// "save as" dialog (Downloads is the default destination on Android,
/// the Files app on iOS).
class SaveService {
  SaveService._();

  /// Test hook — when set, saving is routed here instead of the system
  /// dialog so widget tests never hit a platform channel.
  static Future<bool> Function(String filename, List<int> bytes)?
  debugOverride;

  /// Saves [bytes] under [filename]. Returns false when the user cancels
  /// the dialog, true once the file is written.
  static Future<bool> saveFile({
    required String filename,
    required List<int> bytes,
  }) async {
    final override = debugOverride;
    if (override != null) {
      return override(filename, bytes);
    }

    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: Uint8List.fromList(bytes),
        fileName: filename,
      ),
    );

    return savedPath != null;
  }
}
