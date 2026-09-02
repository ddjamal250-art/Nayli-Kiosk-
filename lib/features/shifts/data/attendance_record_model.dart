/// Enterprise Staff Attendance Record (Pointage)
/// Tracks daily check-ins, check-outs, absences, and shifts worked
class AttendanceRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String dateStr; // YYYY-MM-DD
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'present', 'absent', 'late', 'leave'
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.dateStr,
    this.checkInTime,
    this.checkOutTime,
    this.status = 'present',
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffId': staffId,
        'staffName': staffName,
        'dateStr': dateStr,
        'checkInTime': checkInTime?.toIso8601String(),
        'checkOutTime': checkOutTime?.toIso8601String(),
        'status': status,
        'notes': notes,
      };

  factory AttendanceRecord.fromMap(Map<dynamic, dynamic> map) => AttendanceRecord(
        id: map['id']?.toString() ?? '',
        staffId: map['staffId']?.toString() ?? '',
        staffName: map['staffName']?.toString() ?? '',
        dateStr: map['dateStr']?.toString() ?? '',
        checkInTime: map['checkInTime'] != null ? DateTime.tryParse(map['checkInTime'].toString()) : null,
        checkOutTime: map['checkOutTime'] != null ? DateTime.tryParse(map['checkOutTime'].toString()) : null,
        status: map['status']?.toString() ?? 'present',
        notes: map['notes']?.toString(),
      );
}
