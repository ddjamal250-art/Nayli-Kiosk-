import 'package:equatable/equatable.dart';

class QuickItem extends Equatable {
  final String id;
  final String name;
  final double price;
  final String icon;

  const QuickItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
  });

  QuickItem copyWith({
    String? id,
    String? name,
    double? price,
    String? icon,
  }) {
    return QuickItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'icon': icon,
    };
  }

  factory QuickItem.fromMap(Map<dynamic, dynamic> map) {
    return QuickItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      icon: map['icon']?.toString() ?? '🛍️',
    );
  }

  static List<QuickItem> get defaultItems => const [
        QuickItem(id: 'q_bread_1', name: 'خبز عادي', price: 10.0, icon: '🥖'),
        QuickItem(id: 'q_bread_2', name: 'خبز محسن', price: 15.0, icon: '🥖'),
        QuickItem(id: 'q_egg', name: 'بيضة طازجة', price: 25.0, icon: '🥚'),
        QuickItem(id: 'q_bag', name: 'كيس بلاستيكي', price: 5.0, icon: '🛍️'),
        QuickItem(id: 'q_water', name: 'ماء 0.5L', price: 25.0, icon: '💧'),
        QuickItem(id: 'q_milk', name: 'حليب مبستر', price: 25.0, icon: '🥛'),
      ];

  @override
  List<Object?> get props => [id, name, price, icon];
}
