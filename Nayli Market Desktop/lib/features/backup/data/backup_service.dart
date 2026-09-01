import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';
import '../documents/data/document_service.dart';

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
}

class BackupService {
  /// Get dedicated local backup directory
  static Future<Directory> getBackupDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }
    final backupDir = Directory('${baseDir.path}/NayliMarket_Backups');
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
    final docBox = await DocumentService.box;
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

  /// List all local backup archives
  static Future<List<BackupSnapshotInfo>> listLocalBackups() async {
    final backupDir = await getBackupDirectory();
    final list = <BackupSnapshotInfo>[];

    final files = backupDir.listSync().whereType<File>().where((f) => f.path.endsWith('.nbak') || f.path.endsWith('.zip'));

    for (var file in files) {
      try {
        final stat = file.statSync();
        final bytes = file.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        final jsonFile = archive.findFile('nayli_market_database.json');
        
        int pCount = 0, iCount = 0, cCount = 0, dCount = 0;
        if (jsonFile != null) {
          final content = utf8.decode(jsonFile.content as List<int>);
          final map = jsonDecode(content) as Map<String, dynamic>;
          final stats = map['stats'] as Map<String, dynamic>?;
          pCount = stats?['productsCount'] ?? (map['products'] as List?)?.length ?? 0;
          iCount = stats?['invoicesCount'] ?? (map['invoices'] as List?)?.length ?? 0;
          cCount = stats?['customersCount'] ?? (map['customers'] as List?)?.length ?? 0;
          dCount = stats?['documentsCount'] ?? (map['documents'] as List?)?.length ?? 0;
        }

        list.add(BackupSnapshotInfo(
          filePath: file.path,
          fileName: file.uri.pathSegments.last,
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

  /// Restore Database from a backup file (.nbak / .zip)
  static Future<bool> restoreDatabaseFromFile(File backupFile) async {
    try {
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final jsonFile = archive.findFile('nayli_market_database.json');
      if (jsonFile == null) return false;

      final content = utf8.decode(jsonFile.content as List<int>);
      final data = jsonDecode(content) as Map<String, dynamic>;

      // 1. Restore Products
      if (data['products'] is List) {
        await HiveDatabase.productBox.clear();
        for (var p in (data['products'] as List)) {
          final id = p['id']?.toString() ?? p['barcode']?.toString();
          if (id != null) {
            await HiveDatabase.productBox.put(id, p);
          }
        }
      }

      // 2. Restore Invoices
      if (data['invoices'] is List) {
        await HiveDatabase.invoicesBox.clear();
        for (var inv in (data['invoices'] as List)) {
          final id = inv['id']?.toString() ?? inv['invoiceNumber']?.toString();
          if (id != null) {
            await HiveDatabase.invoicesBox.put(id, inv);
          }
        }
      }

      // 3. Restore Customers
      if (data['customers'] is List) {
        await HiveDatabase.customersBox.clear();
        for (var c in (data['customers'] as List)) {
          final id = c['id']?.toString() ?? c['name']?.toString();
          if (id != null) {
            await HiveDatabase.customersBox.put(id, c);
          }
        }
      }

      // 4. Restore Documents
      if (data['documents'] is List) {
        final docBox = await DocumentService.box;
        await docBox.clear();
        for (var doc in (data['documents'] as List)) {
          final id = doc['id']?.toString() ?? doc['reference']?.toString();
          if (id != null) {
            await docBox.put(id, doc);
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
