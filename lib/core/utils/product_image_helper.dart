import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ProductImageHelper {
  static Directory? _imagesDirectory;

  /// Get the dedicated persistent directory for product images
  static Future<Directory> getImagesDirectory() async {
    if (_imagesDirectory != null && await _imagesDirectory!.exists()) {
      return _imagesDirectory!;
    }
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }
    final dir = Directory('${baseDir.path}/nayli_kiosk_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _imagesDirectory = dir;
    return dir;
  }

  /// Resolves an image path dynamically across platforms (Windows / Android / Linux)
  /// If the path is an old absolute path from another machine, it searches for the
  /// filename in the current device's image vault or the provided imagesDir.
  static Future<String?> resolveImagePath(String? storedPath, {Directory? imagesDir}) async {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    final trimmed = storedPath.trim();

    // 1. Web URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 2. Direct File exists
    final directFile = File(trimmed);
    if (directFile.existsSync()) {
      return directFile.path;
    }

    // 3. Search in provided imagesDir
    final fileName = trimmed.replaceAll('\\', '/').split('/').last;
    if (imagesDir != null && fileName.isNotEmpty) {
      final imgFile = File('${imagesDir.path}/$fileName');
      if (imgFile.existsSync()) {
        return imgFile.path;
      }
    }

    // 4. Search in local app images vault by file name
    if (fileName.isNotEmpty) {
      final vault = await getImagesDirectory();
      final vaultFile = File('${vault.path}/$fileName');
      if (vaultFile.existsSync()) {
        return vaultFile.path;
      }
    }

    return trimmed;
  }

  /// Synchronous fallback resolver for in-memory mapping
  static String? resolveImagePathSync(String? storedPath, {Directory? imagesDir}) {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    final trimmed = storedPath.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final directFile = File(trimmed);
    if (directFile.existsSync()) {
      return directFile.path;
    }

    final fileName = trimmed.replaceAll('\\', '/').split('/').last;
    if (imagesDir != null && fileName.isNotEmpty) {
      final imgFile = File('${imagesDir.path}/$fileName');
      if (imgFile.existsSync()) {
        return imgFile.path;
      }
    }

    return trimmed;
  }

  /// Decodes a base64 encoded image string and saves it as a local JPG/PNG
  static Future<String?> saveBase64Image(String base64Data, String barcode) async {
    try {
      String cleanBase64 = base64Data;
      String extension = 'jpg';

      if (cleanBase64.contains('data:image/')) {
        final commaIndex = cleanBase64.indexOf(',');
        if (commaIndex != -1) {
          final header = cleanBase64.substring(0, commaIndex);
          if (header.contains('png')) extension = 'png';
          if (header.contains('webp')) extension = 'webp';
          cleanBase64 = cleanBase64.substring(commaIndex + 1);
        }
      }

      cleanBase64 = cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim();
      final bytes = base64Decode(cleanBase64);
      if (bytes.isEmpty) return null;

      final vault = await getImagesDirectory();
      final cleanBarcode = barcode.replaceAll(RegExp(r'[^\w-]'), '_');
      final fileName = 'img_${cleanBarcode}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${vault.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving base64 image: $e');
      return null;
    }
  }

  /// Scans a directory for images that match product barcodes or names
  static Future<Map<String, String>> scanDirectoryForBarcodeImages(Directory dir, [Directory? secondDir]) async {
    final matchedImages = <String, String>{};
    final dirs = [dir, if (secondDir != null) secondDir];

    for (final d in dirs) {
      if (!d.existsSync()) continue;
      try {
        final entities = d.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File) {
            final p = entity.path.toLowerCase();
            if (p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.webp')) {
              final fileNameWithoutExt = entity.uri.pathSegments.last.split('.').first.trim().toLowerCase();
              matchedImages[fileNameWithoutExt] = entity.path;
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning directory for images: $e');
      }
    }

    return matchedImages;
  }
}
