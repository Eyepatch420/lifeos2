import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Real clipboard / share-sheet / file-export, replacing the snackbar stubs.
class ShareService {
  const ShareService._();

  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  /// Writes [content] to a file in the app documents dir and opens the share
  /// sheet. Returns the file path so callers can report where it went.
  static Future<String> shareAsFile(
    String content,
    String fileName, {
    String? subject,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File f = File('${dir.path}/$fileName');
    await f.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(f.path)], subject: subject),
    );
    return f.path;
  }

  static Future<void> shareFilePath(String path, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], subject: subject),
    );
  }
}
