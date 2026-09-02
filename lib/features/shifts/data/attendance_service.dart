import 'package:intl/intl.dart';
import '../../../core/data/hive_database.dart';
import 'attendance_record_model.dart';

class AttendanceService {
  /// Record quick pointage check-in or check-out
  static Future<AttendanceRecord> recordPointage({
    required String staffId,
    required String staffName,
    String status = 'present',
    String? notes,
  }) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final id = 'att_' + staffId + '_' + todayStr;

    final box = HiveDatabase.attendanceBox;
    final existing = box.get(id);

    if (existing is Map) {
      // Already checked in today -> update checkOutTime
      final current = AttendanceRecord.fromMap(existing);
      final updated = AttendanceRecord(
        id: current.id,
        staffId: current.staffId,
        staffName: current.staffName,
        dateStr: current.dateStr,
        checkInTime: current.checkInTime,
        checkOutTime: now,
        status: current.status,
        notes: notes ?? current.notes,
      );
      await box.put(updated.id, updated.toMap());
      return updated;
    } else {
      // First scan of the day -> Check in
      final record = AttendanceRecord(
        id: id,
        staffId: staffId,
        staffName: staffName,
        dateStr: todayStr,
        checkInTime: now,
        status: status,
        notes: notes,
      );
      await box.put(record.id, record.toMap());
      return record;
    }
  }

  /// Get attendance records for a specific staff member in a month
  static List<AttendanceRecord> getMonthlyAttendance(String staffId, String monthStr) {
    try {
      final box = HiveDatabase.attendanceBox;
      final list = <AttendanceRecord>[];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final a = AttendanceRecord.fromMap(val);
          if (a.staffId == staffId && a.dateStr.startsWith(monthStr)) {
            list.add(a);
          }
        }
      }
      list.sort((a, b) => b.dateStr.compareTo(a.dateStr));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Count worked days for monthly settlement
  static int countDaysWorked(String staffId, String monthStr) {
    final list = getMonthlyAttendance(staffId, monthStr);
    return list.where((a) => a.status == 'present' || a.status == 'late').length;
  }
}
