import 'import_result.dart';

/// يصنف الجداول والأعمدة ذكياً باستخدام قاموس متعدد اللغات.
class SmartFieldMapper {

  /// تصنيف جدول بناءً على اسمه + أعمدته
  static TableType classifyTable(String tableName, List<ColumnInfo> columns) {
    final name = tableName.toLowerCase().trim();
    final colNames = columns.map((c) => c.name.toLowerCase()).toSet();

    // 1. التطابق المباشر الدقيق (Exact Name Priority)
    if (name == 'products' || name == 'product' || name == 'articles' || name == 'items') return TableType.products;
    if (name == 'clients' || name == 'client' || name == 'customers' || name == 'customer') return TableType.customers;
    if (name == 'suppliers' || name == 'supplier' || name == 'fournisseurs') return TableType.suppliers;
    if (name == 'groups' || name == 'categories' || name == 'category') return TableType.categories;
    if (name == 'payments' || name == 'payment' || name == 'reglements') return TableType.payments;
    if (name == 'saleorders' || name == 'sales' || name == 'invoices' || name == 'factures') return TableType.sales;

    // استبعاد الجداول الفرعية وجداول الربط والأسعار من أن تؤخذ كجدول رئيسي للمنتجات أو الزبائن
    if (name.contains('item') || name.contains('price') || name.contains('pack') || name.contains('movement') || name.contains('_')) {
      return TableType.unknown;
    }

    // --- المستوى 1: اسم الجدول ---
    if (_matchesAny(name, _customerTableNames)) return TableType.customers;
    if (_matchesAny(name, _supplierTableNames)) return TableType.suppliers;
    if (_matchesAny(name, _productTableNames)) return TableType.products;
    if (_matchesAny(name, _categoryTableNames)) return TableType.categories;
    if (_matchesAny(name, _paymentTableNames)) return TableType.payments;
    if (_matchesAny(name, _saleTableNames)) return TableType.sales;

    // --- المستوى 2: تحليل الأعمدة ---
    final hasName = colNames.any((c) => _nameColumns.contains(c));
    final hasPhone = colNames.any((c) => _phoneColumns.contains(c));
    final hasFiscal = colNames.any((c) => _fiscalColumns.contains(c));
    final hasBarcode = colNames.any((c) => _barcodeColumns.contains(c));
    final hasPrice = colNames.any((c) => c.contains('price') || c.contains('prix') || c.contains('سعر'));

    if (hasName && hasPhone && hasFiscal) return TableType.suppliers;
    if (hasName && hasPhone && !hasBarcode && !hasPrice) return TableType.customers;
    if (hasName && (hasBarcode || hasPrice)) return TableType.products;

    return TableType.unknown;
  }

  /// أي عمود مصدر يقابل أي حقل هدف
  static String? mapColumnToField(String columnName, TableType tableType) {
    final col = columnName.toLowerCase().trim();

    // --- حقول مشتركة ---
    if (_nameColumns.contains(col)) return 'name';
    if (_addressColumns.contains(col)) return 'address';
    if (_phone1Columns.contains(col)) return 'phone1';
    if (_phone2Columns.contains(col)) return 'phone2';
    if (_createdAtColumns.contains(col)) return 'createdAt';

    // --- حقول الموردين ---
    if (tableType == TableType.suppliers || tableType == TableType.customers) {
      if (_registerColumns.contains(col)) return 'register';
      if (_nifColumns.contains(col)) return 'nif';
      if (_aiColumns.contains(col)) return 'ai';
      if (_nisColumns.contains(col)) return 'nis';
    }

    // --- حقول المنتجات ---
    if (tableType == TableType.products) {
      if (_barcodeColumns.contains(col)) return 'barcode';
      if (_sellPriceColumns.contains(col)) return 'price';
      if (_costPriceColumns.contains(col)) return 'costPrice';
      if (_stockColumns.contains(col)) return 'stock';
      if (_categoryColumns.contains(col)) return 'category';
      if (_imageColumns.contains(col)) return 'image';
      if (_expiryColumns.contains(col)) return 'expiryDate';
      if (_unitColumns.contains(col)) return 'unit';
    }

    return null; // عمود غير معروف
  }

  // ===================== القواميس =====================

  static bool _matchesAny(String value, List<String> patterns) {
    return patterns.any((p) => value.contains(p));
  }

  static const _customerTableNames = ['client', 'customer', 'زبون', 'زبائن', 'acheteur', 'buyer'];
  static const _supplierTableNames = ['supplier', 'fournisseur', 'مورد', 'موردين', 'vendor', 'provider'];
  static const _productTableNames = ['product', 'article', 'منتج', 'منتجات', 'item', 'marchandise'];
  static const _categoryTableNames = ['group', 'category', 'categorie', 'فئة', 'صنف', 'famille', 'rayon'];
  static const _paymentTableNames = ['payment', 'paiement', 'دفعة', 'versement', 'reglement'];
  static const _saleTableNames = ['sale', 'vente', 'مبيعات', 'facture', 'invoice', 'order'];

  static const _nameColumns = ['name', 'nom', 'الاسم', 'اسم', 'clientname', 'fullname', 'titre', 'designation'];
  static const _phoneColumns = ['phone', 'phone1', 'tel', 'tel1', 'telephone', 'الهاتف', 'mobile', 'gsm', 'phone2', 'tel2', 'الهاتف2', 'fax'];
  static const _phone1Columns = ['phone', 'phone1', 'tel', 'tel1', 'telephone', 'الهاتف', 'mobile', 'gsm'];
  static const _phone2Columns = ['phone2', 'tel2', 'الهاتف2', 'fax', 'mobile2'];
  static const _addressColumns = ['address', 'adresse', 'العنوان', 'ville', 'city', 'location', 'adr'];
  static const _fiscalColumns = ['register', 'rc', 'registre', 'السجل', 'commercial_register', 'reg_commerce', 'nif', 'الرقم_الجبائي', 'tax_id', 'fiscal', 'num_fiscal', 'ai', 'المادة', 'article_imposition', 'art_imp', 'nis', 'الضمان', 'social_security', 'num_stat', 'stat'];
  static const _registerColumns = ['register', 'rc', 'registre', 'السجل', 'commercial_register', 'reg_commerce'];
  static const _nifColumns = ['nif', 'الرقم_الجبائي', 'tax_id', 'fiscal', 'num_fiscal'];
  static const _aiColumns = ['ai', 'المادة', 'article_imposition', 'art_imp'];
  static const _nisColumns = ['nis', 'الضمان', 'social_security', 'num_stat', 'stat'];
  static const _barcodeColumns = ['barcode', 'code', 'ean', 'upc', 'الباركود', 'code_barre', 'codebar'];
  static const _sellPriceColumns = ['sellingprice', 'price', 'prix', 'prix_vente', 'sell_price', 'سعر_البيع', 'pv'];
  static const _costPriceColumns = ['cost', 'costprice', 'prix_achat', 'سعر_الشراء', 'buying_price', 'purchase_price', 'pa'];
  static const _stockColumns = ['stock', 'quantity', 'الكمية', 'quantite', 'qty', 'remaining', 'qte'];
  static const _categoryColumns = ['category', 'group', 'الفئة', 'الصنف', 'categorie', 'famille', 'rayon'];
  static const _imageColumns = ['image', 'photo', 'img', 'picture', 'الصورة', 'logo'];
  static const _expiryColumns = ['expiration', 'expiry', 'exp_date', 'تاريخ_الانتهاء', 'peremption', 'dlc'];
  static const _unitColumns = ['unit', 'unite', 'الوحدة', 'customunits', 'mesure'];
  static const _createdAtColumns = ['createdat', 'created_at', 'date_creation', 'تاريخ_الانشاء', 'date_ajout'];
}
