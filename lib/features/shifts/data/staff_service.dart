import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import '../../../core/utils/security_pin_helper.dart';
import 'staff_member_model.dart';

class StaffService {
  /// Ensures the default Admin account exists on first launch without a premature hardcoded PIN
  static Future<void> seedInitialAdminIfEmpty() async {
    try {
      final box = HiveDatabase.staffBox;
      // Remove duplicate legacy admin_01 if staff_admin_master also exists
      if (box.containsKey('admin_01') && box.containsKey('staff_admin_master')) {
        await box.delete('admin_01');
      }

      if (box.isEmpty) {
        final admin = StaffMember(
          id: 'staff_admin_master',
          name: 'المدير العام (المشرف الرئيسي)',
          phone: '',
          department: 'admin',
          role: 'admin',
          pin: '', // No PIN required until the merchant explicitly sets one
          barcode: 'STAFF-0001',
          baseSalary: 0.0,
          isActive: true,
          preferredStation: 'الإدارة',
        );
        await box.put(admin.id, admin.toMap());
      } else if (!SecurityPinHelper.isPinEnabled()) {
        // Heal legacy factory PINs ('9999' / '0000') if the merchant has never enabled PIN lock
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw is Map) {
            final role = raw['role']?.toString() ?? '';
            final pin = raw['pin']?.toString() ?? '';
            if (role == 'admin' && (pin == '9999' || pin == '0000')) {
              final updated = Map<String, dynamic>.from(raw);
              updated['pin'] = '';
              await box.put(key, updated);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('seedInitialAdminIfEmpty error: $e');
    }
  }

  /// Get all staff members
  static List<StaffMember> getAllStaff() {
    try {
      final box = HiveDatabase.staffBox;
      final list = <StaffMember>[];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          list.add(StaffMember.fromMap(val));
        }
      }
      list.sort((a, b) {
        if (a.isAdmin) return -1;
        if (b.isAdmin) return 1;
        return a.name.compareTo(b.name);
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Get active staff only
  static List<StaffMember> getActiveStaff() {
    return getAllStaff().where((s) => s.isActive).toList();
  }

  /// Get staff members with POS register access
  static List<StaffMember> getActiveCashiers() {
    return getActiveStaff().where((s) => s.hasPosAccess).toList();
  }

  /// Check if a PIN is unique (zero-collision check)
  static bool isPinUnique(String pin, {String? excludeId}) {
    final clean = pin.trim();
    if (clean.isEmpty) return false;

    // Check manager master pin
    if (SecurityPinHelper.isPinEnabled() && SecurityPinHelper.verifyPin(clean) && excludeId != 'staff_admin_master') {
      return false;
    }

    final all = getAllStaff();
    for (var s in all) {
      if (excludeId != null && s.id == excludeId) continue;
      if (s.pin.trim() == clean) {
        return false;
      }
    }
    return true;
  }

  /// Generate a unique, collision-free 4-digit PIN
  static String generateUniquePin() {
    final rng = Random();
    for (int attempts = 0; attempts < 1000; attempts++) {
      final pin = (rng.nextInt(9000) + 1000).toString();
      // Avoid obvious repetitive PINs
      if (pin == '1111' || pin == '2222' || pin == '3333' || pin == '4444' ||
          pin == '5555' || pin == '6666' || pin == '7777' || pin == '8888' ||
          pin == '9999' || pin == '1234' || pin == '4321') {
        continue;
      }
      if (isPinUnique(pin)) {
        return pin;
      }
    }
    return (Random().nextInt(9000) + 1000).toString();
  }

  /// Find staff member by PIN
  static StaffMember? findByPin(String pin) {
    final clean = pin.trim();
    final all = getActiveStaff();
    for (var s in all) {
      if (s.pin.trim() == clean) {
        return s;
      }
    }
    return null;
  }

  /// Find staff member by barcode badge
  static StaffMember? findByBarcode(String barcode) {
    final clean = barcode.trim();
    final all = getActiveStaff();
    for (var s in all) {
      if (s.barcode.trim() == clean) {
        return s;
      }
    }
    return null;
  }

  /// Save or update staff member
  static Future<void> saveStaff(StaffMember member) async {
    final box = HiveDatabase.staffBox;
    await box.put(member.id, member.toMap());
  }

  /// Toggle staff active status (soft delete / archive)
  static Future<void> toggleActive(String id) async {
    final box = HiveDatabase.staffBox;
    final val = box.get(id);
    if (val is Map) {
      final member = StaffMember.fromMap(val);
      final updated = member.copyWith(isActive: !member.isActive);
      await box.put(id, updated.toMap());
    }
  }

  /// Permanently delete staff member
  static Future<void> deleteStaff(String id) async {
    final box = HiveDatabase.staffBox;
    await box.delete(id);
  }
}
