import 'dart:convert';
import 'package:equatable/equatable.dart';

/// قارورة أو صيغة بيع مجزأة لسائل (عطر، زيت، كيراتين، شامبو...)
class LiquidBottleFormat extends Equatable {
  final String id;
  final String name; // e.g. "قارورة 30 مل", "بخاخ 50 مل", "10 مل رول أون"
  final double volumeMl; // السعة بالمليلتر أو الغرام (مثلاً 30.0)
  final double bottleCost; // تكلفة القارورة الفارغة + البخاخ/الغطاء (مثلاً 150 دج)
  final double sellingPrice; // سعر البيع للزبون (مثلاً 4500 دج)
  final String? bottleProductId; // معرّف منتج القارورة الفارغة في المخزون لخصمها آلياً (اختياري)
  final String? barcode; // باركود مباشر للقارورة إن وجد
  final bool isEnabled;

  const LiquidBottleFormat({
    this.id = '',
    this.name = '',
    required this.volumeMl,
    this.bottleCost = 0.0,
    required this.sellingPrice,
    this.bottleProductId,
    this.barcode,
    this.isEnabled = true,
  });

  /// تكلفة السائل فقط داخل هذه القارورة بناءً على تكلفة المل للوعاء الأصلي
  double liquidCost(double costPerMl) => volumeMl * costPerMl;

  /// التكلفة الإجمالية للقارورة معبأة = تكلفة السائل + تكلفة القارورة الفارغة
  double totalCost(double costPerMl) => liquidCost(costPerMl) + bottleCost;

  /// الربح الصافي للقطعة الواحدة
  double profit(double costPerMl) => sellingPrice - totalCost(costPerMl);

  /// نسبة هامش الربح المئوية
  double marginPercent(double costPerMl) {
    if (sellingPrice <= 0) return 0.0;
    return (profit(costPerMl) / sellingPrice) * 100.0;
  }

  LiquidBottleFormat copyWith({
    String? id,
    String? name,
    double? volumeMl,
    double? bottleCost,
    double? sellingPrice,
    String? bottleProductId,
    String? barcode,
    bool? isEnabled,
  }) {
    return LiquidBottleFormat(
      id: id ?? this.id,
      name: name ?? this.name,
      volumeMl: volumeMl ?? this.volumeMl,
      bottleCost: bottleCost ?? this.bottleCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      bottleProductId: bottleProductId ?? this.bottleProductId,
      barcode: barcode ?? this.barcode,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedId = id.isNotEmpty ? id : 'fmt_${volumeMl.toInt()}ml';
    final resolvedName = name.isNotEmpty ? name : 'قارورة ${volumeMl.toInt()} مل';
    return {
      'id': resolvedId,
      'name': resolvedName,
      'volumeMl': volumeMl,
      'bottleCost': bottleCost,
      'sellingPrice': sellingPrice,
      'bottleProductId': bottleProductId,
      'barcode': barcode,
      'isEnabled': isEnabled,
    };
  }

  factory LiquidBottleFormat.fromMap(Map<String, dynamic> map) {
    return LiquidBottleFormat(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'قارورة',
      volumeMl: (map['volumeMl'] as num?)?.toDouble() ?? 10.0,
      bottleCost: (map['bottleCost'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      bottleProductId: map['bottleProductId']?.toString(),
      barcode: map['barcode']?.toString(),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, name, volumeMl, bottleCost, sellingPrice, bottleProductId, barcode, isEnabled];
}

/// إعدادات المنتج السائل / وعاء التقسيم الأم (Mother Liquid Product)
class LiquidDecantConfig extends Equatable {
  final double containerVolume; // السعة الإجمالية للوعاء الأصلي بالمل أو الغرام (مثلاً: 100, 250, 500, 1000)
  final double containerCost; // تكلفة شراء الوعاء الأصلي بالكامل (مثلاً: 15,000 دج)
  final String unitName; // 'مل' أو 'غرام' أو 'لتر'
  final double defaultPricePerMl; // سعر البيع بالمليلتر المباشر للتعبئة الحرة (مثلاً: 60 دج/مل)
  final double defaultEmptyBottleCost; // تكلفة القارورة الفارغة عند التعبئة الحرة (مثلاً: 120 دج)
  final double spillageLossPercent; // نسبة الفاقد أو الهدر المتوقعة أثناء التقسيم (مثلاً: 2.0%)
  final double totalReceivedVolumeMl; // إجمالي ما استُلم تاريخياً لتتبع نسبة الامتلاء الحقيقية
  final List<LiquidBottleFormat> formats; // قوارير التعبئة المهيأة

  const LiquidDecantConfig({
    required this.containerVolume,
    required this.containerCost,
    this.unitName = 'مل',
    this.defaultPricePerMl = 0.0,
    this.defaultEmptyBottleCost = 0.0,
    this.spillageLossPercent = 0.0,
    this.totalReceivedVolumeMl = 0.0,
    this.formats = const [],
  });

  /// تكلفة الوحدة الأساسية (1 مل أو 1 غرام) بعد احتساب نسبة الهدر/الفاقد الحقيقية
  double get costPerMl =>
      effectiveSellableVolume > 0 ? (containerCost / effectiveSellableVolume) : 0.0;

  /// الحجم الفعلي القابل للبيع بعد خصم نسبة الهدر/الفاقد
  double get effectiveSellableVolume =>
      containerVolume * (1.0 - (spillageLossPercent.clamp(0.0, 50.0) / 100.0));

  /// نسبة امتلاء القارورة للمؤشر البصري المتحرك (من 0.0 إلى 1.0)
  double fillRatio(double currentStock) {
    if (currentStock <= 0) return 0.0;
    final maxCapacity = totalReceivedVolumeMl > 0 ? totalReceivedVolumeMl : containerVolume;
    if (maxCapacity <= 0) return 0.0;
    return (currentStock / maxCapacity).clamp(0.0, 1.0);
  }

  LiquidDecantConfig copyWith({
    double? containerVolume,
    double? containerCost,
    String? unitName,
    double? defaultPricePerMl,
    double? defaultEmptyBottleCost,
    double? spillageLossPercent,
    double? totalReceivedVolumeMl,
    List<LiquidBottleFormat>? formats,
  }) {
    return LiquidDecantConfig(
      containerVolume: containerVolume ?? this.containerVolume,
      containerCost: containerCost ?? this.containerCost,
      unitName: unitName ?? this.unitName,
      defaultPricePerMl: defaultPricePerMl ?? this.defaultPricePerMl,
      defaultEmptyBottleCost: defaultEmptyBottleCost ?? this.defaultEmptyBottleCost,
      spillageLossPercent: spillageLossPercent ?? this.spillageLossPercent,
      totalReceivedVolumeMl: totalReceivedVolumeMl ?? this.totalReceivedVolumeMl,
      formats: formats ?? this.formats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'containerVolume': containerVolume,
      'containerCost': containerCost,
      'unitName': unitName,
      'defaultPricePerMl': defaultPricePerMl,
      'defaultEmptyBottleCost': defaultEmptyBottleCost,
      'spillageLossPercent': spillageLossPercent,
      'totalReceivedVolumeMl': totalReceivedVolumeMl,
      'formats': formats.map((f) => f.toMap()).toList(),
    };
  }

  factory LiquidDecantConfig.fromMap(Map<String, dynamic> map) {
    final formatsRaw = map['formats'] as List? ?? [];
    return LiquidDecantConfig(
      containerVolume: (map['containerVolume'] as num?)?.toDouble() ?? 100.0,
      containerCost: (map['containerCost'] as num?)?.toDouble() ?? 0.0,
      unitName: map['unitName']?.toString() ?? 'مل',
      defaultPricePerMl: (map['defaultPricePerMl'] as num?)?.toDouble() ?? 0.0,
      defaultEmptyBottleCost: (map['defaultEmptyBottleCost'] as num?)?.toDouble() ?? 0.0,
      spillageLossPercent: (map['spillageLossPercent'] as num?)?.toDouble() ?? 0.0,
      totalReceivedVolumeMl: (map['totalReceivedVolumeMl'] as num?)?.toDouble() ?? 0.0,
      formats: formatsRaw
          .whereType<Map>()
          .map((m) => LiquidBottleFormat.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toMap());

  static LiquidDecantConfig? tryParse(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return LiquidDecantConfig.fromMap(decoded);
      } else if (decoded is Map) {
        return LiquidDecantConfig.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  factory LiquidDecantConfig.defaultPerfumeConfig() {
    return const LiquidDecantConfig(
      containerVolume: 100.0,
      containerCost: 15000.0,
      unitName: 'مل',
      defaultPricePerMl: 220.0,
      defaultEmptyBottleCost: 150.0,
      spillageLossPercent: 2.0,
      formats: [
        LiquidBottleFormat(id: 'fmt_5ml', name: 'قارورة 5 مل', volumeMl: 5.0, bottleCost: 100.0, sellingPrice: 1200.0),
        LiquidBottleFormat(id: 'fmt_10ml', name: 'قارورة 10 مل', volumeMl: 10.0, bottleCost: 120.0, sellingPrice: 2300.0),
        LiquidBottleFormat(id: 'fmt_20ml', name: 'قارورة 20 مل', volumeMl: 20.0, bottleCost: 150.0, sellingPrice: 4400.0),
        LiquidBottleFormat(id: 'fmt_30ml', name: 'قارورة 30 مل', volumeMl: 30.0, bottleCost: 180.0, sellingPrice: 6500.0),
        LiquidBottleFormat(id: 'fmt_50ml', name: 'قارورة 50 مل', volumeMl: 50.0, bottleCost: 250.0, sellingPrice: 10500.0),
      ],
    );
  }

  factory LiquidDecantConfig.defaultOilPerfumeConfig() {
    return const LiquidDecantConfig(
      containerVolume: 500.0,
      containerCost: 12000.0,
      unitName: 'مل',
      defaultPricePerMl: 40.0,
      defaultEmptyBottleCost: 80.0,
      spillageLossPercent: 1.0,
      formats: [
        LiquidBottleFormat(id: 'fmt_3ml', name: 'تولة 3 مل', volumeMl: 3.0, bottleCost: 50.0, sellingPrice: 200.0),
        LiquidBottleFormat(id: 'fmt_6ml', name: 'تولة 6 مل', volumeMl: 6.0, bottleCost: 70.0, sellingPrice: 350.0),
        LiquidBottleFormat(id: 'fmt_12ml', name: 'تولة 12 مل', volumeMl: 12.0, bottleCost: 100.0, sellingPrice: 650.0),
        LiquidBottleFormat(id: 'fmt_30ml', name: 'بخاخ 30 مل', volumeMl: 30.0, bottleCost: 120.0, sellingPrice: 1500.0),
        LiquidBottleFormat(id: 'fmt_50ml', name: 'بخاخ 50 مل', volumeMl: 50.0, bottleCost: 150.0, sellingPrice: 2400.0),
      ],
    );
  }

  factory LiquidDecantConfig.defaultCosmeticsConfig() {
    return const LiquidDecantConfig(
      containerVolume: 1000.0,
      containerCost: 18000.0,
      unitName: 'مل',
      defaultPricePerMl: 35.0,
      defaultEmptyBottleCost: 100.0,
      spillageLossPercent: 2.5,
      formats: [
        LiquidBottleFormat(id: 'fmt_50ml', name: 'جرعة 50 مل', volumeMl: 50.0, bottleCost: 80.0, sellingPrice: 2000.0),
        LiquidBottleFormat(id: 'fmt_100ml', name: 'عبوة 100 مل', volumeMl: 100.0, bottleCost: 120.0, sellingPrice: 3800.0),
        LiquidBottleFormat(id: 'fmt_150ml', name: 'عبوة 150 مل', volumeMl: 150.0, bottleCost: 150.0, sellingPrice: 5500.0),
        LiquidBottleFormat(id: 'fmt_250ml', name: 'عبوة 250 مل', volumeMl: 250.0, bottleCost: 180.0, sellingPrice: 8900.0),
      ],
    );
  }

  /// اقتراح صيغ قوارير قياسية بنقرة واحدة
  static List<LiquidBottleFormat> generateDefaultFormats({
    required double costPerMl,
    required double targetMarkupMultiplier, // مثلاً 1.5 لربح 50%
  }) {
    return [
      LiquidBottleFormat(
        id: 'fmt_10ml',
        name: 'قارورة 10 مل',
        volumeMl: 10.0,
        bottleCost: 80.0,
        sellingPrice: ((10.0 * costPerMl + 80.0) * targetMarkupMultiplier).ceilToDouble(),
      ),
      LiquidBottleFormat(
        id: 'fmt_20ml',
        name: 'قارورة 20 مل',
        volumeMl: 20.0,
        bottleCost: 120.0,
        sellingPrice: ((20.0 * costPerMl + 120.0) * targetMarkupMultiplier).ceilToDouble(),
      ),
      LiquidBottleFormat(
        id: 'fmt_30ml',
        name: 'قارورة 30 مل',
        volumeMl: 30.0,
        bottleCost: 150.0,
        sellingPrice: ((30.0 * costPerMl + 150.0) * targetMarkupMultiplier).ceilToDouble(),
      ),
      LiquidBottleFormat(
        id: 'fmt_50ml',
        name: 'قارورة 50 مل',
        volumeMl: 50.0,
        bottleCost: 200.0,
        sellingPrice: ((50.0 * costPerMl + 200.0) * targetMarkupMultiplier).ceilToDouble(),
      ),
      LiquidBottleFormat(
        id: 'fmt_100ml',
        name: 'قارورة 100 مل',
        volumeMl: 100.0,
        bottleCost: 300.0,
        sellingPrice: ((100.0 * costPerMl + 300.0) * targetMarkupMultiplier).ceilToDouble(),
      ),
    ];
  }

  @override
  List<Object?> get props => [
        containerVolume,
        containerCost,
        unitName,
        defaultPricePerMl,
        defaultEmptyBottleCost,
        spillageLossPercent,
        totalReceivedVolumeMl,
        formats,
      ];
}
