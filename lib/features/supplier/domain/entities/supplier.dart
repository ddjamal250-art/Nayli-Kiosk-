import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  final String id;
  final String name;
  final String phone1;
  final String? phone2;
  final String address;
  final String? register; // السجل التجاري RC
  final String? nif;      // الرقم الجبائي
  final String? ai;       // المادة
  final String? nis;      // رقم الضمان الاجتماعي
  final double currentDebt;
  final double maxDebtLimit;
  final Map<String, String> extraFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    required this.phone1,
    this.phone2,
    this.address = '',
    this.register,
    this.nif,
    this.ai,
    this.nis,
    this.currentDebt = 0.0,
    this.maxDebtLimit = 100000.0,
    this.extraFields = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? phone1,
    String? phone2,
    String? address,
    String? register,
    String? nif,
    String? ai,
    String? nis,
    double? currentDebt,
    double? maxDebtLimit,
    Map<String, String>? extraFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      address: address ?? this.address,
      register: register ?? this.register,
      nif: nif ?? this.nif,
      ai: ai ?? this.ai,
      nis: nis ?? this.nis,
      currentDebt: currentDebt ?? this.currentDebt,
      maxDebtLimit: maxDebtLimit ?? this.maxDebtLimit,
      extraFields: extraFields ?? this.extraFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone1': phone1,
      'phone2': phone2,
      'address': address,
      'register': register,
      'nif': nif,
      'ai': ai,
      'nis': nis,
      'currentDebt': currentDebt,
      'maxDebtLimit': maxDebtLimit,
      'extraFields': extraFields,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<dynamic, dynamic> map) {
    return Supplier(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone1: map['phone1']?.toString() ?? '',
      phone2: map['phone2']?.toString(),
      address: map['address']?.toString() ?? '',
      register: map['register']?.toString(),
      nif: map['nif']?.toString(),
      ai: map['ai']?.toString(),
      nis: map['nis']?.toString(),
      currentDebt: (map['currentDebt'] as num?)?.toDouble() ?? 0.0,
      maxDebtLimit: (map['maxDebtLimit'] as num?)?.toDouble() ?? 100000.0,
      extraFields: map['extraFields'] != null
          ? Map<String, String>.from(map['extraFields'] as Map)
          : const {},
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id, name, phone1, phone2, address,
        register, nif, ai, nis,
        currentDebt, maxDebtLimit, extraFields,
        createdAt, updatedAt,
      ];
}
