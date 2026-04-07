import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../config/constants.dart';

class FileService {
  static Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    // Validate size
    if (file.size > AppConstants.maxFileSizeMB * 1024 * 1024) {
      throw Exception('File size exceeds ${AppConstants.maxFileSizeMB}MB limit');
    }
    return file;
  }

  static Future<String> copyToAppDirectory(String sourcePath, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'documents'));
    if (!await docsDir.exists()) await docsDir.create(recursive: true);
    final destPath = p.join(docsDir.path, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<Directory> getDocumentsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'documents'));
    if (!await docsDir.exists()) await docsDir.create(recursive: true);
    return docsDir;
  }

  static Future<Directory> getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(appDir.path, 'thumbnails'));
    if (!await thumbDir.exists()) await thumbDir.create(recursive: true);
    return thumbDir;
  }

  static String getFileExtension(String path) =>
      p.extension(path).toLowerCase().replaceAll('.', '');

  static bool fileExists(String path) => File(path).existsSync();

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) return await file.length();
    return 0;
  }
}
