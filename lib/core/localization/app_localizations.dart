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
      'app_name': 'Nayli Market',
      'app_title': 'Nayli Market - إدارة الفوترة والمخزون',
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
      'credit_ledger': 'دفتر الكريدي والديون',
      'credit_ledger_title': 'دفتر ديون الزبائن (Crédit)',
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
      'balance': 'الرصيد',

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

      // Payment & Credit Modes
      'payment_mode': 'طريقة الدفع',
      'pay_cash': 'كاش (نقداً)',
      'pay_credit': 'كريدي كامل (دين)',
      'pay_acompte': 'تسبيق + كريدي',
      'select_customer': 'اختر الزبون',
      'select_customer_hint': 'اضغط لاختيار الزبون المسجل عليه الدين',
      'acompte_amount': 'مبلغ التسبيق المدفوع',
      'remaining_to_credit': 'المبلغ المسجل في الكريدي:',
      'credit_limit_exceeded': 'تحذير: هذا الزبون تجاوز سقف الدين المسموح به!',

      // Customers & Debts
      'total_credit_debts': 'إجمالي الديون المعلقة في المحل',
      'customers_count': 'زبون',
      'search_customer_hint': 'ابحث بالاسم أو برقم الهاتف...',
      'no_customers_found': 'لا يوجد زبائن مسجلين حالياً',
      'add_customer': 'إضافة زبون جديد',
      'add_customer_title': 'تسجيل زبون جديد في الكريدي',
      'customer_name': 'اسم الزبون الكامل',
      'customer_phone': 'رقم الهاتف',
      'customer_address': 'العنوان / الحي',
      'initial_debt': 'الدين الأولي (إن وجد)',
      'max_debt_limit': 'سقف الدين الأقصى (دج)',
      'current_debt': 'الدين الحالي المستحق',
      'total_debt_balance': 'رصيد الدين الكلي',
      'pay_debt': 'تسديد دين',
      'pay_debt_title': 'تسجيل تسديد دين',
      'paid_amount': 'المبلغ المدفوع (دج)',
      'payment_note': 'ملاحظة (اختياري)',
      'confirm_payment': 'تأكيد التسديد وطباعة الوصل',
      'payment_recorded_msg': 'تم تسجيل تسديد الدين بنجاح',
      'pay_now_btn': 'تسديد',
      'debt_transactions_history': 'سجل المعاملات والديون',
      'no_debt_history': 'لا توجد معاملات سابقة لهذا الزبون',
      'credit_purchase': 'شراء بالكريدي',
      'payment_received': 'تسديد دين',
      'enter_valid_amount': 'يرجى إدخال مبلغ صحيح',

      // Quick Items Customization
      'edit_quick_item': 'تعديل السلعة السريعة',
      'add_quick_item': 'إضافة سلعة سريعة جديدة',
      'quick_item_price': 'سعر السلعة (دج)',
      'quick_item_name': 'اسم السلعة',
      'quick_item_icon': 'الأيقونة (إيموجي)',
      'price_updated_msg': 'تم تحديث السعر بنجاح ⚡',

      // Cost & Net Profit
      'cost_price': 'سعر الشراء (التكلفة)',
      'selling_price': 'سعر البيع',
      'net_profit': 'صافي الأرباح',
      'estimated_profit': 'صافي الربح التقديري',
      'profit_margin': 'نسبة هامش الربح',
      'total_cost': 'إجمالي تكلفة السلع',

      // Change Calculator
      'change_calc': 'حاسبة الصرف والباقي',
      'exact_amount': 'المضبوط',
      'change_due': 'الباقي للزبون (الصرف):',
      'insufficient_amount': 'المبلغ المدفوع أقل من الإجمالي المطلوب!',

      // Quick Add Bottom Sheet
      'quick_add_title': 'منتج غير مسجل - إضافة سريعة',
      'master_recognized': 'تم التعرف على المنتج في الكتالوج الجزائري! 🇩🇿',
      'barcode_label': 'باركود',
      'product_name': 'اسم المنتج',
      'initial_stock': 'الكمية الأولية',
      'save_and_add_cart': 'حفظ وإضافة للسلة',
      'saved_product_msg': 'تمت إضافة المنتج بنجاح إلى المخزون والسلة',

      // Stock In
      'stock_in_title': 'استلام السلع / Arrivage',
      'stock_in_hint': 'امسح الباركود بالكاميرا لإضافة كميات جديدة للمخزون فوراً',
      'existing_in_shop': 'مسجل في المحل',
      'new_from_catalog': 'سلعة جديدة (من الكتالوج الجزائري)',
      'new_unregistered': 'سلعة جديدة غير مسجلة',
      'current_stock': 'المخزون الحالي',
      'new_total_stock': 'المخزون الجديد الإجمالي',
      'quantity_to_add': 'الكمية المضافة (الاستلام)',
      'save_stock_in': 'تأكيد وحفظ الاستلام (+)',
      'stock_added_msg': 'تم استلام وزيادة المخزون بنجاح',
      'session_stock_ins': 'السلع المستلمة في هذه الجلسة',

      // Daily Report
      'daily_report_title': 'تقرير اليومية والمبيعات',
      'today_revenue': 'مداخيل اليومية الإجمالية',
      'invoices_count': 'عدد الفواتير',
      'sold_items_count': 'السلع المباعة',
      'today_invoices': 'فواتير اليوم المكتملة',
      'print_z_report': 'طباعة تقرير الإغلاق اليومي (Rapport Z)',
      'no_sales_today': 'لم يتم تسجيل أي مبيعات اليوم حتى الآن',

      // Products List
      'products_title': 'إدارة المنتجات والمخزون',
      'in_stock': 'متوفر',
      'low_stock': 'منخفض',
      'out_of_stock': 'نفد المخزون',
      'add_product': 'إضافة منتج جديد',
      'edit_product': 'تعديل المنتج',
      'export_excel': 'تصدير كملف Excel (CSV)',
      'exported_success': 'تم تصدير الملف بنجاح!',
    },
    'fr': {
      // General & Navigation
      'app_title': 'Caisse & Stock POS',
      'cart': 'Panier',
      'items_count': 'Articles',
      'total_price': 'Total Général',
      'grand_total': 'Total Général',
      'checkout': 'Détails & Paiement',
      'review_order': 'Payer la commande',
      'settings': 'Paramètres',
      'products_management': 'Gestion des Produits & Stock',
      'stock_in': 'Réception / Arrivage',
      'daily_report': 'Rapport Journalier & Bénéfices',
      'shop_details': 'Informations Boutique',
      'credit_ledger': 'Carnet de Crédit (Dettes)',
      'credit_ledger_title': 'Gestion des Crédits Clients',
      'hardware': 'Matériel & Périphériques',
      'print_device': 'Imprimante Tickets',
      'connected': 'Connecté',
      'disconnected': 'Déconnecté',
      'language': 'Langue de l\'application',
      'arabic': 'العربية (AR)',
      'french': 'Français (FR)',
      'english': 'English (EN)',
      'close': 'Fermer',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'search': 'Recherche...',
      'required': 'Champ obligatoire',
      'balance': 'Solde',

      // POS & Scanner
      'camera_off': 'Caméra éteinte',
      'turn_on_camera': 'Allumer la caméra',
      'align_barcode': 'Alignez le code-barres dans le cadre',
      'cart_empty': 'Le panier est vide',
      'cart_empty_hint': 'Scannez un code-barres ou choisissez un article rapide ci-dessus',
      'park_cart': 'En attente',
      'parked_cart_msg': 'Panier mis en attente ⏸️',
      'resume_cart': 'Reprendre',
      'resumed_cart_msg': 'Panier récupéré ▶️',
      'stock_zero_warning': 'Stock: 0',
      'item_name': 'Article',
      'item_price': 'Prix',
      'total': 'Total',
      'quantity': 'Qté',
      'new_invoice': 'Nouveau Ticket',
      'confirm_and_print': 'Valider et Imprimer',
      'reprint': 'Réimprimer Ticket',
      'printed_success': '✅ Transaction enregistrée et ticket imprimé !',

      // Payment & Credit Modes
      'payment_mode': 'Mode de Paiement',
      'pay_cash': 'Espèces (Cash)',
      'pay_credit': 'Crédit Complet',
      'pay_acompte': 'Acompte + Crédit',
      'select_customer': 'Sélectionner un Client',
      'select_customer_hint': 'Cliquez pour choisir le client à débiter',
      'acompte_amount': 'Montant de l\'acompte versé',
      'remaining_to_credit': 'Montant ajouté au crédit:',
      'credit_limit_exceeded': 'Attention : Le client a dépassé son plafond de crédit !',

      // Customers & Debts
      'total_credit_debts': 'Total des Dettes Clients en cours',
      'customers_count': 'clients',
      'search_customer_hint': 'Rechercher par nom ou numéro...',
      'no_customers_found': 'Aucun client enregistré',
      'add_customer': 'Ajouter un Client',
      'add_customer_title': 'Enregistrer un Nouveau Client',
      'customer_name': 'Nom complet du client',
      'customer_phone': 'Numéro de téléphone',
      'customer_address': 'Adresse / Quartier',
      'initial_debt': 'Dette initiale (si existante)',
      'max_debt_limit': 'Plafond max de crédit (DA)',
      'current_debt': 'Dette Actuelle',
      'total_debt_balance': 'Solde Global de Dette',
      'pay_debt': 'Versement Dette',
      'pay_debt_title': 'Enregistrer un Versement',
      'paid_amount': 'Montant versé (DA)',
      'payment_note': 'Note (Optionnel)',
      'confirm_payment': 'Confirmer & Imprimer Reçu',
      'payment_recorded_msg': 'Versement enregistré avec succès',
      'pay_now_btn': 'Payer',
      'debt_transactions_history': 'Historique des Mouvements',
      'no_debt_history': 'Aucun historique pour ce client',
      'credit_purchase': 'Achat à Crédit',
      'payment_received': 'Versement de Dette',
      'enter_valid_amount': 'Veuillez saisir un montant valide',

      // Quick Items Customization
      'edit_quick_item': 'Modifier l\'Article Rapide',
      'add_quick_item': 'Ajouter un Article Rapide',
      'quick_item_price': 'Prix de l\'article (DA)',
      'quick_item_name': 'Nom de l\'article',
      'quick_item_icon': 'Icône (Emoji)',
      'price_updated_msg': 'Prix mis à jour avec succès ⚡',

      // Cost & Net Profit
      'cost_price': 'Prix d\'Achat (Coût)',
      'selling_price': 'Prix de Vente',
      'net_profit': 'Bénéfice Net',
      'estimated_profit': 'Bénéfice Net Estimé',
      'profit_margin': 'Marge Bénéficiaire',
      'total_cost': 'Coût Total des Ventes',

      // Change Calculator
      'change_calc': 'Calculateur de Monnaie',
      'exact_amount': 'Montant Exact',
      'change_due': 'Monnaie à rendre :',
      'insufficient_amount': 'Le montant donné est inférieur au total !',

      // Quick Add Bottom Sheet
      'quick_add_title': 'Article non répertorié - Ajout Rapide',
      'master_recognized': 'Reconnu dans le catalogue Algérie ! 🇩🇿',
      'barcode_label': 'Code-barres',
      'product_name': 'Nom de l\'article',
      'initial_stock': 'Quantité initiale',
      'save_and_add_cart': 'Enregistrer et ajouter au panier',
      'saved_product_msg': 'Article enregistré avec succès',

      // Stock In
      'stock_in_title': 'Réception de Marchandises / Arrivage',
      'stock_in_hint': 'Scannez le code-barres pour ajouter du stock instantanément',
      'existing_in_shop': 'Article existant en boutique',
      'new_from_catalog': 'Nouvel article (Catalogue Algérie)',
      'new_unregistered': 'Nouvel article inconnu',
      'current_stock': 'Stock actuel',
      'new_total_stock': 'Nouveau stock total',
      'quantity_to_add': 'Quantité reçue (+)',
      'save_stock_in': 'Confirmer la réception (+)',
      'stock_added_msg': 'Stock mis à jour avec succès',
      'session_stock_ins': 'Articles reçus cette session',

      // Daily Report
      'daily_report_title': 'Rapport Journalier & Ventes',
      'today_revenue': 'Chiffre d\'Affaires du Jour',
      'invoices_count': 'Nombre de Tickets',
      'sold_items_count': 'Articles Vendus',
      'today_invoices': 'Tickets de la Journée',
      'print_z_report': 'Imprimer Rapport de Clôture (Rapport Z)',
      'no_sales_today': 'Aucune vente enregistrée aujourd\'hui',

      // Products List
      'products_title': 'Gestion des Produits & Stock',
      'in_stock': 'En Stock',
      'low_stock': 'Stock Faible',
      'out_of_stock': 'Épuisé',
      'add_product': 'Ajouter un Produit',
      'edit_product': 'Modifier le Produit',
      'export_excel': 'Exporter en Excel (CSV)',
      'exported_success': 'Exportation réussie !',
    },
    'en': {
      // General & Navigation
      'app_title': 'Billing & Inventory POS',
      'cart': 'Shopping Cart',
      'items_count': 'Items',
      'total_price': 'Grand Total',
      'grand_total': 'Grand Total',
      'checkout': 'Checkout & Payment',
      'review_order': 'Review Order',
      'settings': 'Settings',
      'products_management': 'Products & Inventory',
      'stock_in': 'Stock In / Arrivage',
      'daily_report': 'Daily Report & Profits',
      'shop_details': 'Shop Profile',
      'credit_ledger': 'Credit & Debts Ledger',
      'credit_ledger_title': 'Customer Credit Ledger',
      'hardware': 'Hardware & Devices',
      'print_device': 'Receipt Printer',
      'connected': 'Connected',
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
      'required': 'This field is required',
      'balance': 'Balance',

      // POS & Scanner
      'camera_off': 'Camera Off',
      'turn_on_camera': 'Turn Camera On',
      'align_barcode': 'Align barcode inside scanner frame',
      'cart_empty': 'Cart is empty',
      'cart_empty_hint': 'Scan a barcode or choose a quick item from the top bar',
      'park_cart': 'Hold',
      'parked_cart_msg': 'Cart parked successfully ⏸️',
      'resume_cart': 'Resume',
      'resumed_cart_msg': 'Cart resumed ▶️',
      'stock_zero_warning': 'Stock: 0',
      'item_name': 'Item Name',
      'item_price': 'Price',
      'total': 'Total',
      'quantity': 'Qty',
      'new_invoice': 'New Receipt',
      'confirm_and_print': 'Confirm & Print Receipt',
      'reprint': 'Reprint Receipt',
      'printed_success': '✅ Transaction saved and receipt printed!',

      // Payment & Credit Modes
      'payment_mode': 'Payment Mode',
      'pay_cash': 'Cash (Espèces)',
      'pay_credit': 'Full Credit (Debt)',
      'pay_acompte': 'Deposit + Credit',
      'select_customer': 'Select Customer',
      'select_customer_hint': 'Tap to select customer for credit',
      'acompte_amount': 'Deposit Paid Amount',
      'remaining_to_credit': 'Amount added to Credit:',
      'credit_limit_exceeded': 'Warning: Customer exceeded maximum credit limit!',

      // Customers & Debts
      'total_credit_debts': 'Total Outstanding Customer Debts',
      'customers_count': 'customers',
      'search_customer_hint': 'Search by name or phone...',
      'no_customers_found': 'No registered customers found',
      'add_customer': 'Add Customer',
      'add_customer_title': 'Register New Customer',
      'customer_name': 'Full Customer Name',
      'customer_phone': 'Phone Number',
      'customer_address': 'Address / City',
      'initial_debt': 'Initial Debt (if any)',
      'max_debt_limit': 'Max Debt Limit (DA)',
      'current_debt': 'Current Debt',
      'total_debt_balance': 'Total Debt Balance',
      'pay_debt': 'Pay Debt',
      'pay_debt_title': 'Record Debt Payment',
      'paid_amount': 'Paid Amount (DA)',
      'payment_note': 'Note (Optional)',
      'confirm_payment': 'Confirm & Print Receipt',
      'payment_recorded_msg': 'Debt payment recorded successfully',
      'pay_now_btn': 'Pay',
      'debt_transactions_history': 'Transaction History',
      'no_debt_history': 'No history for this customer',
      'credit_purchase': 'Credit Purchase',
      'payment_received': 'Debt Payment',
      'enter_valid_amount': 'Please enter a valid amount',

      // Quick Items Customization
      'edit_quick_item': 'Edit Quick Item',
      'add_quick_item': 'Add New Quick Item',
      'quick_item_price': 'Item Price (DA)',
      'quick_item_name': 'Item Name',
      'quick_item_icon': 'Icon (Emoji)',
      'price_updated_msg': 'Price updated successfully ⚡',

      // Cost & Net Profit
      'cost_price': 'Cost Price (Purchase)',
      'selling_price': 'Selling Price',
      'net_profit': 'Net Profit',
      'estimated_profit': 'Estimated Net Profit',
      'profit_margin': 'Profit Margin',
      'total_cost': 'Total Cost of Sold Goods',

      // Change Calculator
      'change_calc': 'Change Calculator',
      'exact_amount': 'Exact',
      'change_due': 'Change Due:',
      'insufficient_amount': 'Paid amount is less than total!',

      // Quick Add Bottom Sheet
      'quick_add_title': 'Unregistered Product - Quick Add',
      'master_recognized': 'Recognized from Algerian Master Catalog! 🇩🇿',
      'barcode_label': 'Barcode',
      'product_name': 'Product Name',
      'initial_stock': 'Initial Stock',
      'save_and_add_cart': 'Save and Add to Cart',
      'saved_product_msg': 'Product saved successfully to inventory',

      // Stock In
      'stock_in_title': 'Stock In / Arrivage',
      'stock_in_hint': 'Scan barcode to add new stock instantly',
      'existing_in_shop': 'Existing item in shop',
      'new_from_catalog': 'New item (Algerian Catalog)',
      'new_unregistered': 'New unregistered item',
      'current_stock': 'Current Stock',
      'new_total_stock': 'New Total Stock',
      'quantity_to_add': 'Quantity Received (+)',
      'save_stock_in': 'Confirm Receipt (+)',
      'stock_added_msg': 'Stock increased successfully',
      'session_stock_ins': 'Items received this session',

      // Daily Report
      'daily_report_title': 'Daily Sales Report',
      'today_revenue': 'Today\'s Total Revenue',
      'invoices_count': 'Invoices Count',
      'sold_items_count': 'Sold Items',
      'today_invoices': 'Today\'s Completed Invoices',
      'print_z_report': 'Print Z-Closing Report',
      'no_sales_today': 'No sales recorded today yet',

      // Products List
      'products_title': 'Product & Stock Management',
      'in_stock': 'In Stock',
      'low_stock': 'Low Stock',
      'out_of_stock': 'Out of Stock',
      'add_product': 'Add Product',
      'edit_product': 'Edit Product',
      'export_excel': 'Export to Excel (CSV)',
      'exported_success': 'Exported successfully!',
    },
  };

  String tr(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['ar']?[key] ??
        key;
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

extension TranslationExtension on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
