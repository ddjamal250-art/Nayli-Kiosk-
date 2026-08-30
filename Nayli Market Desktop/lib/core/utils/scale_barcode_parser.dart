class ScaleBarcodeResult {
  final bool isScaleBarcode;
  final String productCode;
  final double? weightKg;
  final double? embeddedPrice;
  final String rawBarcode;

  ScaleBarcodeResult({
    required this.isScaleBarcode,
    required this.productCode,
    this.weightKg,
    this.embeddedPrice,
    required this.rawBarcode,
  });
}

class ScaleBarcodeParser {
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

    final productCode = clean.substring(2, 6);
    final valueStr = clean.substring(6, 11);
    final int value = int.tryParse(valueStr) ?? 0;

    if (prefix == '20' || prefix == '28') {
      // Weight embedded in grams (e.g. 00350 = 350g = 0.350kg)
      final weightKg = value / 1000.0;
      return ScaleBarcodeResult(
        isScaleBarcode: true,
        productCode: productCode,
        weightKg: weightKg,
        rawBarcode: clean,
      );
    } else {
      // Price embedded (e.g. 00150 = 150 DZD)
      final price = value.toDouble();
      return ScaleBarcodeResult(
        isScaleBarcode: true,
        productCode: productCode,
        embeddedPrice: price,
        rawBarcode: clean,
      );
    }
  }
}