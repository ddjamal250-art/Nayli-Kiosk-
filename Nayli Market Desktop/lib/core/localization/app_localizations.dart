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
      'app_name': 'Nayli Market Pro',
      'app_title': 'Nayli Market - إدارة الفوترة ونقاط البيع الذكية',
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

      // POS, Scanner & Actions
      'camera_off': 'الكاميرا متوقفة',
      'turn_on_camera': 'تشغيل الكاميرا',
      'align_barcode': 'وجّه الكاميرا نحو باركود السلعة',
      'cart_empty': 'السلة فارغة حالياً',
      'cart_empty_hint': 'امسح الباركود بالكاميرا أو اختر سلعة سريعة من الشريط أعلاه',
      'clear_cart': 'إفراغ السلة',
      'clear_cart_confirm': 'هل أنت متأكد من حذف جميع السلع الممسوحة في هذه السلة والبدء من جديد؟',
      'park_cart': 'تعليق في سلة مؤقتة',
      'parked_cart_msg': 'تم تعليق الفاتورة بنجاح ⏸️',
      'resume_cart': 'استرجاع السلة',
      'resumed_cart_msg': 'تم استرجاع الفاتورة المعلقة ▶️',
      'held_carts': 'السلات المؤقتة المعلقة',
      'return_mode': 'وضع الإرجاع والاستبدال 🔄',
      'return_mode_active': 'وضع الإرجاع مفعّل (Mode Retour)',
      'return_mode_hint': 'سيتم استرجاع السلع وإعادتها للمخزون وإعادة المبلغ للزبون',
      'discount': 'تخفيض / Remise',
      'apply_discount': 'تطبيق التخفيض',
      'remove_discount': 'حذف التخفيض',
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

      // Scale & Weighable (Vrac)
      'scale_calculator': 'حاسبة سلع الميزان والتجزئة (Vrac)',
      'add_weighable_item': 'إضافة مادة ميزان جديدة',
      'supply_method': 'طريقة التوريد والمخزون',
      'by_bags': 'بالأكياس / الشكاير',
      'by_direct_kg': 'بالكيلوغرام المباشر',
      'bags_count': 'عدد الشكاير',
      'bag_weight': 'وزن الشكارة (كغ)',
      'total_calculated_stock': 'المخزون المحسوب الكلي',
      'price_per_kg': 'سعر الكيلو (دج)',
      'cost_per_kg': 'سعر التكلفة للكيلو (دج)',
      'supplier_name': 'اسم المورد / شركة التوزيع',
      'weighable_stock': 'مخزون الميزان',

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

      // Stock In & Supplier Invoices
      'stock_in_title': 'استلام السلع / Arrivage',
      'stock_in_hint': 'امسح الباركود لزيادة المخزون فورياً',
      'supplier_invoices': 'فواتير الموردين والمشتريات',
      'new_supplier_invoice': 'فاتورة مورد جديدة',
      'settle_supplier_debt': 'تسديد دين للمورد',
      'total_purchases': 'إجمالي المشتريات',
      'remaining_debt': 'الدين المتبقي',

      // Expenses & Cashier Shifts
      'store_expenses': 'مصاريف ونفقات المحل',
      'record_expense': 'تسجيل مصروف',
      'today_expenses': 'مصاريف اليوم',
      'month_expenses': 'مصاريف الشهر',
      'cashier_shifts': 'مناوبات الكاسة والصندوق',
      'devis_proforma': 'عروض الأسعار والفواتير المبدئية',
      'receipt_designer': 'تخصيص وتصميم الوصل الحراري',
      'security_pin_title': 'رمز الأمان PIN للمالك 🔒',

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
      'app_name': 'Nayli Market Pro',
      'app_title': 'Nayli Market - Caisse & Stock POS',
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

      // POS, Scanner & Actions
      'camera_off': 'Caméra éteinte',
      'turn_on_camera': 'Allumer la caméra',
      'align_barcode': 'Alignez le code-barres dans le cadre',
      'cart_empty': 'Le panier est vide',
      'cart_empty_hint': 'Scannez un code-barres ou choisissez un article rapide ci-dessus',
      'clear_cart': 'Vider le panier',
      'clear_cart_confirm': 'Voulez-vous vraiment vider tout le panier et recommencer ?',
      'park_cart': 'Mettre en attente',
      'parked_cart_msg': 'Panier mis en attente ⏸️',
      'resume_cart': 'Reprendre le panier',
      'resumed_cart_msg': 'Panier récupéré ▶️',
      'held_carts': 'Paniers en attente',
      'return_mode': 'Mode Retour 🔄',
      'return_mode_active': 'Mode Retour Activé',
      'return_mode_hint': 'Les articles seront réintégrés au stock et remboursés',
      'discount': 'Remise',
      'apply_discount': 'Appliquer la remise',
      'remove_discount': 'Supprimer la remise',
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
      'pay_debt_title': 'Enregistrer un Règlement de Dette',
      'paid_amount': 'Montant Versé (DA)',
      'payment_note': 'Note (Optionnel)',
      'confirm_payment': 'Confirmer & Imprimer Reçu',
      'payment_recorded_msg': 'Règlement enregistré avec succès',
      'pay_now_btn': 'Régler',
      'debt_transactions_history': 'Historique des Transactions',
      'no_debt_history': 'Aucun historique pour ce client',
      'credit_purchase': 'Achat à Crédit',
      'payment_received': 'Versement Dette',
      'enter_valid_amount': 'Veuillez saisir un montant valide',

      // Scale & Weighable (Vrac)
      'scale_calculator': 'Calculateur Balance & Vrac',
      'add_weighable_item': 'Ajouter un article de balance',
      'supply_method': 'Méthode d\'approvisionnement',
      'by_bags': 'Par sacs / cartons',
      'by_direct_kg': 'Au kilogramme direct',
      'bags_count': 'Nombre de sacs',
      'bag_weight': 'Poids du sac (kg)',
      'total_calculated_stock': 'Stock total calculé',
      'price_per_kg': 'Prix au kilo (DA)',
      'cost_per_kg': 'Prix de revient au kilo (DA)',
      'supplier_name': 'Nom du fournisseur',
      'weighable_stock': 'Stock Vrac',

      // Quick Items Customization
      'edit_quick_item': 'Modifier Article Rapide',
      'add_quick_item': 'Nouvel Article Rapide',
      'quick_item_price': 'Prix de l\'article (DA)',
      'quick_item_name': 'Nom de l\'article',
      'quick_item_icon': 'Icône (Émoji)',
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
      'quick_add_title': 'Produit non enregistré - Ajout rapide',
      'master_recognized': 'Reconnu dans le catalogue algérien ! 🇩🇿',
      'barcode_label': 'Code-barres',
      'product_name': 'Nom du produit',
      'initial_stock': 'Quantité initiale',
      'save_and_add_cart': 'Enregistrer et ajouter au panier',
      'saved_product_msg': 'Produit ajouté au stock et au panier',

      // Stock In & Supplier Invoices
      'stock_in_title': 'Réception / Arrivage',
      'stock_in_hint': 'Scannez le code-barres pour ajouter du stock',
      'supplier_invoices': 'Factures Fournisseurs',
      'new_supplier_invoice': 'Nouvelle Facture Fournisseur',
      'settle_supplier_debt': 'Régler Dette Fournisseur',
      'total_purchases': 'Achats Totaux',
      'remaining_debt': 'Dette Restante',

      // Expenses & Cashier Shifts
      'store_expenses': 'Dépenses & Charges du Magasin',
      'record_expense': 'Enregistrer une dépense',
      'today_expenses': 'Dépenses du jour',
      'month_expenses': 'Dépenses du mois',
      'cashier_shifts': 'Sessions de Caisse (Fond de caisse)',
      'devis_proforma': 'Devis & Pro-forma',
      'receipt_designer': 'Personnalisation du ticket',
      'security_pin_title': 'Code PIN Sécurité Propriétaire 🔒',

      // Daily Report
      'daily_report_title': 'Rapport Journalier des Ventes',
      'today_revenue': 'Recette Totale du Jour',
      'invoices_count': 'Nombre de Tickets',
      'sold_items_count': 'Articles Vendus',
      'today_invoices': 'Tickets Réalisés Aujourd\'hui',
      'print_z_report': 'Imprimer le Rapport Z',
      'no_sales_today': 'Aucune vente enregistrée pour le moment',

      // Products List
      'products_title': 'Gestion des Produits & Stock',
      'in_stock': 'En Stock',
      'low_stock': 'Stock Faible',
      'out_of_stock': 'Épuisé',
      'add_product': 'Ajouter un Produit',
      'edit_product': 'Modifier le Produit',
      'export_excel': 'Exporter vers Excel (CSV)',
      'exported_success': 'Exportation réussie !',
    },
    'en': {
      // General & Navigation
      'app_name': 'Nayli Market Pro',
      'app_title': 'Nayli Market - Smart POS & Inventory Management',
      'cart': 'Shopping Cart',
      'items_count': 'Items',
      'total_price': 'Grand Total',
      'grand_total': 'Grand Total',
      'checkout': 'Invoice Details & Payment',
      'review_order': 'Checkout Order',
      'settings': 'Settings & Preferences',
      'products_management': 'Products & Stock Management',
      'stock_in': 'Stock In / Arrivage',
      'daily_report': 'Daily Sales & Profit Report',
      'shop_details': 'Store Information',
      'credit_ledger': 'Customer Credit Ledger',
      'credit_ledger_title': 'Customer Credit & Debt Management',
      'hardware': 'Hardware & Devices',
      'print_device': 'Thermal Receipt Printer',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'language': 'Application Language',
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

      // POS, Scanner & Actions
      'camera_off': 'Camera is turned off',
      'turn_on_camera': 'Turn on camera',
      'align_barcode': 'Align barcode inside frame',
      'cart_empty': 'Cart is currently empty',
      'cart_empty_hint': 'Scan barcode with camera or tap quick item above',
      'clear_cart': 'Clear Cart',
      'clear_cart_confirm': 'Are you sure you want to clear all items in this cart and start fresh?',
      'park_cart': 'Hold Cart',
      'parked_cart_msg': 'Cart parked successfully ⏸️',
      'resume_cart': 'Resume Cart',
      'resumed_cart_msg': 'Held cart restored ▶️',
      'held_carts': 'Held Carts',
      'return_mode': 'Return & Refund Mode 🔄',
      'return_mode_active': 'Return Mode Active',
      'return_mode_hint': 'Items will be returned to stock and refunded to customer',
      'discount': 'Discount',
      'apply_discount': 'Apply Discount',
      'remove_discount': 'Remove Discount',
      'stock_zero_warning': 'Stock: 0',
      'item_name': 'Item Name',
      'item_price': 'Price',
      'total': 'Total',
      'quantity': 'Qty',
      'new_invoice': 'New Invoice',
      'confirm_and_print': 'Confirm & Print Receipt',
      'reprint': 'Reprint Receipt',
      'printed_success': '✅ Sale recorded, stock adjusted and receipt printed!',

      // Payment & Credit Modes
      'payment_mode': 'Payment Method',
      'pay_cash': 'Cash',
      'pay_credit': 'Full Credit (Debt)',
      'pay_acompte': 'Deposit + Credit',
      'select_customer': 'Select Customer',
      'select_customer_hint': 'Tap to select customer for credit record',
      'acompte_amount': 'Deposit Paid Amount',
      'remaining_to_credit': 'Remaining Debt Added:',
      'credit_limit_exceeded': 'Warning: Customer exceeded maximum debt limit!',

      // Customers & Debts
      'total_credit_debts': 'Total Customer Debts in Store',
      'customers_count': 'customers',
      'search_customer_hint': 'Search by name or phone...',
      'no_customers_found': 'No customers registered yet',
      'add_customer': 'Add New Customer',
      'add_customer_title': 'Register New Customer in Credit Book',
      'customer_name': 'Customer Full Name',
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

      // Scale & Weighable (Vrac)
      'scale_calculator': 'Weighing Scale & Bulk Calculator',
      'add_weighable_item': 'Add New Weighable Item',
      'supply_method': 'Supply Method & Stock',
      'by_bags': 'By Bags / Sacks',
      'by_direct_kg': 'Direct Kilograms',
      'bags_count': 'Bags Count',
      'bag_weight': 'Bag Weight (kg)',
      'total_calculated_stock': 'Total Calculated Stock',
      'price_per_kg': 'Price per Kg (DA)',
      'cost_per_kg': 'Cost per Kg (DA)',
      'supplier_name': 'Supplier Name',
      'weighable_stock': 'Weighable Stock',

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

      // Stock In & Supplier Invoices
      'stock_in_title': 'Stock In / Arrivage',
      'stock_in_hint': 'Scan barcode to add new stock instantly',
      'supplier_invoices': 'Supplier Invoices & Purchases',
      'new_supplier_invoice': 'New Supplier Invoice',
      'settle_supplier_debt': 'Settle Supplier Debt',
      'total_purchases': 'Total Purchases',
      'remaining_debt': 'Remaining Debt',

      // Expenses & Cashier Shifts
      'store_expenses': 'Store Expenses & Utilities',
      'record_expense': 'Record Expense',
      'today_expenses': 'Today\'s Expenses',
      'month_expenses': 'Monthly Expenses',
      'cashier_shifts': 'Cashier Shifts (Cash Drawer)',
      'devis_proforma': 'Estimates & Quotations (Devis)',
      'receipt_designer': 'Thermal Receipt Designer',
      'security_pin_title': 'Owner Security PIN 🔒',

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
