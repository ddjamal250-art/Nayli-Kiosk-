import 'dart:convert';
import 'package:equatable/equatable.dart';

class ProductOptionChoice extends Equatable {
  final String id;
  final String name; // e.g. "كبير", "حليب لوز", "سكر زيادة"
  final double priceDelta; // e.g. +50.0, +30.0, -10.0
  final bool isDefault;

  const ProductOptionChoice({
    required this.id,
    required this.name,
    this.priceDelta = 0.0,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'priceDelta': priceDelta,
    'isDefault': isDefault,
  };

  factory ProductOptionChoice.fromMap(Map<dynamic, dynamic> map) => ProductOptionChoice(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    priceDelta: (map['priceDelta'] as num?)?.toDouble() ?? 0.0,
    isDefault: map['isDefault'] == true,
  );

  @override
  List<Object> get props => [id, name, priceDelta, isDefault];
}

class ProductOptionGroup extends Equatable {
  final String id;
  final String name; // e.g. "الحجم", "الإضافات", "درجة الطهي"
  final bool isRequired;
  final bool isMultiSelect;
  final List<ProductOptionChoice> choices;

  const ProductOptionGroup({
    required this.id,
    required this.name,
    this.isRequired = false,
    this.isMultiSelect = false,
    this.choices = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'isRequired': isRequired,
    'isMultiSelect': isMultiSelect,
    'choices': choices.map((c) => c.toMap()).toList(),
  };

  factory ProductOptionGroup.fromMap(Map<dynamic, dynamic> map) {
    final rawChoices = map['choices'] as List? ?? [];
    return ProductOptionGroup(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isRequired: map['isRequired'] == true,
      isMultiSelect: map['isMultiSelect'] == true,
      choices: rawChoices.map((c) => ProductOptionChoice.fromMap(c as Map)).toList(),
    );
  }

  static List<ProductOptionGroup> parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.map((item) => ProductOptionGroup.fromMap(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  List<Object> get props => [id, name, isRequired, isMultiSelect, choices];
}

class SelectedProductOption extends Equatable {
  final String? groupId;
  final String groupName;
  final String? choiceId;
  final String choiceName;
  final double priceDelta;

  const SelectedProductOption({
    this.groupId,
    required this.groupName,
    this.choiceId,
    required this.choiceName,
    this.priceDelta = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'groupName': groupName,
    'choiceId': choiceId,
    'choiceName': choiceName,
    'priceDelta': priceDelta,
  };

  Map<String, dynamic> toJson() => toMap();

  factory SelectedProductOption.fromMap(Map<dynamic, dynamic> map) => SelectedProductOption(
    groupId: map['groupId']?.toString(),
    groupName: map['groupName']?.toString() ?? '',
    choiceId: map['choiceId']?.toString(),
    choiceName: map['choiceName']?.toString() ?? '',
    priceDelta: (map['priceDelta'] as num?)?.toDouble() ?? 0.0,
  );

  factory SelectedProductOption.fromJson(Map<dynamic, dynamic> map) => SelectedProductOption.fromMap(map);

  @override
  List<Object?> get props => [groupId, groupName, choiceId, choiceName, priceDelta];
}
