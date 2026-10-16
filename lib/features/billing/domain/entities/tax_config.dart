import '../../../../core/data/hive_database.dart';

class TaxCalculation {
  final double grossAmount; // المبلغ الإجمالي (TTC)
  final double htAmount;    // المبلغ الصافي بدون ضريبة (HT)
  final double tvaAmount;   // مبلغ القيمة المضافة (TVA)
  final double rate;        // النسبة المئوية للضريبة (e.g. 19% أو 9%)
  final bool isEnabled;

  const TaxCalculation({
    required this.grossAmount,
    required this.htAmount,
    required this.tvaAmount,
    required this.rate,
    required this.isEnabled,
  });
}

class TaxConfig {
  /// تفعيل حساب الضرائب (معطل اختيارياً وغير مفعل أولياً حسب رغبة المستخدم الصريحة)
  final bool isTaxEnabled;
  /// نسبة الرسم على القيمة المضافة الافتراضية (19% في الجزائر)
  final double defaultTvaRate;
  /// هل أسعار المنتجات تتضمن الضريبة مسبقاً (TTC)
  final bool isPricesTtc;
  /// رقم التعريف الجبائي / الإحصائي (NIF / NIS)
  final String taxRegistrationNumber;

  const TaxConfig({
    this.isTaxEnabled = false,
    this.defaultTvaRate = 19.0,
    this.isPricesTtc = true,
    this.taxRegistrationNumber = '',
  });

  /// حساب الضريبة والمبلغ الصافي (HT) لمبلغ إجمالي
  TaxCalculation calculate(double grossAmount, {double? overrideRate}) {
    if (!isTaxEnabled) {
      return TaxCalculation(
        grossAmount: grossAmount,
        htAmount: grossAmount,
        tvaAmount: 0.0,
        rate: 0.0,
        isEnabled: false,
      );
    }

    final double rate = overrideRate ?? defaultTvaRate;
    if (rate <= 0 || grossAmount <= 0) {
      return TaxCalculation(
        grossAmount: grossAmount,
        htAmount: grossAmount,
        tvaAmount: 0.0,
        rate: rate,
        isEnabled: true,
      );
    }

    if (isPricesTtc) {
      final double ht = grossAmount / (1.0 + (rate / 100.0));
      final double tva = grossAmount - ht;
      return TaxCalculation(
        grossAmount: grossAmount,
        htAmount: ht,
        tvaAmount: tva,
        rate: rate,
        isEnabled: true,
      );
    } else {
      final double tva = grossAmount * (rate / 100.0);
      final double ttc = grossAmount + tva;
      return TaxCalculation(
        grossAmount: ttc,
        htAmount: grossAmount,
        tvaAmount: tva,
        rate: rate,
        isEnabled: true,
      );
    }
  }

  static TaxConfig fromSettings() {
    final box = HiveDatabase.settingsBox;
    return TaxConfig(
      isTaxEnabled: box.get('pos_tax_enabled', defaultValue: false) as bool,
      defaultTvaRate: (box.get('pos_tax_rate', defaultValue: 19.0) as num).toDouble(),
      isPricesTtc: box.get('pos_tax_inclusive', defaultValue: true) as bool,
      taxRegistrationNumber: box.get('pos_tax_nif_nis', defaultValue: '')?.toString() ?? '',
    );
  }

  Future<void> saveToSettings() async {
    final box = HiveDatabase.settingsBox;
    await box.put('pos_tax_enabled', isTaxEnabled);
    await box.put('pos_tax_rate', defaultTvaRate);
    await box.put('pos_tax_inclusive', isPricesTtc);
    await box.put('pos_tax_nif_nis', taxRegistrationNumber);
  }
}
