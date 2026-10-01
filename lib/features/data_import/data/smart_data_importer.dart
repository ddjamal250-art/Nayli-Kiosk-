import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import '../../../core/data/hive_database.dart';
import '../../customer/domain/entities/customer.dart';
import '../../supplier/domain/entities/supplier.dart';
import '../../product/data/models/product_model.dart';
import '../../product/data/models/product_unit_model.dart';
import '../../product/domain/entities/product.dart';
import 'analysis_engine.dart';
import 'data_sanitizer.dart';
import 'field_mapper.dart';
import 'import_result.dart';

class SmartDataImporter {
  Future<ImportResult> importData(
    String dbPath,
    AnalysisSummary summary, {
    bool importCustomers = true,
    bool importSuppliers = true,
    bool importProducts = true,
    bool importImages = true,
  }) async {
    final startTime = DateTime.now();
    int cCount = 0, sCount = 0, pCount = 0, iCount = 0, errCount = 0, skipCount = 0;
    final skips = <ImportSkipRecord>[];
    final errors = <ImportErrorRecord>[];

    sql.Database? db;
    try {
      db = sql.sqlite3.open(dbPath);
      
      final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence';");
      final tableNames = tables.map((r) => r['name'] as String).toList();
      
      String? custTable, suppTable, prodTable, codesTable, pricesTable, sellPricesTable, groupsTable;
      for (final t in tableNames) {
        final colsResult = db.select("PRAGMA table_info('\$t');");
        final columns = colsResult.map((r) => ColumnInfo(name: r['name'] as String, type: r['type'] as String, isNullable: (r['notnull'] as int) == 0)).toList();
        final type = SmartFieldMapper.classifyTable(t, columns);
        if (type == TableType.customers) custTable = t;
        if (type == TableType.suppliers) suppTable = t;
        if (type == TableType.products) prodTable = t;
        if (t.toLowerCase() == 'codes') codesTable = t;
        if (t.toLowerCase() == 'prices') pricesTable = t;
        if (t.toLowerCase() == 'sellingprices') sellPricesTable = t;
        if (t.toLowerCase() == 'groups') groupsTable = t;
      }

      if (importCustomers && custTable != null) {
        final custBox = HiveDatabase.customersBox;
        final res = db.select("SELECT * FROM '\$custTable'");
        for (final row in res) {
          try {
            final sourceId = row['id'];
            final name = DataSanitizer.sanitizeName(row['name']);
            if (!DataSanitizer.isValidName(name)) {
              skips.add(ImportSkipRecord(tableName: custTable, recordName: name.isEmpty ? 'Unknown' : name, reason: 'اسم غير صالح'));
              skipCount++;
              continue;
            }
            final phone = DataSanitizer.sanitizePhone(row['phone1'] ?? row['phone']);
            
            // Check duplicates
            bool isDup = false;
            for (final k in custBox.keys) {
               final e = custBox.get(k);
               if (e != null && e is Map) {
                 if (e['name'].toString().trim().toLowerCase() == name.toLowerCase() && 
                    e['phoneNumber'].toString() == phone) {
                   isDup = true; break;
                 }
               }
            }
            if (isDup) {
              skipCount++;
              continue;
            }

            final debt = summary.customerDebts[sourceId] ?? 0.0;
            final uuid = DateTime.now().microsecondsSinceEpoch.toString() + 'c';
            final c = Customer(
              id: uuid,
              name: name,
              phoneNumber: phone,
              address: DataSanitizer.sanitizeAddress(row['address']),
              currentDebt: debt,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await custBox.put(uuid, c.toMap());
            cCount++;
          } catch (e) {
            errors.add(ImportErrorRecord(tableName: custTable, recordName: 'Row Error', error: e.toString()));
            errCount++;
          }
        }
      }

      if (importSuppliers && suppTable != null) {
        final suppBox = HiveDatabase.suppliersBox;
        final res = db.select("SELECT * FROM '\$suppTable'");
        for (final row in res) {
          try {
            final sourceId = row['id'];
            final name = DataSanitizer.sanitizeName(row['name']);
            if (!DataSanitizer.isValidName(name)) {
              skipCount++; continue;
            }
            final phone = DataSanitizer.sanitizePhone(row['phone1'] ?? row['phone']);
            
            bool isDup = false;
            for (final k in suppBox.keys) {
               final e = suppBox.get(k);
               if (e != null && e is Map) {
                 if (e['name'].toString().trim().toLowerCase() == name.toLowerCase() && 
                    e['phone1'].toString() == phone) {
                   isDup = true; break;
                 }
               }
            }
            if (isDup) {
              skipCount++; continue;
            }

            final debt = summary.supplierDebts[sourceId] ?? 0.0;
            final uuid = DateTime.now().microsecondsSinceEpoch.toString() + 's';
            final s = Supplier(
              id: uuid,
              name: name,
              phone1: phone,
              phone2: DataSanitizer.sanitizePhone(row['phone2']),
              address: DataSanitizer.sanitizeAddress(row['address']),
              register: DataSanitizer.sanitizeOptionalField(row['register'] ?? row['rc']),
              nif: DataSanitizer.sanitizeOptionalField(row['nif']),
              ai: DataSanitizer.sanitizeOptionalField(row['ai']),
              nis: DataSanitizer.sanitizeOptionalField(row['nis']),
              currentDebt: debt,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await suppBox.put(uuid, s.toMap());
            sCount++;
          } catch (e) {
            errCount++;
          }
        }
      }

      if (importProducts && prodTable != null) {
        final prodBox = HiveDatabase.productBox;
        final res = db.select("SELECT * FROM '\$prodTable'");
        for (final row in res) {
          try {
            final pId = row['id'];
            final name = DataSanitizer.sanitizeName(row['name']);
            if (!DataSanitizer.isValidName(name)) { skipCount++; continue; }

            String barcode = '';
            if (codesTable != null) {
              final codes = db.select("SELECT value FROM '\$codesTable' WHERE productId = ?", [pId]);
              if (codes.isNotEmpty) barcode = DataSanitizer.sanitizeBarcode(codes.first['value']);
            }
            
            bool isDup = false;
            for (final k in prodBox.keys) {
               final e = prodBox.get(k);
               if (e != null && e.barcode == barcode && barcode.isNotEmpty) {
                 isDup = true; break;
               }
            }
            if (isDup) { skipCount++; continue; }

            double costPrice = 0.0, stock = 0.0, price = 0.0;
            if (pricesTable != null) {
              final prices = db.select("SELECT value, quantity FROM '\$pricesTable' WHERE productId = ?", [pId]);
              if (prices.isNotEmpty) {
                costPrice = DataSanitizer.sanitizePrice(prices.last['value']);
                stock = DataSanitizer.sanitizeQuantity(prices.last['quantity']);
              }
            }
            if (sellPricesTable != null) {
              final sp = db.select("SELECT value FROM '\$sellPricesTable' WHERE productId = ? AND isDefault = 1", [pId]);
              if (sp.isNotEmpty) {
                price = DataSanitizer.sanitizePrice(sp.first['value']);
              } else {
                final spAll = db.select("SELECT value FROM '\$sellPricesTable' WHERE productId = ?", [pId]);
                if (spAll.isNotEmpty) price = DataSanitizer.sanitizePrice(spAll.first['value']);
              }
            }

            String category = 'عام';
            if (groupsTable != null && row['groupId'] != null) {
              final grps = db.select("SELECT name FROM '\$groupsTable' WHERE id = ?", [row['groupId']]);
              if (grps.isNotEmpty) category = DataSanitizer.sanitizeName(grps.first['name']);
            }

            final List<ProductUnitModel> units = [];
            if (row['customUnits'] != null) {
              try {
                final List dynamicUnits = jsonDecode(row['customUnits'].toString());
                for (var u in dynamicUnits) {
                  units.add(ProductUnitModel(
                    name: u['unit']?.toString() ?? 'وحدة',
                    multiplier: DataSanitizer.sanitizeQuantity(u['value']),
                    price: DataSanitizer.sanitizePrice(u['sellingPrice']),
                    tierIndex: 1, // medium
                  ));
                }
              } catch (_) {}
            }

            final uuid = DateTime.now().microsecondsSinceEpoch.toString() + 'p';
            final p = ProductModel(
              id: uuid,
              name: name,
              barcode: barcode.isEmpty ? uuid : barcode,
              price: price,
              stock: stock,
              costPrice: costPrice,
              category: category.isEmpty ? 'عام' : category,
              isWeighted: row['weighted'] == 1,
              expiryDate: row['expiration'] != null ? DataSanitizer.sanitizeDate(row['expiration']).toIso8601String() : null,
              units: units,
              imageUrl: row['image']?.toString(),
            );
            await prodBox.put(uuid, p);
            pCount++;
          } catch (e) {
            errCount++;
          }
        }
      }

      if (importImages && summary.imagesFound > 0) {
        try {
          final zipDir = File(dbPath).parent;
          final imagesDir = Directory('\${zipDir.path}/images');
          if (await imagesDir.exists()) {
            final appDocDir = await getApplicationDocumentsDirectory();
            final targetDir = Directory('\${appDocDir.path}/images');
            if (!await targetDir.exists()) await targetDir.create(recursive: true);
            
            await for (final file in imagesDir.list()) {
              if (file is File) {
                final name = file.uri.pathSegments.last;
                await file.copy('\${targetDir.path}/\$name');
                iCount++;
              }
            }
          }
        } catch (_) {}
      }

    } catch (e) {
      errors.add(ImportErrorRecord(tableName: 'Global', recordName: 'Database', error: e.toString()));
    } finally {
      db?.dispose();
    }

    return ImportResult(
      customersImported: cCount,
      suppliersImported: sCount,
      productsImported: pCount,
      imagesImported: iCount,
      skippedCount: skipCount,
      errorCount: errCount,
      skippedRecords: skips,
      errorRecords: errors,
      duration: DateTime.now().difference(startTime),
    );
  }
}
