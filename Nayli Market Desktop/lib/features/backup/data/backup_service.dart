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

    // Package local images
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${docDir.path}/NayliMarket/images');
      if (await imgDir.exists()) {
        final imageFiles = imgDir.listSync(recursive: false);
        for (final entity in imageFiles) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            final imgBytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile('images/$fileName', imgBytes.length, imgBytes));
          }
        }
      }
    } catch (e) {
      debugPrint('Error packaging images: $e');
    }

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

  /// Restore Database from a backup file (.nbak / .zip / .json) safely and atomically
  static Future<bool> restoreDatabaseFromFile(File backupFile) async {
    try {
      if (!backupFile.existsSync()) return false;
      final bytes = await backupFile.readAsBytes();

      Map<String, dynamic>? data;

      // Setup images directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/NayliMarket/images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      // 1. Try reading as zip archive
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final jsonFile = archive.findFile('nayli_market_database.json') ??
            archive.files.where((f) => f.name.endsWith('.json')).firstOrNull;

        if (jsonFile != null) {
          final contentBytes = jsonFile.content as List<int>;
          if (contentBytes.isNotEmpty) {
            final content = utf8.decode(contentBytes);
            final decoded = jsonDecode(content);
            if (decoded is Map) {
              data = Map<String, dynamic>.from(decoded);
            }

            // Extract embedded images
            for (var file in archive.files) {
              if (file.isFile && file.name.startsWith('images/')) {
                final fileName = file.name.split('/').last;
                if (fileName.isNotEmpty) {
                  final imgBytes = file.content as List<int>;
                  if (imgBytes.isNotEmpty) {
                    final localFile = File('${imagesDir.path}/$fileName');
                    await localFile.writeAsBytes(imgBytes);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Zip extraction notice: $e');
      }

      // 2. If not zip or archive extraction produced no data, try raw JSON text
      if (data == null) {
        try {
          final content = utf8.decode(bytes);
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      if (data == null) {
        debugPrint('Failed to extract valid JSON data from backup file');
        return false;
      }

      // 3. Restore Products safely & atomically
      if (data['products'] is List) {
        final rawList = data['products'] as List;
        final parsedModels = <ProductModel>[];
        for (var p in rawList) {
          if (p is Map) {
            try {
              final pMap = Map<String, dynamic>.from(p);
              if (pMap['imageUrl'] != null) {
                String img = pMap['imageUrl'].toString();
                if (!img.startsWith('http')) {
                  final filename = img.split(RegExp(r'[\\/]')).last;
                  if (filename.isNotEmpty) {
                    pMap['imageUrl'] = filename; // Only save the relative filename
                  }
                }
              }
              var model = ProductModel.fromJson(pMap);
              if (model.id.isEmpty) {
                final fallbackId = model.barcode.isNotEmpty ? model.barcode : 'prod_${DateTime.now().microsecondsSinceEpoch}_${parsedModels.length}';
                model = model.copyWith(id: fallbackId);
              }
              parsedModels.add(model);
            } catch (err) {
              debugPrint('Warning: Skipped corrupted product entry: $err');
            }
          }
        }

        if (parsedModels.isNotEmpty || rawList.isEmpty) {
          await HiveDatabase.productBox.clear();
          for (var model in parsedModels) {
            await HiveDatabase.productBox.put(model.id, model);
          }
        }
      }

      // 4. Restore Invoices safely
      if (data['invoices'] is List) {
        final parsedInvoices = <String, Map<String, dynamic>>{};
        for (var inv in (data['invoices'] as List)) {
          if (inv is Map) {
            try {
              final invMap = Map<String, dynamic>.from(inv);
              final id = invMap['id']?.toString() ?? invMap['invoiceNumber']?.toString() ?? invMap['reference']?.toString();
              if (id != null && id.isNotEmpty) {
                parsedInvoices[id] = invMap;
              }
            } catch (_) {}
          }
        }
        await HiveDatabase.invoicesBox.clear();
        for (var entry in parsedInvoices.entries) {
          await HiveDatabase.invoicesBox.put(entry.key, entry.value);
        }
      }

      // 5. Restore Customers safely
      if (data['customers'] is List) {
        final parsedCustomers = <String, Map<String, dynamic>>{};
        for (var c in (data['customers'] as List)) {
          if (c is Map) {
            try {
              final cMap = Map<String, dynamic>.from(c);
              final id = cMap['id']?.toString() ?? cMap['name']?.toString();
              if (id != null && id.isNotEmpty) {
                parsedCustomers[id] = cMap;
              }
            } catch (_) {}
          }
        }
        await HiveDatabase.customersBox.clear();
        for (var entry in parsedCustomers.entries) {
          await HiveDatabase.customersBox.put(entry.key, entry.value);
        }
      }

      // 6. Restore Commercial Documents safely
      if (data['documents'] is List) {
        final docBox = HiveDatabase.commercialDocsBox;
        final parsedDocs = <String, Map<String, dynamic>>{};
        for (var doc in (data['documents'] as List)) {
          if (doc is Map) {
            try {
              final docMap = Map<String, dynamic>.from(doc);
              final id = docMap['id']?.toString() ?? docMap['reference']?.toString();
              if (id != null && id.isNotEmpty) {
                parsedDocs[id] = docMap;
              }
            } catch (_) {}
          }
        }
        await docBox.clear();
        for (var entry in parsedDocs.entries) {
          await docBox.put(entry.key, entry.value);
        }
      }

      // 7. Restore Quick Items safely
      if (data['quick_items'] is List) {
        final quickBox = HiveDatabase.quickItemsBox;
        final parsedQuick = <Map<String, dynamic>>[];
        for (var q in (data['quick_items'] as List)) {
          if (q is Map) {
            try {
              parsedQuick.add(Map<String, dynamic>.from(q));
            } catch (_) {}
          }
        }
        await quickBox.clear();
        for (var item in parsedQuick) {
          await quickBox.add(item);
        }
      }

      // 8. Restore Customer Debts safely
      if (data['customer_debts'] is List) {
        final debtBox = HiveDatabase.customerDebtsBox;
        final parsedDebts = <Map<String, dynamic>>[];
        for (var d in (data['customer_debts'] as List)) {
          if (d is Map) {
            try {
              parsedDebts.add(Map<String, dynamic>.from(d));
            } catch (_) {}
          }
        }
        await debtBox.clear();
        for (var item in parsedDebts) {
          await debtBox.add(item);
        }
      }

      // 9. Restore Settings safely (preserve machine identity)
      if (data['settings'] is Map) {
        final setMap = data['settings'] as Map;
        for (var key in setMap.keys) {
          final k = key.toString();
          if (k == 'device_id' || k == 'hardware_fingerprint' || k == 'window_size') continue;
          try {
            await HiveDatabase.settingsBox.put(k, setMap[key]);
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}

