import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String address;
  final double currentDebt;
  final double maxDebtLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address = '',
    this.currentDebt = 0.0,
    this.maxDebtLimit = 50000.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? address,
    double? currentDebt,
    double? maxDebtLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      currentDebt: currentDebt ?? this.currentDebt,
      maxDebtLimit: maxDebtLimit ?? this.maxDebtLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'currentDebt': currentDebt,
      'maxDebtLimit': maxDebtLimit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<dynamic, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      currentDebt: (map['currentDebt'] as num?)?.toDouble() ?? 0.0,
      maxDebtLimit: (map['maxDebtLimit'] as num?)?.toDouble() ?? 50000.0,
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
        id,
        name,
        phoneNumber,
        address,
        currentDebt,
        maxDebtLimit,
        createdAt,
        updatedAt,
      ];
}
