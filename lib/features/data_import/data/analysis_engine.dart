import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'import_result.dart';
import 'field_mapper.dart';
import 'data_sanitizer.dart';

class AnalysisEngine {
  /// يحلل ملف قاعدة البيانات ويبث أحداث التقدم.
  /// يدعم: .sqlite, .db, .zip (يفك الضغط ويبحث عن SQLite بداخله)
  Stream<AnalysisEvent> analyze(String filePath) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      yield AnalysisEvent(phase: 'error', progress: 0, message: '❌ الملف غير موجود', icon: '❌');
      return;
    }

    String dbPath = filePath;

    // --- كشف ZIP وفك الضغط ---
    if (filePath.toLowerCase().endsWith('.zip')) {
      yield AnalysisEvent(phase: 'discovery', progress: 0.02, message: '📦 جاري فك ضغط الملف...', icon: '📦');
      try {
        final extractDir = await _extractZip(file);
        final sqliteFile = await _findSqliteInDir(extractDir);
        if (sqliteFile == null) {
          yield AnalysisEvent(phase: 'error', progress: 0, message: '❌ لم يتم العثور على قاعدة بيانات داخل الأرشيف', icon: '❌');
          return;
        }
        dbPath = sqliteFile.path;
        yield AnalysisEvent(phase: 'discovery', progress: 0.08, message: '✅ تم اكتشاف: ${sqliteFile.uri.pathSegments.last}', icon: '✅');
      } catch (e) {
        yield AnalysisEvent(phase: 'error', progress: 0, message: '❌ فشل فك الضغط: $e', icon: '❌');
        return;
      }
    }

    // --- فتح قاعدة البيانات ---
    yield AnalysisEvent(phase: 'discovery', progress: 0.10, message: '🔍 جاري فتح قاعدة البيانات...', icon: '🔍');

    sql.Database db;
    try {
      db = sql.sqlite3.open(dbPath);
    } catch (e) {
      yield AnalysisEvent(phase: 'error', progress: 0, message: '❌ الملف ليس قاعدة بيانات صالحة: $e', icon: '❌');
      return;
    }

    try {
      // --- اكتشاف الجداول ---
      final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence';");
      final tableNames = tables.map((r) => r['name'] as String).toList();
      yield AnalysisEvent(phase: 'discovery', progress: 0.15, message: '✅ تم اكتشاف ${tableNames.length} جدول', icon: '✅');

      // --- تصنيف كل جدول ---
      final discoveredTables = <DiscoveredTable>[];
      int customersCount = 0, suppliersCount = 0, productsCount = 0, categoriesCount = 0;
      String? customersTable, suppliersTable, productsTable, categoriesTable;
      String? paymentsTable, salesTable;

      for (int i = 0; i < tableNames.length; i++) {
        final tName = tableNames[i];
        final progress = 0.20 + (0.30 * i / tableNames.length);

        // قراءة أعمدة الجدول
        final colsResult = db.select("PRAGMA table_info('$tName');");
        final columns = colsResult.map((r) => ColumnInfo(
          name: r['name'] as String,
          type: r['type'] as String,
          isNullable: (r['notnull'] as int) == 0,
        )).toList();

        // عدد الصفوف
        final countResult = db.select("SELECT COUNT(*) as c FROM '$tName';");
        final rowCount = countResult.first['c'] as int;

        // تصنيف ذكي
        final type = SmartFieldMapper.classifyTable(tName, columns);
        discoveredTables.add(DiscoveredTable(name: tName, type: type, columns: columns, rowCount: rowCount));

        switch (type) {
          case TableType.customers:
            customersTable = tName;
            customersCount = rowCount;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '👤 تم التعرف على جدول الزبائن: $tName ($rowCount)', icon: '👤');
            break;
          case TableType.suppliers:
            suppliersTable = tName;
            suppliersCount = rowCount;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '🏭 تم التعرف على جدول الموردين: $tName ($rowCount)', icon: '🏭');
            break;
          case TableType.products:
            productsTable = tName;
            productsCount = rowCount;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '📦 تم التعرف على جدول المنتجات: $tName ($rowCount)', icon: '📦');
            break;
          case TableType.categories:
            categoriesTable = tName;
            categoriesCount = rowCount;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '🏷️ تم التعرف على جدول الأصناف: $tName ($rowCount)', icon: '🏷️');
            break;
          case TableType.payments:
            paymentsTable = tName;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '💳 تم التعرف على جدول المدفوعات: $tName ($rowCount)', icon: '💳');
            break;
          case TableType.sales:
            salesTable = tName;
            yield AnalysisEvent(phase: 'classify', progress: progress, message: '🧾 تم التعرف على جدول المبيعات: $tName ($rowCount)', icon: '🧾');
            break;
          default:
            break;
        }
      }

      // --- حساب الديون ---
      yield AnalysisEvent(phase: 'debts', progress: 0.60, message: '💰 جاري حساب ديون الزبائن والموردين...', icon: '💰');

      final customerDebts = <int, double>{};
      final supplierDebts = <int, double>{};

      // ديون الزبائن
      if (customersTable != null && salesTable != null && paymentsTable != null) {
        try {
          final debtQuery = '''
            SELECT c.id, c.name,
              COALESCE(s.total_sales, 0) - COALESCE(p.total_paid, 0) as debt
            FROM '$customersTable' c
            LEFT JOIN (
              SELECT clientId, SUM(total) as total_sales
              FROM '$salesTable' WHERE clientId IS NOT NULL GROUP BY clientId
            ) s ON c.id = s.clientId
            LEFT JOIN (
              SELECT clientId, SUM(value) as total_paid
              FROM '$paymentsTable' WHERE clientId IS NOT NULL GROUP BY clientId
            ) p ON c.id = p.clientId
          ''';
          final debtResults = db.select(debtQuery);
          for (final row in debtResults) {
            final id = row['id'] as int;
            final name = row['name']?.toString() ?? '';
            final debt = DataSanitizer.sanitizeDebt(row['debt']);
            if (debt > 0) {
              customerDebts[id] = debt;
              yield AnalysisEvent(phase: 'debts', progress: 0.70, message: '💰 الزبون "$name": دين = ${debt.toStringAsFixed(0)} دج', icon: '💰');
            }
          }
        } catch (e) {
          yield AnalysisEvent(phase: 'debts', progress: 0.70, message: '⚠️ تعذر حساب ديون الزبائن: $e', icon: '⚠️');
        }
      }

      // ديون الموردين
      if (suppliersTable != null && paymentsTable != null) {
        try {
          final hasSupplierPurchases = tableNames.contains('purchases');
          if (hasSupplierPurchases) {
            final debtQuery = '''
              SELECT s.id, s.name,
                COALESCE(pu.total_purchases, 0) - COALESCE(pa.total_paid, 0) as debt
              FROM '$suppliersTable' s
              LEFT JOIN (
                SELECT supplierId, SUM(total) as total_purchases
                FROM purchases WHERE supplierId IS NOT NULL GROUP BY supplierId
              ) pu ON s.id = pu.supplierId
              LEFT JOIN (
                SELECT supplierId, SUM(value) as total_paid
                FROM '$paymentsTable' WHERE supplierId IS NOT NULL GROUP BY supplierId
              ) pa ON s.id = pa.supplierId
            ''';
            final debtResults = db.select(debtQuery);
            for (final row in debtResults) {
              final id = row['id'] as int;
              final debt = DataSanitizer.sanitizeDebt(row['debt']);
              if (debt > 0) supplierDebts[id] = debt;
            }
          }
        } catch (e) {
          yield AnalysisEvent(phase: 'debts', progress: 0.75, message: '⚠️ تعذر حساب ديون الموردين: $e', icon: '⚠️');
        }
      }

      // --- اكتشاف الصور ---
      int imagesCount = 0;
      final zipDir = File(dbPath).parent;
      final imagesDir = Directory('${zipDir.path}/images');
      if (await imagesDir.exists()) {
        imagesCount = await imagesDir.list().where((f) => f is File).length;
        yield AnalysisEvent(phase: 'images', progress: 0.85, message: '📸 تم اكتشاف $imagesCount صورة منتج', icon: '📸');
      }

      // --- الملخص النهائي ---
      final warnings = <String>[];
      if (customersTable == null) warnings.add('لم يتم اكتشاف جدول زبائن');
      if (productsTable == null) warnings.add('لم يتم اكتشاف جدول منتجات');

      final summary = AnalysisSummary(
        customersFound: customersCount,
        suppliersFound: suppliersCount,
        productsFound: productsCount,
        categoriesFound: categoriesCount,
        imagesFound: imagesCount,
        customerDebts: customerDebts,
        supplierDebts: supplierDebts,
        warnings: warnings,
      );

      yield AnalysisEvent(
        phase: 'complete',
        progress: 1.0,
        message: '✅ التحليل مكتمل!',
        icon: '✅',
        summary: summary,
      );
    } finally {
      db.dispose();
    }
  }

  /// فك ضغط ZIP وإرجاع المجلد المستخرج
  Future<Directory> _extractZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final extractDir = Directory('${zipFile.parent.path}/nayli_import_temp_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create(recursive: true);

    for (final file in archive) {
      final filePath = '${extractDir.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
    return extractDir;
  }

  /// البحث عن أول ملف SQLite في مجلد
  Future<File?> _findSqliteInDir(Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final name = entity.path.toLowerCase();
        if (name.endsWith('.sqlite') || name.endsWith('.db') || name.endsWith('.sqlite3')) {
          return entity;
        }
        // تحقق من magic bytes (SQLite format 3\000)
        try {
          final header = await entity.openRead(0, 16).first;
          if (header.length >= 15 && String.fromCharCodes(header.sublist(0, 15)) == 'SQLite format 3') {
            return entity;
          }
        } catch (_) {}
      }
    }
    return null;
  }
}
