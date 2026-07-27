import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks real files/photos and copies them into app storage so the reference
/// survives even if the original is moved or the cache is cleared.
class AttachmentService {
  const AttachmentService._();

  static final ImagePicker _images = ImagePicker();

  /// Copies [source] into the app documents dir, returning the stored path.
  static Future<String> _store(File source, String suffix) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory attachments = Directory('${dir.path}/attachments');
    if (!attachments.existsSync()) attachments.createSync(recursive: true);
    final String name =
        '${DateTime.now().millisecondsSinceEpoch}_$suffix';
    final File dest = File('${attachments.path}/$name');
    await source.copy(dest.path);
    return dest.path;
  }

  /// Camera or gallery photo. Returns the stored path, or null if cancelled.
  static Future<String?> pickImage({bool fromCamera = false}) async {
    final XFile? x = await _images.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return null;
    return _store(File(x.path), x.name);
  }

  /// Any file type (PRD 9 — the vault must accept more than images/PDFs).
  static Future<String?> pickFile() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles();
    final String? path = res?.files.single.path;
    if (path == null) return null;
    return _store(File(path), res!.files.single.name);
  }

  static String extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }

  static bool isImage(String path) =>
      const <String>{'jpg', 'jpeg', 'png', 'webp', 'heic'}
          .contains(extensionOf(path));

  static Future<void> delete(String path) async {
    try {
      final File f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {/* already gone */}
  }
}
