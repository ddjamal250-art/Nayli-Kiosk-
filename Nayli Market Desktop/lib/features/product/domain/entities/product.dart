import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final double costPrice;
  final int stock;
  final String category;
  final bool isWeighted;
  final double wholesalePrice;
  final String? expiryDate;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0,
    this.category = 'عام',
    this.isWeighted = false,
    this.wholesalePrice = 0.0,
    this.expiryDate,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        costPrice,
        stock,
        category,
        isWeighted,
        wholesalePrice,
        expiryDate,
      ];
}
