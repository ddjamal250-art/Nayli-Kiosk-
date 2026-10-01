/// حدث تحليل واحد يُبث في الـ Stream
class AnalysisEvent {
  final String phase;      // 'discovery' | 'classify' | 'debts' | 'products' | 'complete'
  final double progress;   // 0.0 → 1.0
  final String message;    // الرسالة المعروضة في الكونسول
  final String? icon;      // '✅' | '⏳' | '💰' | '🔍' | '❌'
  final AnalysisSummary? summary; // null حتى تكتمل العملية

  const AnalysisEvent({
    required this.phase,
    required this.progress,
    required this.message,
    this.icon,
    this.summary,
  });
}

/// ملخص التحليل النهائي
class AnalysisSummary {
  final int customersFound;
  final int suppliersFound;
  final int productsFound;
  final int categoriesFound;
  final int imagesFound;
  final Map<int, double> customerDebts;  // sourceId → debt amount
  final Map<int, double> supplierDebts;  // sourceId → debt amount
  final List<String> warnings;

  const AnalysisSummary({
    this.customersFound = 0,
    this.suppliersFound = 0,
    this.productsFound = 0,
    this.categoriesFound = 0,
    this.imagesFound = 0,
    this.customerDebts = const {},
    this.supplierDebts = const {},
    this.warnings = const [],
  });
}

/// نتيجة الاستيراد النهائية
class ImportResult {
  final int customersImported;
  final int suppliersImported;
  final int productsImported;
  final int imagesImported;
  final int skippedCount;
  final int errorCount;
  final List<ImportSkipRecord> skippedRecords;
  final List<ImportErrorRecord> errorRecords;
  final Duration duration;

  const ImportResult({
    this.customersImported = 0,
    this.suppliersImported = 0,
    this.productsImported = 0,
    this.imagesImported = 0,
    this.skippedCount = 0,
    this.errorCount = 0,
    this.skippedRecords = const [],
    this.errorRecords = const [],
    this.duration = Duration.zero,
  });
}

class ImportSkipRecord {
  final String tableName;
  final String recordName;
  final String reason;
  const ImportSkipRecord({required this.tableName, required this.recordName, required this.reason});
}

class ImportErrorRecord {
  final String tableName;
  final String recordName;
  final String error;
  const ImportErrorRecord({required this.tableName, required this.recordName, required this.error});
}

/// تصنيف الجدول المكتشف
enum TableType { customers, suppliers, products, categories, payments, sales, images, unknown }

/// معلومات عمود مكتشف
class ColumnInfo {
  final String name;
  final String type;
  final bool isNullable;
  const ColumnInfo({required this.name, required this.type, required this.isNullable});
}

/// جدول مكتشف مع بياناته
class DiscoveredTable {
  final String name;
  final TableType type;
  final List<ColumnInfo> columns;
  final int rowCount;
  const DiscoveredTable({required this.name, required this.type, required this.columns, required this.rowCount});
}
