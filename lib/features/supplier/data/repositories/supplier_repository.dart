import '../../../../core/data/hive_database.dart';
import '../../domain/entities/supplier.dart';

class SupplierRepository {
  List<Supplier> getAllSuppliers() {
    final box = HiveDatabase.suppliersBox;
    final List<Supplier> list = [];
    for (final key in box.keys) {
      try {
        final data = box.get(key);
        if (data != null && data is Map) {
          list.add(Supplier.fromMap(data));
        }
      } catch (_) {
        // تخطي السجلات الفاسدة بدون crash
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Supplier? getSupplierById(String id) {
    try {
      final data = HiveDatabase.suppliersBox.get(id);
      if (data != null && data is Map) {
        return Supplier.fromMap(data);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveSupplier(Supplier supplier) async {
    await HiveDatabase.suppliersBox.put(supplier.id, supplier.toMap());
  }

  Future<void> deleteSupplier(String id) async {
    await HiveDatabase.suppliersBox.delete(id);
  }

  bool existsByNameAndPhone(String name, String phone) {
    for (final key in HiveDatabase.suppliersBox.keys) {
      try {
        final data = HiveDatabase.suppliersBox.get(key);
        if (data != null && data is Map) {
          final n = (data['name'] ?? '').toString().trim().toLowerCase();
          final p = (data['phone1'] ?? '').toString().trim();
          if (n == name.trim().toLowerCase() && p == phone.trim()) return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
