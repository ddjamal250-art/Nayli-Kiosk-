class ScaleBarcodeResult {
  final bool isScaleBarcode;
  final String productCode;
  final String productCodeAlt;
  final double? weightKg;
  final double? embeddedPrice;
  final String rawBarcode;

  ScaleBarcodeResult({
    required this.isScaleBarcode,
    required this.productCode,
    this.productCodeAlt = '',
    this.weightKg,
    this.embeddedPrice,
    required this.rawBarcode,
  });

  String get itemCode => productCode;
  double get weightOrPrice => weightKg ?? embeddedPrice ?? 0.0;
}

class ScaleBarcodeParser {
  static bool isScaleBarcode(String barcode) => parse(barcode).isScaleBarcode;

  /// Parses standard 13-digit retail weighing scale barcodes (Prefix 20, 21, 22, 28, 29)
  static ScaleBarcodeResult parse(String barcode) {
    final clean = barcode.trim();
    if (clean.length != 13) {
      return ScaleBarcodeResult(isScaleBarcode: false, productCode: '', rawBarcode: clean);
    }

    final prefix = clean.substring(0, 2);
    if (!['20', '21', '22', '28', '29'].contains(prefix)) {
      return ScaleBarcodeResult(isScaleBarcode: false, productCode: '', rawBarcode: clean);
    }

    // Support both 5-digit standard (positions 2..7) and 4-digit standard (positions 2..6)
    final code5 = clean.substring(2, 7);
    final code4 = clean.substring(2, 6);

    // Value can be 5 digits at 7..12 (standard 5-digit item code) or 6..11
    final int val5 = int.tryParse(clean.substring(7, 12)) ?? 0;
    final int val4 = int.tryParse(clean.substring(6, 11)) ?? 0;
    final int value = val5 > 0 ? val5 : val4;

    if (prefix == '20' || prefix == '28') {
      // Weight embedded in grams (e.g. 00350 = 350g = 0.350kg)
      final weightKg = value / 1000.0;
      return ScaleBarcodeResult(
        isScaleBarcode: true,
        productCode: code5,
        productCodeAlt: code4,
        weightKg: weightKg,
        rawBarcode: clean,
      );
    } else {
      // Price embedded (e.g. 00150 = 150 DZD)
      final price = value.toDouble();
      return ScaleBarcodeResult(
        isScaleBarcode: true,
        productCode: code5,
        productCodeAlt: code4,
        embeddedPrice: price,
        rawBarcode: clean,
      );
    }
  }
}