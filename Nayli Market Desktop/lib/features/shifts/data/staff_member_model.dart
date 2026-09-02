import 'dart:convert';

/// Enterprise Staff Member Model for Nayli Market
/// Supports job departments, salaries, unique PINs, and granular security toggles
class StaffMember {
  final String id;
  final String name;
  final String phone;
  final String nationalId;
  final String department; // caisse, stock, boucherie, fruits, securite, entretien, admin
  final String role; // admin, supervisor, cashier, worker
  final String pin; // 4-digit unique PIN
  final String barcode; // Barcode for douchette badge, e.g. STAFF-1001
  final double baseSalary;
  final String salaryType; // 'monthly' or 'daily'
  final bool isActive;
  final DateTime hireDate;
  final String preferredStation; // e.g. 'كاشير 01'
  final Map<String, dynamic> permissions;

  StaffMember({
    required this.id,
    required this.name,
    this.phone = '',
    this.nationalId = '',
    this.department = 'caisse',
    this.role = 'cashier',
    required this.pin,
    required this.barcode,
    this.baseSalary = 0.0,
    this.salaryType = 'monthly',
    this.isActive = true,
    DateTime? hireDate,
    this.preferredStation = 'كاشير 01',
    Map<String, dynamic>? permissions,
  })  : hireDate = hireDate ?? DateTime.now(),
        permissions = permissions ?? defaultPermissionsForRole(role);

  /// Default permissions based on job role
  static Map<String, dynamic> defaultPermissionsForRole(String role) {
    if (role == 'admin') {
      return {
        'canApplyDiscount': true,
        'maxDiscountAmount': 999999.0,
        'canVoidInvoice': true,
        'canSellOnCredit': true,
        'maxCreditLimit': 999999.0,
        'canViewCostPrice': true,
        'canOpenCashDrawerManually': true,
        'canModifyProductPrice': true,
        'canManageStock': true,
        'canViewReports': true,
        'isTemporaryElevation': false,
        'temporaryShiftId': null,
      };
    } else if (role == 'supervisor') {
      return {
        'canApplyDiscount': true,
        'maxDiscountAmount': 5000.0,
        'canVoidInvoice': true,
        'canSellOnCredit': true,
        'maxCreditLimit': 20000.0,
        'canViewCostPrice': true,
        'canOpenCashDrawerManually': true,
        'canModifyProductPrice': true,
        'canManageStock': true,
        'canViewReports': false,
        'isTemporaryElevation': false,
        'temporaryShiftId': null,
      };
    } else if (role == 'cashier') {
      return {
        'canApplyDiscount': true,
        'maxDiscountAmount': 500.0,
        'canVoidInvoice': false,
        'canSellOnCredit': false,
        'maxCreditLimit': 0.0,
        'canViewCostPrice': false,
        'canOpenCashDrawerManually': false,
        'canModifyProductPrice': false,
        'canManageStock': false,
        'canViewReports': false,
        'isTemporaryElevation': false,
        'temporaryShiftId': null,
      };
    } else {
      // General workers (stock, cleaning, security) have no POS access
      return {
        'canApplyDiscount': false,
        'maxDiscountAmount': 0.0,
        'canVoidInvoice': false,
        'canSellOnCredit': false,
        'maxCreditLimit': 0.0,
        'canViewCostPrice': false,
        'canOpenCashDrawerManually': false,
        'canModifyProductPrice': false,
        'canManageStock': role == 'stock',
        'canViewReports': false,
        'isTemporaryElevation': false,
        'temporaryShiftId': null,
      };
    }
  }

  bool get hasPosAccess =>
      role == 'admin' || role == 'supervisor' || role == 'cashier';

  bool get isAdmin => role == 'admin';
  bool get isSupervisor => role == 'supervisor' || role == 'admin';

  bool can(String permissionKey) {
    if (isAdmin) return true;
    return permissions[permissionKey] == true;
  }

  double get maxDiscount =>
      (permissions['maxDiscountAmount'] as num?)?.toDouble() ?? 0.0;

  double get maxCredit =>
      (permissions['maxCreditLimit'] as num?)?.toDouble() ?? 0.0;

  StaffMember copyWith({
    String? name,
    String? phone,
    String? nationalId,
    String? department,
    String? role,
    String? pin,
    String? barcode,
    double? baseSalary,
    String? salaryType,
    bool? isActive,
    String? preferredStation,
    Map<String, dynamic>? permissions,
  }) {
    return StaffMember(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      nationalId: nationalId ?? this.nationalId,
      department: department ?? this.department,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      barcode: barcode ?? this.barcode,
      baseSalary: baseSalary ?? this.baseSalary,
      salaryType: salaryType ?? this.salaryType,
      isActive: isActive ?? this.isActive,
      hireDate: hireDate,
      preferredStation: preferredStation ?? this.preferredStation,
      permissions: permissions ?? Map<String, dynamic>.from(this.permissions),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'nationalId': nationalId,
        'department': department,
        'role': role,
        'pin': pin,
        'barcode': barcode,
        'baseSalary': baseSalary,
        'salaryType': salaryType,
        'isActive': isActive,
        'hireDate': hireDate.toIso8601String(),
        'preferredStation': preferredStation,
        'permissions': permissions,
      };

  factory StaffMember.fromMap(Map<dynamic, dynamic> map) {
    final rawPerms = map['permissions'];
    Map<String, dynamic> parsedPerms;
    if (rawPerms is Map) {
      parsedPerms = Map<String, dynamic>.from(rawPerms);
    } else {
      parsedPerms = defaultPermissionsForRole(map['role']?.toString() ?? 'cashier');
    }

    return StaffMember(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'موظف',
      phone: map['phone']?.toString() ?? '',
      nationalId: map['nationalId']?.toString() ?? '',
      department: map['department']?.toString() ?? 'caisse',
      role: map['role']?.toString() ?? 'cashier',
      pin: map['pin']?.toString() ?? '0000',
      barcode: map['barcode']?.toString() ?? 'STAFF-1001',
      baseSalary: (map['baseSalary'] as num?)?.toDouble() ?? 0.0,
      salaryType: map['salaryType']?.toString() ?? 'monthly',
      isActive: map['isActive'] as bool? ?? true,
      hireDate: DateTime.tryParse(map['hireDate']?.toString() ?? '') ?? DateTime.now(),
      preferredStation: map['preferredStation']?.toString() ?? 'كاشير 01',
      permissions: parsedPerms,
    );
  }
}
