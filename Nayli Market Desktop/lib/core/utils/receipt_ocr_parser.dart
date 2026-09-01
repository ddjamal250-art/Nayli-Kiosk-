import 'dart:math';
import 'package:uuid/uuid.dart';
import '../data/master_catalog_service.dart';
import '../../features/documents/domain/entities/commercial_document.dart';

class ParsedReceiptResult {
  final String entityName;
  final DateTime? date;
  final List<CommercialDocItem> items;
  final double totalAmount;
  final double subtotal;
  final double discount;
  final String rawExtractedText;

  ParsedReceiptResult({
    this.entityName = '',
    this.date,
    required this.items,
    this.totalAmount = 0.0,
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.rawExtractedText = '',
  });
}

class ReceiptOcrParser {
  /// Algerian Retail Vocabulary & Abbreviations Dictionary
  static final Map<String, String> _algerianUnitDictionary = {
    'ctn': 'كرتونة',
    'carton': 'كرتونة',
    'cartons': 'كرتونة',
    'crt': 'كرتونة',
    'fardeau': 'فاردو',
    'fardo': 'فاردو',
    'fard': 'فاردو',
    'bte': 'علبة / باطة',
    'boite': 'علبة / باطة',
    'boites': 'علبة / باطة',
    'u': 'حبة',
    'unite': 'حبة',
    'pcs': 'حبة',
    'piece': 'حبة',
    'kg': 'كغ',
    'kilo': 'كغ',
    'g': 'غرام',
    'gr': 'غرام',
    'l': 'لتر',
    'litre': 'لتر',
    'btl': 'قارورة',
    'bouteille': 'قارورة',
    'sac': 'شكارة',
    'sacs': 'شكارة',
    'sachet': 'كيس',
    'pqt': 'باكي',
    'paquet': 'باكي',
  };

  /// Parses raw text extracted from optical scan into structured commercial document items
  static ParsedReceiptResult parseRawText(String rawText) {
    if (rawText.trim().isEmpty) {
      return ParsedReceiptResult(items: []);
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String detectedEntity = '';
    DateTime? detectedDate;
    final List<CommercialDocItem> extractedItems = [];
    double detectedTotal = 0.0;

    final priceRegex = RegExp(r'(\d+[\.,]?\d*)\s*(?:DA|DZD|دج|da|dzd)?', caseSensitive: false);
    final dateRegex = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 1. Detect Date
      final dateMatch = dateRegex.firstMatch(line);
      if (dateMatch != null && detectedDate == null) {
        try {
          final p1 = int.parse(dateMatch.group(1)!);
          final p2 = int.parse(dateMatch.group(2)!);
          int p3 = int.parse(dateMatch.group(3)!);
          if (p3 < 100) p3 += 2000;
          detectedDate = DateTime(p3, p2, p1);
        } catch (_) {}
      }

      // 2. Detect Entity / Supplier / Client Name in top 5 lines
      if (i < 5 && detectedEntity.isEmpty) {
        if (line.toLowerCase().contains('client') ||
            line.toLowerCase().contains('fournisseur') ||
            line.toLowerCase().contains('societe') ||
            line.toLowerCase().contains('sarl') ||
            line.toLowerCase().contains('ets') ||
            line.toLowerCase().contains('distrib') ||
            line.contains('مؤسسة') ||
            line.contains('السيد') ||
            line.contains('الزبون') ||
            line.contains('المورد') ||
            line.contains('شركة') ||
            line.contains('توزيع')) {
          detectedEntity = line
              .replaceAll(RegExp(r'^(client|fournisseur|societe|sarl|ets|الزبون|المورد|مؤسسة|شركة|توزيع)[\s\:\-]+', caseSensitive: false), '')
              .trim();
        }
      }

      // 3. Skip common table headers
      final lower = line.toLowerCase();
      if (lower.contains('designation') ||
          lower.contains('désignation') ||
          lower.contains('qte') ||
          lower.contains('qté') ||
          lower.contains('prix') ||
          lower.contains('pu ht') ||
          lower.contains('total ht') ||
          lower.contains('ref') ||
          lower.contains('code') ||
          lower.contains('تعيين') ||
          lower.contains('الكمية') ||
          lower.contains('السعر') ||
          lower.contains('المجموع')) {
        continue;
      }

      // 4. Detect Document Total Line
      if (lower.contains('total') ||
          lower.contains('net à payer') ||
          lower.contains('net a payer') ||
          lower.contains('ttc') ||
          lower.contains('reste') ||
          lower.contains('المجموع') ||
          lower.contains('الصافي')) {
        final matches = priceRegex.allMatches(line).toList();
        if (matches.isNotEmpty) {
          final lastMatch = matches.last.group(1)?.replaceAll(',', '.');
          if (lastMatch != null) {
            detectedTotal = double.tryParse(lastMatch) ?? detectedTotal;
          }
        }
        continue;
      }

      // 5. Parse Product Line Item with Intelligent Fuzzy Correction
      final item = _parseItemLine(line);
      if (item != null) {
        extractedItems.add(item);
      }
    }

    // Fallback entity name if first line is a header
    if (detectedEntity.isEmpty && lines.isNotEmpty && !lines[0].toUpperCase().contains('FACTURE') && !lines[0].toUpperCase().contains('BON')) {
      detectedEntity = lines[0];
    }

    final computedSubtotal = extractedItems.fold(0.0, (sum, it) => sum + it.totalHT);

    return ParsedReceiptResult(
      entityName: detectedEntity,
      date: detectedDate ?? DateTime.now(),
      items: extractedItems,
      totalAmount: detectedTotal > 0 ? detectedTotal : computedSubtotal,
      subtotal: computedSubtotal,
      rawExtractedText: rawText,
    );
  }

  static CommercialDocItem? _parseItemLine(String line) {
    final tokens = line.split(RegExp(r'\s{2,}|\t|\s+(?=\d)'));
    if (tokens.length < 2) return null;

    final numRegex = RegExp(r'^\d+[\.,]?\d*$');
    final numbers = <double>[];
    final textParts = <String>[];
    String detectedUnit = 'حبة';

    for (final token in tokens) {
      final clean = token.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll(',', '.');
      final val = double.tryParse(clean);
      if (val != null && numRegex.hasMatch(clean)) {
        numbers.add(val);
      } else if (token.trim().isNotEmpty) {
        final lowerToken = token.trim().toLowerCase();
        if (_algerianUnitDictionary.containsKey(lowerToken)) {
          detectedUnit = _algerianUnitDictionary[lowerToken]!;
        } else {
          textParts.add(token.trim());
        }
      }
    }

    String rawDesignation = textParts.join(' ').trim();
    if (rawDesignation.length < 2) return null;

    // Intelligent Fuzzy Auto-Correction with Algerian Master Catalog
    String correctedDesignation = _fuzzyMatchWithCatalog(rawDesignation);

    double qty = 1.0;
    double unitPrice = 0.0;

    if (numbers.length >= 2) {
      qty = numbers[0];
      unitPrice = numbers[1];
    } else if (numbers.length == 1) {
      unitPrice = numbers[0];
    } else {
      return null;
    }

    return CommercialDocItem(
      id: const Uuid().v4(),
      productId: '',
      designation: correctedDesignation,
      quantity: qty > 0 ? qty : 1.0,
      unitPrice: unitPrice >= 0 ? unitPrice : 0.0,
      unit: detectedUnit,
    );
  }

  /// Fuzzy Match against 59,000 Algerian Catalog Products for spell correction
  static String _fuzzyMatchWithCatalog(String rawName) {
    if (rawName.trim().length < 3) return rawName;

    try {
      final catalogResults = MasterCatalogService.instance.search(rawName, limit: 3);
      if (catalogResults.isNotEmpty) {
        final best = catalogResults.first;
        final similarity = _calculateSimilarity(rawName.toLowerCase(), best.name.toLowerCase());
        // If similarity is above 65%, use the clean standardized catalog name
        if (similarity > 0.65) {
          return best.name;
        }
      }
    } catch (_) {}

    return rawName;
  }

  /// Levenshtein distance based similarity (0.0 to 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = max(s1.length, s2.length);
    final dist = _levenshtein(s1, s2);
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    List<List<int>> d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) d[i][0] = i;
    for (int j = 0; j <= n; j++) d[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        d[i][j] = min(
          min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );
      }
    }
    return d[m][n];
  }
}

