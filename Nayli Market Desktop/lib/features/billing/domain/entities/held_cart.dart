import 'package:equatable/equatable.dart';
import 'cart_item.dart';
import '../../../../features/product/domain/entities/product.dart';

class HeldCart extends Equatable {
  final String id;
  final String label;
  final DateTime parkedAt;
  final List<CartItem> items;

  const HeldCart({
    required this.id,
    required this.label,
    required this.parkedAt,
    required this.items,
  });

  double get totalAmount => items.fold(0, (sum, i) => sum + i.total);
  int get itemCount => items.length;

  int get remainingMinutes {
    final diff = DateTime.now().difference(parkedAt).inMinutes;
    final remaining = 20 - diff;
    return remaining > 0 ? remaining : 0;
  }

  bool get isExpired => DateTime.now().difference(parkedAt).inMinutes >= 20;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'parkedAt': parkedAt.toIso8601String(),
      'items': items.map((i) => {
        'product': {
          'id': i.product.id,
          'name': i.product.name,
          'barcode': i.product.barcode,
          'price': i.product.price,
          'stock': i.product.stock,
          'costPrice': i.product.costPrice,
        },
        'quantity': i.quantity,
      }).toList(),
    };
  }

  factory HeldCart.fromMap(Map<dynamic, dynamic> map) {
    final itemsList = <CartItem>[];
    if (map['items'] is List) {
      for (var raw in map['items']) {
        if (raw is Map) {
          final pMap = raw['product'] as Map? ?? {};
          final prod = Product(
            id: pMap['id']?.toString() ?? '',
            name: pMap['name']?.toString() ?? '',
            barcode: pMap['barcode']?.toString() ?? '',
            price: (pMap['price'] as num?)?.toDouble() ?? 0.0,
            stock: (pMap['stock'] as num?)?.toInt() ?? 0,
            costPrice: (pMap['costPrice'] as num?)?.toDouble() ?? 0.0,
          );
          final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
          itemsList.add(CartItem(product: prod, quantity: qty));
        }
      }
    }

    return HeldCart(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? 'سلة مؤقتة',
      parkedAt: DateTime.tryParse(map['parkedAt']?.toString() ?? '') ?? DateTime.now(),
      items: itemsList,
    );
  }

  @override
  List<Object?> get props => [id, label, parkedAt, items];
}