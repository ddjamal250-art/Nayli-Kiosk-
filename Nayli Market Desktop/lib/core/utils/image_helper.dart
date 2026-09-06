import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<String> getLocalImagesDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('\/NayliMarket/images');
    if (!imgDir.existsSync()) imgDir.createSync(recursive: true);
    return imgDir.path;
  }

  static Future<String?> resolveImagePath(String? originalPath) async {
    if (originalPath == null || originalPath.trim().isEmpty) return null;
    if (originalPath.startsWith('http')) return originalPath;
    final filename = originalPath.split(RegExp(r'[\\\\/]')).last;
    if (filename.isEmpty) return null;
    final localDir = await getLocalImagesDir();
    return '\/\';
  }

  static String? resolveImagePathSync(String? originalPath, String baseDirPath) {
    if (originalPath == null || originalPath.trim().isEmpty) return null;
    if (originalPath.startsWith('http')) return originalPath;
    final filename = originalPath.split(RegExp(r'[\\\\/]')).last;
    if (filename.isEmpty) return null;
    return '\/\';
  }
}
