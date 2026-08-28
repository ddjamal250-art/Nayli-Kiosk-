import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      // General & Navigation
      'app_title': 'تطبيق الفوترة والمخزون',
      'cart': 'سلة المشتريات',
      'items_count': 'أصناف',
      'total_price': 'المجموع الإجمالي',
      'grand_total': 'المجموع الإجمالي',
      'checkout': 'تفاصيل الفاتورة والدفع',
      'review_order': 'متابعة الدفع',
      'settings': 'الإعدادات والخيارات',
      'products_management': 'إدارة المنتجات والمخزون',
      'stock_in': 'استلام السلع / Arrivage',
      'daily_report': 'تقرير اليومية والأرباح',
      'shop_details': 'معلومات المتجر',
      'hardware': 'العتاد والأجهزة',
      'print_device': 'طابعة الفواتير',
      'connected': 'متصل',
      'disconnected': 'غير متصل',
      'language': 'لغة التطبيق',
      'arabic': 'العربية (AR)',
      'french': 'Français (FR)',
      'english': 'English (EN)',
      'close': 'إغلاق',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'search': 'بحث...',
      'required': 'هذا الحقل مطلوب',

      // POS & Scanner
      'camera_off': 'الكاميرا متوقفة',
      'turn_on_camera': 'تشغيل الكاميرا',
      'align_barcode': 'وجّه الكاميرا نحو باركود السلعة',
      'cart_empty': 'السلة فارغة حالياً',
      'cart_empty_hint': 'امسح الباركود بالكاميرا أو اختر سلعة سريعة من الشريط أعلاه',
      'park_cart': 'تعليق',
      'parked_cart_msg': 'تم تعليق الفاتورة بنجاح ⏸️',
      'resume_cart': 'استرجاع',
      'resumed_cart_msg': 'تم استرجاع الفاتورة المعلقة ▶️',
      'stock_zero_warning': 'المخزون: 0',
      'item_name': 'اسم السلعة',
      'item_price': 'السعر',
      'total': 'المجموع',
      'quantity': 'الكمية',
      'new_invoice': 'فاتورة جديدة',
      'confirm_and_print': 'تأكيد البيع وطباعة الوصل',
      'reprint': 'إعادة طباعة الوصل',
      'printed_success': '✅ تم حفظ المعاملة وخصم المخزون والطباعة بنجاح!',

      // Change Calculator
      'change_calc': 'حاسبة الصرف والباقي',
      'paid_amount': 'المبلغ المدفوع من الزبون',
      'exact_amount': 'المضبوط',
      'change_due': 'الباقي للزبون (الصرف):',
      'remaining_due': 'المبلغ المتبقي على الزبون:',

      // Quick Add
      'quick_add_title': 'إضافة منتج جديد وتمريره للكاسة',
      'master_recognized': 'تم التعرف التلقائي من الكتالوج الشامل ⚡',
      'barcode_label': 'الباركود',
      'product_name': 'اسم المنتج',
      'selling_price': 'سعر البيع',
      'initial_stock': 'الكمية الأولية',
      'save_and_add_cart': 'حفظ وإضافة للفاتورة',
      'saved_product_msg': 'تم تسجيل وإضافة المنتج للفاتورة بنجاح!',

      // Stock In (Arrivage)
      'stock_in_title': 'استلام السلع / Arrivage',
      'stock_in_hint': 'وجّه الكاميرا نحو باركود السلعة المستلمة',
      'existing_in_shop': 'منتج مسجل في المحل',
      'current_stock': 'المخزون الحالي',
      'received_qty': 'الكمية المستلمة (قطع / كراتين)',
      'save_stock': 'إدخال للمخزون (Enregistrer Stock)',
      'session_stock_ins': 'السلع المستلمة في هذه الجلسة:',
      'stock_added_msg': '✅ تم إدخال الكمية للمخزون بنجاح',

      // Stock Badges
      'in_stock': 'متوفر',
      'low_stock': 'كمية منخفضة',
      'out_of_stock': 'نفد من المخزن',

      // Daily Report
      'report_title': 'تقرير اليومية والأرباح',
      'date': 'التاريخ',
      'change_date': 'تغيير',
      'total_revenue': 'إجمالي المداخيل',
      'invoices_count': 'عدد الفواتير',
      'today_invoices': 'فواتير اليوم',
      'no_invoices': 'لا توجد فواتير مسجلة في هذا التاريخ',
      'print_z_report': 'طباعة تقرير اليومية (Rapport Z)',
      'z_report_header': 'تقرير اليومية (RAPPORT Z)',
      'items_sold': 'القطع المباعة',
      'report_printed': 'تمت طباعة التقرير اليومي بنجاح!',
    },
    'fr': {
      // General & Navigation
      'app_title': 'Application Caisse & Stock',
      'cart': 'Panier d\'achat',
      'items_count': 'articles',
      'total_price': 'PRIX TOTAL',
      'grand_total': 'TOTAL GÉNÉRAL',
      'checkout': 'Paiement & Facturation',
      'review_order': 'Passer au paiement',
      'settings': 'Paramètres & Options',
      'products_management': 'Gestion des Produits & Stock',
      'stock_in': 'Réception / Arrivage',
      'daily_report': 'Bilan Journalier & Recettes',
      'shop_details': 'Informations du Magasin',
      'hardware': 'Matériel & Périphériques',
      'print_device': 'Imprimante thermique',
      'connected': 'CONNECTÉ',
      'disconnected': 'Non connecté',
      'language': 'Langue de l\'application',
      'arabic': 'العربية (AR)',
      'french': 'Français (FR)',
      'english': 'English (EN)',
      'close': 'Fermer',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'search': 'Rechercher...',
      'required': 'Champ obligatoire',

      // POS & Scanner
      'camera_off': 'Caméra désactivée',
      'turn_on_camera': 'Activer la caméra',
      'align_barcode': 'Alignez le code-barres dans le cadre',
      'cart_empty': 'Le panier est vide',
      'cart_empty_hint': 'Scannez un code-barres ou choisissez un article rapide ci-dessus',
      'park_cart': 'Mettre en attente',
      'parked_cart_msg': 'Panier mis en attente ⏸️',
      'resume_cart': 'Reprendre',
      'resumed_cart_msg': 'Panier en attente repris ▶️',
      'stock_zero_warning': 'Stock: 0',
      'item_name': 'Article',
      'item_price': 'Prix',
      'total': 'Total',
      'quantity': 'Quantité',
      'new_invoice': 'Nouvelle vente',
      'confirm_and_print': 'Valider la vente & Imprimer',
      'reprint': 'Réimprimer le ticket',
      'printed_success': '✅ Vente enregistrée, stock déduit et ticket imprimé !',

      // Change Calculator
      'change_calc': 'Calcul du Rendu de Monnaie',
      'paid_amount': 'Montant versé par le client',
      'exact_amount': 'Exact',
      'change_due': 'Monnaie à rendre au client :',
      'remaining_due': 'Reste à payer par le client :',

      // Quick Add
      'quick_add_title': 'Ajout Rapide & Envoi en Caisse',
      'master_recognized': 'Reconnu automatiquement du catalogue global ⚡',
      'barcode_label': 'Code-barres',
      'product_name': 'Nom du produit',
      'selling_price': 'Prix de vente',
      'initial_stock': 'Quantité initiale',
      'save_and_add_cart': 'Enregistrer & Ajouter au panier',
      'saved_product_msg': 'Produit enregistré et ajouté au panier avec succès !',

      // Stock In (Arrivage)
      'stock_in_title': 'Réception Marchandise / Arrivage',
      'stock_in_hint': 'Scannez le code-barres de la marchandise reçue',
      'existing_in_shop': 'Produit déjà existant en magasin',
      'current_stock': 'Stock actuel',
      'received_qty': 'Quantité reçue (pièces / packs)',
      'save_stock': 'Enregistrer en Stock',
      'session_stock_ins': 'Articles reçus durant cette session :',
      'stock_added_msg': '✅ Quantité ajoutée au stock avec succès',

      // Stock Badges
      'in_stock': 'En stock',
      'low_stock': 'Stock faible',
      'out_of_stock': 'Épuisé',

      // Daily Report
      'report_title': 'Bilan Journalier & Recettes',
      'date': 'Date',
      'change_date': 'Changer',
      'total_revenue': 'Chiffre d\'affaires',
      'invoices_count': 'Nombre de tickets',
      'today_invoices': 'Tickets du jour',
      'no_invoices': 'Aucun ticket enregistré pour cette date',
      'print_z_report': 'Imprimer le Rapport Z',
      'z_report_header': 'RAPPORT JOURNALIER (RAPPORT Z)',
      'items_sold': 'Articles vendus',
      'report_printed': 'Rapport journalier imprimé avec succès !',
    },
    'en': {
      // General & Navigation
      'app_title': 'Billing & Inventory POS',
      'cart': 'Shopping Cart',
      'items_count': 'items',
      'total_price': 'TOTAL PRICE',
      'grand_total': 'GRAND TOTAL',
      'checkout': 'Checkout & Payment',
      'review_order': 'Review Order',
      'settings': 'Settings & Options',
      'products_management': 'Products & Inventory',
      'stock_in': 'Stock In / Arrivage',
      'daily_report': 'Daily Report & Profits',
      'shop_details': 'Shop Information',
      'hardware': 'Hardware & Devices',
      'print_device': 'Thermal Printer',
      'connected': 'CONNECTED',
      'disconnected': 'Disconnected',
      'language': 'App Language',
      'arabic': 'العربية (AR)',
      'french': 'Français (FR)',
      'english': 'English (EN)',
      'close': 'Close',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search...',
      'required': 'Required field',

      // POS & Scanner
      'camera_off': 'Camera is turned off',
      'turn_on_camera': 'Turn on Camera',
      'align_barcode': 'Align barcode within frame',
      'cart_empty': 'Cart is currently empty',
      'cart_empty_hint': 'Scan barcodes with camera or pick quick items above',
      'park_cart': 'Hold Cart',
      'parked_cart_msg': 'Cart parked on hold ⏸️',
      'resume_cart': 'Resume',
      'resumed_cart_msg': 'Parked cart resumed ▶️',
      'stock_zero_warning': 'Stock: 0',
      'item_name': 'Item',
      'item_price': 'Price',
      'total': 'Total',
      'quantity': 'Quantity',
      'new_invoice': 'New Sale',
      'confirm_and_print': 'Confirm Sale & Print Receipt',
      'reprint': 'Re-print Receipt',
      'printed_success': '✅ Sale recorded, stock deducted, and receipt printed!',

      // Change Calculator
      'change_calc': 'Change Calculator',
      'paid_amount': 'Amount Paid by Customer',
      'exact_amount': 'Exact',
      'change_due': 'Change Due to Customer:',
      'remaining_due': 'Remaining Due:',

      // Quick Add
      'quick_add_title': 'Quick Add & Send to Cart',
      'master_recognized': 'Recognized from Global Catalog ⚡',
      'barcode_label': 'Barcode',
      'product_name': 'Product Name',
      'selling_price': 'Selling Price',
      'initial_stock': 'Initial Quantity',
      'save_and_add_cart': 'Save & Add to Bill',
      'saved_product_msg': 'Product saved and added to cart successfully!',

      // Stock In (Arrivage)
      'stock_in_title': 'Stock Reception / Arrivage',
      'stock_in_hint': 'Scan barcode of received items',
      'existing_in_shop': 'Product already in shop inventory',
      'current_stock': 'Current Stock',
      'received_qty': 'Received Quantity (units / packs)',
      'save_stock': 'Save to Stock',
      'session_stock_ins': 'Items received in this session:',
      'stock_added_msg': '✅ Stock quantity added successfully',

      // Stock Badges
      'in_stock': 'In stock',
      'low_stock': 'Low stock',
      'out_of_stock': 'Out of stock',

      // Daily Report
      'report_title': 'Daily Sales & Profits Report',
      'date': 'Date',
      'change_date': 'Change',
      'total_revenue': 'Total Revenue',
      'invoices_count': 'Invoices Count',
      'today_invoices': 'Today\'s Invoices',
      'no_invoices': 'No sales recorded on this date',
      'print_z_report': 'Print Daily Z-Report',
      'z_report_header': 'DAILY SUMMARY (Z-REPORT)',
      'items_sold': 'Items Sold',
      'report_printed': 'Daily report printed successfully!',
    },
  };

  String tr(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['ar']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'fr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationExtension on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
