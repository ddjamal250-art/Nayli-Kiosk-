import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/data/hive_database.dart';
import '../../../core/data/local_sync_server.dart';
import '../../../core/utils/telegram_service.dart';
import '../../../core/utils/product_image_helper.dart';
import '../../documents/data/commercial_document_service.dart';
import '../../product/data/models/product_model.dart';

class BackupSnapshotInfo {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime createdAt;
  final int productsCount;
  final int invoicesCount;
  final int customersCount;
  final int documentsCount;

  BackupSnapshotInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.createdAt,
    required this.productsCount,
    required this.invoicesCount,
    required this.customersCount,
    required this.documentsCount,
  });

  String get readableSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BackupService {
  /// Delete a local backup file
  static Future<bool> deleteBackup(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Get dedicated local backup directory
  static Future<Directory> getBackupDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }
    final backupDir = Directory('${baseDir.path}/NayliKiosk_Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Create a complete, compressed backup snapshot (.zip)
  static Future<File> createFullBackupZip({String? customNote}) async {
    final products = HiveDatabase.productBox.values.map((p) => p.toJson()).toList();
    final invoices = HiveDatabase.invoicesBox.values.toList();
    final customers = HiveDatabase.customersBox.values.toList();
    final settings = {};
    for (var key in HiveDatabase.settingsBox.keys) {
      settings[key.toString()] = HiveDatabase.settingsBox.get(key);
    }
    
    // Commercial documents
    final docBox = HiveDatabase.commercialDocsBox;
    final documents = docBox.values.toList();

    final backupData = {
      'app': 'Nayli Kiosk POS',
      'version': '2.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'customNote': customNote ?? '',
      'stats': {
        'productsCount': products.length,
        'invoicesCount': invoices.length,
        'customersCount': customers.length,
        'documentsCount': documents.length,
      },
      'products': products,
      'invoices': invoices,
      'customers': customers,
      'settings': settings,
      'documents': documents,
    };

    final jsonString = jsonEncode(backupData);
    final jsonBytes = utf8.encode(jsonString);

    // Compress using ZIP
    final archive = Archive();
    archive.addFile(ArchiveFile('nayli_market_database.json', jsonBytes.length, jsonBytes));
    final zipBytes = ZipEncoder().encode(archive);

    final backupDir = await getBackupDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final backupFile = File('${backupDir.path}/Backup_NayliMarket_$dateStr.nbak');
    await backupFile.writeAsBytes(zipBytes!);

    // Check if USB / Secondary drive is available and mirror (async read to avoid blocking UI thread)
    await _mirrorToExternalDrives(await backupFile.readAsBytes(), backupFile.uri.pathSegments.last);

    return backupFile;
  }

  /// Check external removable drives (D:, E:, F:, G:, U:) on Windows
  static Future<void> _mirrorToExternalDrives(Uint8List bytes, String fileName) async {
    if (!Platform.isWindows) return;
    final driveLetters = ['D', 'E', 'F', 'G', 'H', 'U'];
    for (var drive in driveLetters) {
      final driveDir = Directory('$drive:\\NayliMarket_AutoBackups');
      try {
        if (Directory('$drive:\\').existsSync()) {
          if (!driveDir.existsSync()) {
            driveDir.createSync(recursive: true);
          }
          final mirrorFile = File('${driveDir.path}/$fileName');
          await mirrorFile.writeAsBytes(bytes);
          debugPrint('Mirrored backup to $drive:\\');
        }
      } catch (_) {}
    }
  }

  /// List all local backup archives from app directory and external/connected drives safely
  static Future<List<BackupSnapshotInfo>> listLocalBackups() async {
    final list = <BackupSnapshotInfo>[];
    final Set<String> scannedPaths = {};
    final directoriesToScan = <Directory>[];

    // 1. Primary app backup directory
    try {
      final backupDir = await getBackupDirectory();
      directoriesToScan.add(backupDir);
    } catch (_) {}

    // 2. Windows specific backup folders (ONLY dedicated folders, NEVER arbitrary drive roots like C:\ or D:\)
    if (Platform.isWindows) {
      final driveLetters = ['D', 'E', 'F', 'G', 'H', 'C'];
      for (final letter in driveLetters) {
        directoriesToScan.add(Directory('$letter:\\NayliMarket_AutoBackups'));
        directoriesToScan.add(Directory('$letter:\\NayliKiosk_Backups'));
      }
    }

    // 3. User Downloads & Documents
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      directoriesToScan.add(appDocDir);
      final userHome = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userHome != null) {
        directoriesToScan.add(Directory('$userHome/Downloads'));
        directoriesToScan.add(Directory('$userHome/Documents'));
      }
    } catch (_) {}

    for (final dir in directoriesToScan) {
      try {
        if (!dir.existsSync()) continue;

        final isDedicated = dir.path.toLowerCase().contains('nayli') || dir.path.toLowerCase().contains('backup');
        final files = dir.listSync(recursive: false).whereType<File>().where((f) {
          final p = f.path.toLowerCase();
          final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last.toLowerCase() : p;

          if (p.endsWith('.nbak')) return true;
          if (p.endsWith('.zip')) {
            // If in a general folder like Downloads or Documents, strictly require Nayli/Backup in filename
            if (!isDedicated) {
              return name.contains('nayli') || name.contains('backup') || name.contains('kiosk');
            }
            return true;
          }
          return false;
        });

        for (var file in files) {
          final normPath = file.path.toLowerCase();
          if (scannedPaths.contains(normPath)) continue;
          scannedPaths.add(normPath);

          try {
            final stat = file.statSync();
            // Skip files larger than 150MB to prevent memory exhaustion
            if (stat.size > 150 * 1024 * 1024) continue;

            int pCount = 0, iCount = 0, cCount = 0, dCount = 0;

            // Read asynchronously without blocking UI thread
            final bytes = await file.readAsBytes();

            try {
              final archive = ZipDecoder().decodeBytes(bytes, verify: false);
              final jsonFile = archive.findFile('nayli_market_database.json') ??
                  archive.files.where((f) => f.name.endsWith('.json')).firstOrNull;

              if (jsonFile != null) {
                final contentBytes = jsonFile.content as List<int>;
                if (contentBytes.isNotEmpty) {
                  final content = utf8.decode(contentBytes);
                  final map = jsonDecode(content) as Map<String, dynamic>;
                  final stats = map['stats'] as Map<String, dynamic>?;
                  pCount = stats?['productsCount'] ?? (map['products'] as List?)?.length ?? 0;
                  iCount = stats?['invoicesCount'] ?? (map['invoices'] as List?)?.length ?? 0;
                  cCount = stats?['customersCount'] ?? (map['customers'] as List?)?.length ?? 0;
                  dCount = stats?['documentsCount'] ?? (map['documents'] as List?)?.length ?? 0;
                }
              }
            } catch (_) {
              // Try raw JSON format
              try {
                final content = utf8.decode(bytes);
                final map = jsonDecode(content) as Map<String, dynamic>;
                pCount = (map['products'] as List?)?.length ?? 0;
                iCount = (map['invoices'] as List?)?.length ?? 0;
                cCount = (map['customers'] as List?)?.length ?? 0;
              } catch (_) {}
            }

            list.add(BackupSnapshotInfo(
              filePath: file.path,
              fileName: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path,
              fileSize: stat.size,
              createdAt: stat.modified,
              productsCount: pCount,
              invoicesCount: iCount,
              customersCount: cCount,
              documentsCount: dCount,
            ));
          } catch (e) {
            debugPrint('Error reading backup file ${file.path}: $e');
          }
        }
      } catch (_) {}
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Send backup snapshot to Telegram Cloud Vault
  static Future<bool> sendToTelegramBot({
    required File backupFile,
    required String botToken,
    required String chatId,
  }) async {
    try {
      final uri = Uri.parse('https://api.telegram.org/bot$botToken/sendDocument');
      final request = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = chatId
        ..fields['caption'] = '📦 نسخة احتياطية نايل ماركت: ${backupFile.uri.pathSegments.last}\n📅 ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}'
        ..files.add(await http.MultipartFile.fromPath('document', backupFile.path));

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram backup failed: $e');
      return false;
    }
  }

  /// Performs an automatic cloud backup to Telegram if credentials are set
  static Future<bool> performAutoCloudBackup({String? note}) async {
    try {
      final token = TelegramService.getBotToken();
      final chatId = TelegramService.getChatId();
      if (token.isEmpty || chatId.isEmpty) return false;

      final file = await createFullBackupZip(customNote: note ?? 'نسخ سحابي آلي تلقائي');
      return await sendToTelegramBot(
        backupFile: file,
        botToken: token,
        chatId: chatId,
      );
    } catch (e) {
      debugPrint('performAutoCloudBackup error: $e');
      return false;
    }
  }

  /// Scan an arbitrary custom directory for backup files (e.g. from USB / external drive)
  static Future<List<BackupSnapshotInfo>> scanDirectoryForBackups(Directory dir) async {
    final list = <BackupSnapshotInfo>[];
    if (!dir.existsSync()) return list;

    try {
      final files = dir.listSync(recursive: false).whereType<File>().where((f) {
        final p = f.path.toLowerCase();
        return p.endsWith('.nbak') || p.endsWith('.zip') || p.endsWith('.json') || p.endsWith('.csv') || p.endsWith('.txt');
      });

      for (var file in files) {
        try {
          final stat = file.statSync();
          if (stat.size > 150 * 1024 * 1024) continue;

          final analysis = await UniversalDatabaseImporter.analyzeFile(file);
          if (analysis.isValid) {
            list.add(BackupSnapshotInfo(
              filePath: file.path,
              fileName: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path,
              fileSize: stat.size,
              createdAt: stat.modified,
              productsCount: analysis.products.length,
              invoicesCount: analysis.invoices.length,
              customersCount: analysis.customers.length,
              documentsCount: analysis.documents.length,
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Restore Database from any supported backup file (.nbak / .zip / .json / .csv / .txt)
  static Future<bool> restoreDatabaseFromFile(File backupFile, {bool isMergeMode = false}) async {
    final parsed = await UniversalDatabaseImporter.analyzeFile(backupFile);
    if (!parsed.isValid) return false;
    return await UniversalDatabaseImporter.executeRestore(data: parsed, isMergeMode: isMergeMode);
  }
}

/// Structured container holding analyzed contents of any database or catalog file
class ParsedDatabaseData {
  final String fileFormat;
  final String fileName;
  final int fileSize;
  final List<ProductModel> products;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> quickItems;
  final List<Map<String, dynamic>> customerDebts;
  final int imagesDiscoveredCount;
  final bool isValid;
  final String? errorMessage;

  ParsedDatabaseData({
    required this.fileFormat,
    required this.fileName,
    required this.fileSize,
    required this.products,
    this.invoices = const [],
    this.customers = const [],
    this.settings = const {},
    this.documents = const [],
    this.quickItems = const [],
    this.customerDebts = const [],
    this.imagesDiscoveredCount = 0,
    required this.isValid,
    this.errorMessage,
  });

  String get readableSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get totalEntries =>
      products.length + invoices.length + customers.length + documents.length + quickItems.length + customerDebts.length;
}

/// Universal database and multi-POS file analyzer & importer
class UniversalDatabaseImporter {
  /// Analyzes any database or catalog file (.nbak, .zip, .json, .csv, .txt, .db)
  static Future<ParsedDatabaseData> analyzeFile(File file) async {
    if (!file.existsSync()) {
      return ParsedDatabaseData(
        fileFormat: 'unknown',
        fileName: file.path,
        fileSize: 0,
        products: [],
        isValid: false,
        errorMessage: 'الملف غير موجود في المسار المحدد',
      );
    }

    final stat = file.statSync();
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    final ext = fileName.split('.').last.toLowerCase();

    // Prepare app images storage directory
    Directory? imagesDir;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      imagesDir = Directory('${appDir.path}/nayli_kiosk_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    } catch (_) {}

    try {
      final bytes = await file.readAsBytes();

      // 1. ZIP / NBAK archive
      if (ext == 'nbak' || ext == 'zip') {
        return await _analyzeZipArchive(bytes, fileName, stat.size, imagesDir, file.parent);
      }

      // 2. JSON file (Nayli backup or raw products array)
      if (ext == 'json') {
        return await _analyzeJsonFile(bytes, fileName, stat.size, imagesDir, file.parent);
      }

      // 3. CSV or TXT file (from other POS software)
      if (ext == 'csv' || ext == 'txt') {
        return await _analyzeCsvFile(bytes, fileName, stat.size, imagesDir, file.parent);
      }

      // 4. Fallback attempt: try zip first, then JSON, then CSV
      try {
        final zipResult = await _analyzeZipArchive(bytes, fileName, stat.size, imagesDir, file.parent);
        if (zipResult.isValid) return zipResult;
      } catch (_) {}

      try {
        final jsonResult = await _analyzeJsonFile(bytes, fileName, stat.size, imagesDir, file.parent);
        if (jsonResult.isValid) return jsonResult;
      } catch (_) {}

      try {
        final csvResult = await _analyzeCsvFile(bytes, fileName, stat.size, imagesDir, file.parent);
        if (csvResult.isValid) return csvResult;
      } catch (_) {}

      return ParsedDatabaseData(
        fileFormat: ext,
        fileName: fileName,
        fileSize: stat.size,
        products: [],
        isValid: false,
        errorMessage: 'صيغة الملف غير مدعومة أو تعذر قراءة البيانات منها',
      );
    } catch (e) {
      return ParsedDatabaseData(
        fileFormat: ext,
        fileName: fileName,
        fileSize: stat.size,
        products: [],
        isValid: false,
        errorMessage: 'حدث خطأ أثناء فحص الملف: $e',
      );
    }
  }

  /// Analyze ZIP or NBAK archive
  static Future<ParsedDatabaseData> _analyzeZipArchive(
    Uint8List bytes,
    String fileName,
    int fileSize,
    Directory? imagesDir,
    Directory parentDir,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    int imagesDiscovered = 0;

    // 1. Extract embedded images into local vault
    if (imagesDir != null) {
      for (var f in archive.files) {
        if (f.isFile) {
          final p = f.name.toLowerCase();
          if (p.startsWith('images/') || p.endsWith('.jpg') || p.endsWith('.png') || p.endsWith('.jpeg') || p.endsWith('.webp')) {
            final imgName = f.name.split('/').last;
            if (imgName.isNotEmpty) {
              final localFile = File('${imagesDir.path}/$imgName');
              await localFile.writeAsBytes(f.content as List<int>);
              imagesDiscovered++;
            }
          }
        }
      }
    }

    // 2. Look for JSON database file
    final jsonFile = archive.findFile('nayli_market_database.json') ??
        archive.files.where((f) => f.name.endsWith('.json')).firstOrNull;

    if (jsonFile != null) {
      final contentBytes = jsonFile.content as List<int>;
      if (contentBytes.isNotEmpty) {
        final content = utf8.decode(contentBytes);
        final decoded = jsonDecode(content);

        if (decoded is Map<String, dynamic>) {
          return _parseNayliBackupMap(
            decoded,
            fileName,
            fileSize,
            'nbak/zip',
            imagesDiscovered,
            imagesDir,
          );
        } else if (decoded is List) {
          Map<String, String>? matchedImages;
          if (imagesDir != null) {
            try {
              matchedImages = await ProductImageHelper.scanDirectoryForBarcodeImages(parentDir, imagesDir);
            } catch (_) {}
          }
          final products = _parseProductsList(decoded, imagesDir, matchedImages);
          return ParsedDatabaseData(
            fileFormat: 'nbak/zip (json array)',
            fileName: fileName,
            fileSize: fileSize,
            products: products,
            imagesDiscoveredCount: imagesDiscovered,
            isValid: products.isNotEmpty,
          );
        }
      }
    }

    // 3. Look for CSV inside archive
    final csvFile = archive.files.where((f) => f.name.endsWith('.csv') || f.name.endsWith('.txt')).firstOrNull;
    if (csvFile != null) {
      final csvBytes = Uint8List.fromList(csvFile.content as List<int>);
      final csvData = await _analyzeCsvFile(csvBytes, fileName, fileSize, imagesDir, parentDir);
      return ParsedDatabaseData(
        fileFormat: 'zip (csv)',
        fileName: fileName,
        fileSize: fileSize,
        products: csvData.products,
        imagesDiscoveredCount: imagesDiscovered + csvData.imagesDiscoveredCount,
        isValid: csvData.isValid,
      );
    }

    return ParsedDatabaseData(
      fileFormat: 'zip',
      fileName: fileName,
      fileSize: fileSize,
      products: [],
      imagesDiscoveredCount: imagesDiscovered,
      isValid: false,
      errorMessage: 'الأرشيف سليم لكن لم يتم العثور على ملف قاعدة بيانات (.json أو .csv) داخله',
    );
  }

  /// Analyze raw JSON file
  static Future<ParsedDatabaseData> _analyzeJsonFile(
    Uint8List bytes,
    String fileName,
    int fileSize,
    Directory? imagesDir,
    Directory parentDir,
  ) async {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final decoded = jsonDecode(content);
    int imagesDiscovered = 0;

    Map<String, String>? matchedImages;
    // Scan adjacent folder for images matching barcodes
    if (imagesDir != null) {
      try {
        matchedImages = await ProductImageHelper.scanDirectoryForBarcodeImages(parentDir, imagesDir);
        imagesDiscovered = matchedImages.length;
      } catch (_) {}
    }

    if (decoded is Map<String, dynamic>) {
      return _parseNayliBackupMap(decoded, fileName, fileSize, 'json', imagesDiscovered, imagesDir, matchedImages);
    } else if (decoded is List) {
      final products = _parseProductsList(decoded, imagesDir, matchedImages);
      return ParsedDatabaseData(
        fileFormat: 'json',
        fileName: fileName,
        fileSize: fileSize,
        products: products,
        imagesDiscoveredCount: imagesDiscovered,
        isValid: products.isNotEmpty,
      );
    }

    return ParsedDatabaseData(
      fileFormat: 'json',
      fileName: fileName,
      fileSize: fileSize,
      products: [],
      isValid: false,
      errorMessage: 'تنسيق JSON غير متطابق مع أي هيكل بيانات معروف',
    );
  }

  /// Parse Nayli standard backup Map
  static ParsedDatabaseData _parseNayliBackupMap(
    Map<String, dynamic> data,
    String fileName,
    int fileSize,
    String format,
    int imagesDiscovered,
    Directory? imagesDir, [
    Map<String, String>? barcodeToImagePath,
  ]) {
    final products = _parseProductsList(data['products'] as List? ?? [], imagesDir, barcodeToImagePath);

    final invoices = <Map<String, dynamic>>[];
    if (data['invoices'] is List) {
      for (var inv in (data['invoices'] as List)) {
        if (inv is Map) invoices.add(Map<String, dynamic>.from(inv));
      }
    }

    final customers = <Map<String, dynamic>>[];
    if (data['customers'] is List) {
      for (var c in (data['customers'] as List)) {
        if (c is Map) customers.add(Map<String, dynamic>.from(c));
      }
    }

    final documents = <Map<String, dynamic>>[];
    if (data['documents'] is List) {
      for (var d in (data['documents'] as List)) {
        if (d is Map) documents.add(Map<String, dynamic>.from(d));
      }
    }

    final quickItems = <Map<String, dynamic>>[];
    if (data['quick_items'] is List) {
      for (var q in (data['quick_items'] as List)) {
        if (q is Map) quickItems.add(Map<String, dynamic>.from(q));
      }
    }

    final customerDebts = <Map<String, dynamic>>[];
    if (data['customer_debts'] is List) {
      for (var cd in (data['customer_debts'] as List)) {
        if (cd is Map) customerDebts.add(Map<String, dynamic>.from(cd));
      }
    }

    final settings = <String, dynamic>{};
    if (data['settings'] is Map) {
      final s = data['settings'] as Map;
      for (var k in s.keys) {
        settings[k.toString()] = s[k];
      }
    }

    final isValid = products.isNotEmpty || invoices.isNotEmpty || customers.isNotEmpty || documents.isNotEmpty;

    return ParsedDatabaseData(
      fileFormat: format,
      fileName: fileName,
      fileSize: fileSize,
      products: products,
      invoices: invoices,
      customers: customers,
      documents: documents,
      quickItems: quickItems,
      customerDebts: customerDebts,
      settings: settings,
      imagesDiscoveredCount: imagesDiscovered,
      isValid: isValid,
    );
  }

  /// Parse products list from JSON array
  static List<ProductModel> _parseProductsList(List rawList, Directory? imagesDir, [Map<String, String>? barcodeToImagePath]) {
    final products = <ProductModel>[];
    for (var p in rawList) {
      if (p is Map) {
        try {
          final pMap = Map<String, dynamic>.from(p);
          if (pMap['imageUrl'] != null && imagesDir != null) {
            final img = pMap['imageUrl'].toString();
            pMap['imageUrl'] = ProductImageHelper.resolveImagePathSync(img, imagesDir: imagesDir);
          }
          var model = ProductModel.fromJson(pMap);
          if (model.id.isEmpty) {
            final fallbackId = model.barcode.isNotEmpty
                ? model.barcode
                : 'prod_${DateTime.now().microsecondsSinceEpoch}_${products.length}';
            model = model.copyWith(id: fallbackId);
          }
          products.add(model);
        } catch (_) {}
      }
    }
    return products;
  }

  /// Universal Multi-POS CSV & TXT Analyzer
  static Future<ParsedDatabaseData> _analyzeCsvFile(
    Uint8List bytes,
    String fileName,
    int fileSize,
    Directory? imagesDir,
    Directory parentDir,
  ) async {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final lines = content.split(RegExp(r'\r\n|\r|\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return ParsedDatabaseData(
        fileFormat: 'csv',
        fileName: fileName,
        fileSize: fileSize,
        products: [],
        isValid: false,
        errorMessage: 'الملف فارغ لا يحتوي على أي أسطر',
      );
    }

    // 1. Detect Delimiter
    final sampleLines = lines.take(5).toList();
    final counts = {',': 0, ';': 0, '\t': 0, '|': 0};
    for (var line in sampleLines) {
      for (var d in counts.keys) {
        counts[d] = counts[d]! + RegExp(RegExp.escape(d)).allMatches(line).length;
      }
    }
    var bestDelimiter = ';';
    int maxCount = -1;
    for (var entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        bestDelimiter = entry.key;
      }
    }

    // 2. Discover adjacent images
    Map<String, String> adjacentImages = {};
    if (imagesDir != null) {
      try {
        adjacentImages = await ProductImageHelper.scanDirectoryForBarcodeImages(parentDir, imagesDir);
      } catch (_) {}
    }

    // 3. Detect Header Line & Column Mapping
    final headerRow = _splitCsvLine(lines[0], bestDelimiter);
    final colMap = _detectColumns(headerRow);

    final hasBarcode = colMap.containsKey('barcode');
    final hasName = colMap.containsKey('name');

    int startRow = 1;
    // If first row didn't look like a header, treat it as data if columns look numeric/alphanumeric
    if (!hasBarcode && !hasName) {
      startRow = 0;
      // Default heuristic: col 0 = barcode, col 1 = name, col 2 = price, col 3 = cost, col 4 = stock
      colMap['barcode'] = 0;
      colMap['name'] = 1;
      if (headerRow.length > 2) colMap['price'] = 2;
      if (headerRow.length > 3) colMap['cost'] = 3;
      if (headerRow.length > 4) colMap['stock'] = 4;
    }

    final products = <ProductModel>[];
    for (int i = startRow; i < lines.length; i++) {
      final row = _splitCsvLine(lines[i], bestDelimiter);
      if (row.isEmpty) continue;

      String barcode = '';
      if (colMap.containsKey('barcode') && colMap['barcode']! < row.length) {
        barcode = row[colMap['barcode']!].trim();
      }

      String name = '';
      if (colMap.containsKey('name') && colMap['name']! < row.length) {
        name = row[colMap['name']!].trim();
      }

      if (barcode.isEmpty && name.isEmpty) continue;
      if (name.isEmpty && barcode.isNotEmpty) name = 'سلعة $barcode';
      if (barcode.isEmpty) barcode = 'GEN_${DateTime.now().microsecondsSinceEpoch}_${products.length}';

      double price = 0.0;
      if (colMap.containsKey('price') && colMap['price']! < row.length) {
        price = _parsePrice(row[colMap['price']!]);
      }

      double cost = 0.0;
      if (colMap.containsKey('cost') && colMap['cost']! < row.length) {
        cost = _parsePrice(row[colMap['cost']!]);
      }

      double wholesale = 0.0;
      if (colMap.containsKey('wholesale') && colMap['wholesale']! < row.length) {
        wholesale = _parsePrice(row[colMap['wholesale']!]);
      }

      int stock = 0;
      if (colMap.containsKey('stock') && colMap['stock']! < row.length) {
        final parsed = _parsePrice(row[colMap['stock']!]);
        stock = parsed.toInt();
      }

      String category = 'عام';
      if (colMap.containsKey('category') && colMap['category']! < row.length) {
        final cat = row[colMap['category']!].trim();
        if (cat.isNotEmpty) category = cat;
      }

      String unit = 'قطعة';
      if (colMap.containsKey('unit') && colMap['unit']! < row.length) {
        final u = row[colMap['unit']!].trim();
        if (u.isNotEmpty) unit = u;
      }

      String? imageUrl;
      if (colMap.containsKey('image') && colMap['image']! < row.length) {
        final img = row[colMap['image']!].trim();
        if (img.isNotEmpty) {
          imageUrl = ProductImageHelper.resolveImagePathSync(img, imagesDir: imagesDir);
        }
      }
      // Check adjacent discovered image if no image URL in CSV
      if (imageUrl == null && adjacentImages.containsKey(barcode)) {
        imageUrl = adjacentImages[barcode];
      }

      final product = ProductModel(
        id: barcode,
        name: name,
        barcode: barcode,
        price: price,
        costPrice: cost,
        stock: stock,
        category: category,
        imageUrl: imageUrl,
        unitType: unit,
        wholesalePrice: wholesale > 0 ? wholesale : price,
      );

      products.add(product);
    }

    return ParsedDatabaseData(
      fileFormat: 'csv ($bestDelimiter)',
      fileName: fileName,
      fileSize: fileSize,
      products: products,
      imagesDiscoveredCount: adjacentImages.length,
      isValid: products.isNotEmpty,
      errorMessage: products.isEmpty ? 'لم يتم استخراج أي سلع صالحة من ملف CSV' : null,
    );
  }

  /// Detect column indices using multi-language synonyms across Arabic, French, English, and old POS software
  static Map<String, int> _detectColumns(List<String> headers) {
    final map = <String, int>{};

    final barcodeSynonyms = [
      'barcode', 'codebarre', 'code_barre', 'code-barres', 'code', 'reference',
      'ref', 'ean', 'ean13', 'cb', 'باركود', 'الرمز', 'كود', 'رمز_السلعة', 'رمز'
    ];
    final nameSynonyms = [
      'name', 'product_name', 'nom', 'designation', 'libelle', 'libellé',
      'article', 'item', 'description', 'الاسم', 'اسم_السلعة', 'اسم المنتج',
      'التعيين', 'البيان', 'السلعة'
    ];
    final priceSynonyms = [
      'price', 'sale_price', 'prix', 'prix_vente', 'pv', 'pv_ttc', 'pu_ttc',
      'detail', 'prix_detail', 'السعر', 'سعر_البيع', 'سعر_التجزئة', 'سعر البيع', 'بيع'
    ];
    final costSynonyms = [
      'cost', 'cost_price', 'prix_achat', 'pa', 'pa_ht', 'achat', 'pachat',
      'cout', 'سعر_الشراء', 'سعر_التكلفة', 'الشراء', 'سعر الشراء'
    ];
    final wholesaleSynonyms = [
      'wholesale', 'wholesale_price', 'prix_gros', 'gros', 'demi_gros',
      'الجملة', 'سعر_الجملة', 'سعر الجملة'
    ];
    final stockSynonyms = [
      'stock', 'quantity', 'qty', 'qte', 'qte_stock', 'quantite', 'quantité',
      'stock_actuel', 'المخزون', 'الكمية', 'الرصيد', 'المتبقي'
    ];
    final categorySynonyms = [
      'category', 'categorie', 'famille', 'rayon', 'departement',
      'القسم', 'الصنف', 'العائلة', 'التصنيف'
    ];
    final unitSynonyms = [
      'unit', 'unite', 'unité', 'mesure', 'الوحدة', 'وحدة'
    ];
    final imageSynonyms = [
      'image', 'imageurl', 'photo', 'picture', 'img', 'صورة', 'الصورة'
    ];

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');
      if (h.isEmpty) continue;

      if (!map.containsKey('barcode') && barcodeSynonyms.any((s) => h.contains(s))) {
        map['barcode'] = i;
      } else if (!map.containsKey('name') && nameSynonyms.any((s) => h.contains(s))) {
        map['name'] = i;
      } else if (!map.containsKey('cost') && costSynonyms.any((s) => h.contains(s))) {
        map['cost'] = i;
      } else if (!map.containsKey('wholesale') && wholesaleSynonyms.any((s) => h.contains(s))) {
        map['wholesale'] = i;
      } else if (!map.containsKey('price') && priceSynonyms.any((s) => h.contains(s))) {
        map['price'] = i;
      } else if (!map.containsKey('stock') && stockSynonyms.any((s) => h.contains(s))) {
        map['stock'] = i;
      } else if (!map.containsKey('category') && categorySynonyms.any((s) => h.contains(s))) {
        map['category'] = i;
      } else if (!map.containsKey('unit') && unitSynonyms.any((s) => h.contains(s))) {
        map['unit'] = i;
      } else if (!map.containsKey('image') && imageSynonyms.any((s) => h.contains(s))) {
        map['image'] = i;
      }
    }

    return map;
  }

  /// Parses numeric price or stock safely
  static double _parsePrice(String val) {
    var clean = val.trim().replaceAll(' ', '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Clean CSV line splitter handling quoted strings
  static List<String> _splitCsvLine(String line, String delimiter) {
    final result = <String>[];
    final sb = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == delimiter && !insideQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString());
    return result.map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
  }

  /// Execute restore / import with either Full Replace or Smart Merge
  static Future<bool> executeRestore({
    required ParsedDatabaseData data,
    required bool isMergeMode,
  }) async {
    if (!data.isValid) return false;

    try {
      // 1. Products
      if (data.products.isNotEmpty) {
        if (!isMergeMode) {
          await HiveDatabase.productBox.clear();
          for (var p in data.products) {
            await HiveDatabase.productBox.put(p.id, p);
          }
        } else {
          // Smart merge: update existing by barcode or ID, add new ones
          final existingBarcodeMap = <String, String>{};
          for (var key in HiveDatabase.productBox.keys) {
            final p = HiveDatabase.productBox.get(key);
            if (p != null && p.barcode.isNotEmpty) {
              existingBarcodeMap[p.barcode.trim()] = key.toString();
            }
          }

          for (var p in data.products) {
            final barcode = p.barcode.trim();
            final existingKey = existingBarcodeMap[barcode] ?? (HiveDatabase.productBox.containsKey(p.id) ? p.id : null);

            if (existingKey != null) {
              final existing = HiveDatabase.productBox.get(existingKey);
              if (existing != null) {
                final merged = existing.copyWith(
                  name: p.name.isNotEmpty ? p.name : existing.name,
                  price: p.price > 0 ? p.price : existing.price,
                  costPrice: p.costPrice > 0 ? p.costPrice : existing.costPrice,
                  stock: existing.stock + p.stock,
                  category: p.category != 'عام' ? p.category : existing.category,
                  imageUrl: (p.imageUrl != null && p.imageUrl!.isNotEmpty) ? p.imageUrl : existing.imageUrl,
                  wholesalePrice: p.wholesalePrice > 0 ? p.wholesalePrice : existing.wholesalePrice,
                  unitType: p.unitType.isNotEmpty ? p.unitType : existing.unitType,
                );
                await HiveDatabase.productBox.put(existingKey, merged);
              }
            } else {
              await HiveDatabase.productBox.put(p.id, p);
            }
          }
        }
      }

      // 2. Invoices (only in full replace or append if missing)
      if (data.invoices.isNotEmpty) {
        if (!isMergeMode) {
          await HiveDatabase.invoicesBox.clear();
          for (var inv in data.invoices) {
            final id = inv['id']?.toString() ?? inv['invoiceNumber']?.toString() ?? inv['reference']?.toString();
            if (id != null && id.isNotEmpty) {
              await HiveDatabase.invoicesBox.put(id, inv);
            }
          }
        } else {
          for (var inv in data.invoices) {
            final id = inv['id']?.toString() ?? inv['invoiceNumber']?.toString() ?? inv['reference']?.toString();
            if (id != null && id.isNotEmpty && !HiveDatabase.invoicesBox.containsKey(id)) {
              await HiveDatabase.invoicesBox.put(id, inv);
            }
          }
        }
      }

      // 3. Customers
      if (data.customers.isNotEmpty) {
        if (!isMergeMode) {
          await HiveDatabase.customersBox.clear();
          for (var c in data.customers) {
            final id = c['id']?.toString() ?? c['name']?.toString();
            if (id != null && id.isNotEmpty) {
              await HiveDatabase.customersBox.put(id, c);
            }
          }
        } else {
          for (var c in data.customers) {
            final id = c['id']?.toString() ?? c['name']?.toString();
            if (id != null && id.isNotEmpty) {
              await HiveDatabase.customersBox.put(id, c);
            }
          }
        }
      }

      // 4. Commercial Documents
      if (data.documents.isNotEmpty) {
        final docBox = HiveDatabase.commercialDocsBox;
        if (!isMergeMode) {
          await docBox.clear();
          for (var d in data.documents) {
            final id = d['id']?.toString() ?? d['reference']?.toString();
            if (id != null && id.isNotEmpty) {
              await docBox.put(id, d);
            }
          }
        } else {
          for (var d in data.documents) {
            final id = d['id']?.toString() ?? d['reference']?.toString();
            if (id != null && id.isNotEmpty && !docBox.containsKey(id)) {
              await docBox.put(id, d);
            }
          }
        }
      }

      // 5. Settings (only restore in full replace mode, preserving machine identity)
      if (!isMergeMode && data.settings.isNotEmpty) {
        for (var key in data.settings.keys) {
          final k = key.toString();
          if (k == 'device_id' || k == 'hardware_fingerprint' || k == 'window_size') continue;
          try {
            await HiveDatabase.settingsBox.put(k, data.settings[key]);
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      debugPrint('Restore execution error: $e');
      return false;
    }
  }
}


