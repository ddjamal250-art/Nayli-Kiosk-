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
import '../../documents/data/commercial_document_service.dart';

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
      'app': 'Nayli Market POS',
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

    // Check if USB / Secondary drive is available and mirror
    await _mirrorToExternalDrives(backupFile.readAsBytesSync(), backupFile.uri.pathSegments.last);

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

  /// List all local backup archives from app directory and external/connected drives
  static Future<List<BackupSnapshotInfo>> listLocalBackups() async {
    final list = <BackupSnapshotInfo>[];
    final Set<String> scannedPaths = {};

    final directoriesToScan = <Directory>[];

    // 1. Primary app backup directory
    try {
      final backupDir = await getBackupDirectory();
      directoriesToScan.add(backupDir);
    } catch (_) {}

    // 2. Common external backup locations on Windows / Android
    if (Platform.isWindows) {
      final driveLetters = ['G', 'D', 'E', 'F', 'H', 'C'];
      for (final letter in driveLetters) {
        directoriesToScan.add(Directory('$letter:\\data'));
        directoriesToScan.add(Directory('$letter:\\NayliMarket_AutoBackups'));
        directoriesToScan.add(Directory('$letter:\\'));
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
        final files = dir
            .listSync(recursive: false)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.nbak') || f.path.toLowerCase().endsWith('.zip'));

        for (var file in files) {
          final normPath = file.path.toLowerCase();
          if (scannedPaths.contains(normPath)) continue;
          scannedPaths.add(normPath);

          try {
            final stat = file.statSync();
            final bytes = file.readAsBytesSync();
            int pCount = 0, iCount = 0, cCount = 0, dCount = 0;

            try {
              final archive = ZipDecoder().decodeBytes(bytes);
              final jsonFile = archive.findFile('nayli_market_database.json') ??
                  archive.files.where((f) => f.name.endsWith('.json')).firstOrNull;

              if (jsonFile != null) {
                final content = utf8.decode(jsonFile.content as List<int>);
                final map = jsonDecode(content) as Map<String, dynamic>;
                final stats = map['stats'] as Map<String, dynamic>?;
                pCount = stats?['productsCount'] ?? (map['products'] as List?)?.length ?? 0;
                iCount = stats?['invoicesCount'] ?? (map['invoices'] as List?)?.length ?? 0;
                cCount = stats?['customersCount'] ?? (map['customers'] as List?)?.length ?? 0;
                dCount = stats?['documentsCount'] ?? (map['documents'] as List?)?.length ?? 0;
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

  /// Restore Database from a backup file (.nbak / .zip / .json)
  static Future<bool> restoreDatabaseFromFile(File backupFile) async {
    try {
      if (!backupFile.existsSync()) return false;
      final bytes = await backupFile.readAsBytes();

      Map<String, dynamic>? data;

      // Setup images directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/nayli_kiosk_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      // Try reading as zip archive
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        final jsonFile = archive.findFile('nayli_market_database.json') ??
            archive.files.where((f) => f.name.endsWith('.json')).firstOrNull;

        if (jsonFile != null) {
          final content = utf8.decode(jsonFile.content as List<int>);
          data = jsonDecode(content) as Map<String, dynamic>;

          // Extract embedded images
          for (var file in archive.files) {
            if (file.isFile && file.name.startsWith('images/')) {
              final fileName = file.name.split('/').last;
              if (fileName.isNotEmpty) {
                final localFile = File('${imagesDir.path}/$fileName');
                await localFile.writeAsBytes(file.content as List<int>);
              }
            }
          }
        }
      } catch (_) {
        // Not a zip, fallback to raw UTF-8 JSON text
      }

      // If not zip or archive extraction produced no data, try raw JSON
      if (data == null) {
        final content = utf8.decode(bytes);
        data = jsonDecode(content) as Map<String, dynamic>;
      }

      // 1. Restore Products safely as ProductModel instances
      if (data['products'] is List) {
        await HiveDatabase.productBox.clear();
        for (var p in (data['products'] as List)) {
          if (p is Map) {
            final pMap = Map<String, dynamic>.from(p);
            // Rewrite local image filenames to absolute path for the current device
            if (pMap['imageUrl'] != null) {
              String img = pMap['imageUrl'].toString();
              if (!img.startsWith('http') && !img.contains('/') && !img.contains('\\')) {
                pMap['imageUrl'] = '${imagesDir.path}/$img';
              }
            }
            final model = ProductModel.fromJson(pMap);
            await HiveDatabase.productBox.put(model.id, model);
          }
        }
      }

      // 2. Restore Invoices
      if (data['invoices'] is List) {
        await HiveDatabase.invoicesBox.clear();
        for (var inv in (data['invoices'] as List)) {
          if (inv is Map) {
            final id = inv['id']?.toString() ?? inv['invoiceNumber']?.toString() ?? inv['reference']?.toString();
            if (id != null) {
              await HiveDatabase.invoicesBox.put(id, Map<String, dynamic>.from(inv));
            }
          }
        }
      }

      // 3. Restore Customers
      if (data['customers'] is List) {
        await HiveDatabase.customersBox.clear();
        for (var c in (data['customers'] as List)) {
          if (c is Map) {
            final id = c['id']?.toString() ?? c['name']?.toString();
            if (id != null) {
              await HiveDatabase.customersBox.put(id, Map<String, dynamic>.from(c));
            }
          }
        }
      }

      // 4. Restore Documents
      if (data['documents'] is List) {
        final docBox = HiveDatabase.commercialDocsBox;
        await docBox.clear();
        for (var doc in (data['documents'] as List)) {
          if (doc is Map) {
            final id = doc['id']?.toString() ?? doc['reference']?.toString();
            if (id != null) {
              await docBox.put(id, Map<String, dynamic>.from(doc));
            }
          }
        }
      }

      // 5. Restore Quick Items
      if (data['quick_items'] is List) {
        final quickBox = HiveDatabase.quickItemsBox;
        await quickBox.clear();
        for (var q in (data['quick_items'] as List)) {
          if (q is Map) {
            await quickBox.add(Map<String, dynamic>.from(q));
          }
        }
      }

      // 6. Restore Customer Debts
      if (data['customer_debts'] is List) {
        final debtBox = HiveDatabase.customerDebtsBox;
        await debtBox.clear();
        for (var d in (data['customer_debts'] as List)) {
          if (d is Map) {
            await debtBox.add(Map<String, dynamic>.from(d));
          }
        }
      }

      // 7. Restore Settings
      if (data['settings'] is Map) {
        final setMap = data['settings'] as Map;
        for (var key in setMap.keys) {
          await HiveDatabase.settingsBox.put(key, setMap[key]);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}

