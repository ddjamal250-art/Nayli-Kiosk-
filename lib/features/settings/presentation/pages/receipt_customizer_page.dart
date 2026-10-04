import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../billing/presentation/widgets/printer_selection_dialog.dart';

class _ReceiptSectionInfo {
  final String id;
  final String title;
  final IconData icon;
  final bool hasAlignment;
  final bool canDisable;
  final bool isSeparator;

  const _ReceiptSectionInfo({
    required this.id,
    required this.title,
    required this.icon,
    this.hasAlignment = true,
    this.canDisable = true,
    this.isSeparator = false,
  });
}

const Map<String, _ReceiptSectionInfo> kReceiptSectionsInfo = {
  'header': _ReceiptSectionInfo(
    id: 'header',
    title: 'اسم المحل / المتجر',
    icon: Icons.storefront_rounded,
    hasAlignment: true,
    canDisable: false,
  ),
  'slogan': _ReceiptSectionInfo(
    id: 'slogan',
    title: 'الشعار أو عبارة الترحيب',
    icon: Icons.chat_bubble_outline_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'address': _ReceiptSectionInfo(
    id: 'address',
    title: 'عنوان المتجر والموقع',
    icon: Icons.location_on_outlined,
    hasAlignment: true,
    canDisable: true,
  ),
  'phone': _ReceiptSectionInfo(
    id: 'phone',
    title: 'رقم هاتف المتجر',
    icon: Icons.phone_outlined,
    hasAlignment: true,
    canDisable: true,
  ),
  'fiscal': _ReceiptSectionInfo(
    id: 'fiscal',
    title: 'السجل التجاري والضرائب (NIF/RC)',
    icon: Icons.receipt_long_outlined,
    hasAlignment: true,
    canDisable: true,
  ),
  'social': _ReceiptSectionInfo(
    id: 'social',
    title: 'حسابات التواصل الاجتماعي',
    icon: Icons.share_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'sep_1': _ReceiptSectionInfo(
    id: 'sep_1',
    title: 'خط فاصل علوي',
    icon: Icons.horizontal_rule_rounded,
    hasAlignment: false,
    canDisable: true,
    isSeparator: true,
  ),
  'invoice_info': _ReceiptSectionInfo(
    id: 'invoice_info',
    title: 'رقم الفاتورة والتاريخ والوقت',
    icon: Icons.confirmation_number_outlined,
    hasAlignment: false,
    canDisable: false,
  ),
  'cashier': _ReceiptSectionInfo(
    id: 'cashier',
    title: 'اسم الكاشير أو المنفذ',
    icon: Icons.person_outline_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'sep_2': _ReceiptSectionInfo(
    id: 'sep_2',
    title: 'خط فاصل جدول السلع',
    icon: Icons.horizontal_rule_rounded,
    hasAlignment: false,
    canDisable: true,
    isSeparator: true,
  ),
  'items': _ReceiptSectionInfo(
    id: 'items',
    title: 'جدول المبيعات (السلعة، الكمية، السعر)',
    icon: Icons.shopping_cart_outlined,
    hasAlignment: false,
    canDisable: false,
  ),
  'sep_3': _ReceiptSectionInfo(
    id: 'sep_3',
    title: 'خط فاصل المجاميع',
    icon: Icons.horizontal_rule_rounded,
    hasAlignment: false,
    canDisable: true,
    isSeparator: true,
  ),
  'totals': _ReceiptSectionInfo(
    id: 'totals',
    title: 'المجاميع والتخفيض والمدفوع والباقي',
    icon: Icons.calculate_outlined,
    hasAlignment: false,
    canDisable: false,
  ),
  'credit_info': _ReceiptSectionInfo(
    id: 'credit_info',
    title: 'بيانات ديون كريدي الزبون',
    icon: Icons.account_balance_wallet_outlined,
    hasAlignment: false,
    canDisable: true,
  ),
  'extra_lines': _ReceiptSectionInfo(
    id: 'extra_lines',
    title: 'أسطر حرة إعلانية مخصصة',
    icon: Icons.playlist_add_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'footer': _ReceiptSectionInfo(
    id: 'footer',
    title: 'سياسة الاسترجاع والشروط',
    icon: Icons.info_outline_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'thank_you': _ReceiptSectionInfo(
    id: 'thank_you',
    title: 'عبارة الشكر والختام',
    icon: Icons.favorite_border_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
  'barcode': _ReceiptSectionInfo(
    id: 'barcode',
    title: 'رمز الاستجابة السريعة / الباركود',
    icon: Icons.qr_code_2_rounded,
    hasAlignment: true,
    canDisable: true,
  ),
};

class ReceiptCustomizerPage extends StatefulWidget {
  ReceiptCustomizerPage({super.key});

  @override
  State<ReceiptCustomizerPage> createState() => _ReceiptCustomizerPageState();
}

class _ReceiptCustomizerPageState extends State<ReceiptCustomizerPage> {
  // Immutable Core Fields (Only editable, cannot be deleted)
  late TextEditingController _shopNameCtrl;

  // Optional Customizable & Deletable Fields
  bool _showSlogan = true;
  late TextEditingController _sloganCtrl;

  bool _showAddress = true;
  late TextEditingController _addressCtrl;

  bool _showPhone = true;
  late TextEditingController _phoneCtrl;

  bool _showFiscalInfo = false;
  late TextEditingController _fiscalCtrl;

  bool _showCashierName = true;
  late TextEditingController _cashierCtrl;

  bool _showSocialMedia = false;
  late TextEditingController _socialCtrl;

  bool _showFooterNote = true;
  late TextEditingController _footerNoteCtrl;

  bool _showThankYou = true;
  late TextEditingController _thankYouCtrl;

  bool _showBarcodeAtBottom = true;

  String _separatorStyle = 'dashed'; // dashed, stars, double, dots
  String _headerAlignment = 'center'; // center, left, right

  // Receipt Paper Dimensions
  String _paperSize = '80mm'; // '80mm', '58mm', 'custom'
  double _paperWidthMm = 80.0;
  double _receiptMarginMm = 6.0;
  late TextEditingController _paperWidthCtrl;
  late TextEditingController _marginCtrl;

  List<String> _customExtraLines = [];

  // Modular Layout & Ordering Engine
  List<String> _sectionOrder = [];
  Map<String, String> _sectionAlignments = {};
  int _previewRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  void _loadTemplate() {
    final box = HiveDatabase.settingsBox;
    final saved = box.get('receipt_template');
    final shopBox = HiveDatabase.shopBox;
    final defaultShopName = shopBox.isNotEmpty ? shopBox.values.first.name : 'متجر الأناقة والمواد الغذائية';
    final defaultPhone = shopBox.isNotEmpty ? shopBox.values.first.phoneNumber : '0550 12 34 56';
    final defaultAddress = shopBox.isNotEmpty ? shopBox.values.first.addressLine1 : 'حي 500 مسكن، الجلفة';

    if (saved is Map) {
      final map = Map<String, dynamic>.from(saved);
      _shopNameCtrl = TextEditingController(text: map['shopName']?.toString() ?? defaultShopName);
      _showSlogan = map['showSlogan'] == true;
      _sloganCtrl = TextEditingController(text: map['slogan']?.toString() ?? 'مرحباً بكم في متجرنا');
      _showAddress = map['showAddress'] != false;
      _addressCtrl = TextEditingController(text: map['address']?.toString() ?? defaultAddress);
      _showPhone = map['showPhone'] != false;
      _phoneCtrl = TextEditingController(text: map['phone']?.toString() ?? defaultPhone);
      _showFiscalInfo = map['showFiscalInfo'] == true;
      _fiscalCtrl = TextEditingController(text: map['fiscalInfo']?.toString() ?? 'NIF: 0998123456789 | RC: 16/00-12345');
      _showCashierName = map['showCashierName'] != false;
      _cashierCtrl = TextEditingController(text: map['cashierName']?.toString() ?? 'الكاشير: سليم');
      _showSocialMedia = map['showSocialMedia'] == true;
      _socialCtrl = TextEditingController(text: map['socialMedia']?.toString() ?? 'FB / Insta: nayli.market');
      _showFooterNote = map['showFooterNote'] != false;
      _footerNoteCtrl = TextEditingController(text: map['footerNote']?.toString() ?? 'السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة');
      _showThankYou = map['showThankYou'] != false;
      _thankYouCtrl = TextEditingController(text: map['thankYou']?.toString() ?? '✨ شكراً لزيارتكم ونتشرف بخدمتكم دائماً ✨');
      _showBarcodeAtBottom = map['showBarcodeAtBottom'] != false;
      _separatorStyle = map['separatorStyle']?.toString() ?? 'dashed';
      _headerAlignment = map['headerAlignment']?.toString() ?? 'center';
      _paperSize = map['paperSize']?.toString() ?? box.get('printer_paper_size', defaultValue: '80mm') as String;
      _paperWidthMm = (map['paperWidthMm'] as num?)?.toDouble() ??
          (box.get('receipt_paper_width_mm') as num?)?.toDouble() ??
          (_paperSize == '58mm' ? 58.0 : 80.0);
      _receiptMarginMm = (map['marginMm'] as num?)?.toDouble() ??
          (box.get('receipt_margin_mm') as num?)?.toDouble() ??
          (_paperSize == '58mm' ? 4.0 : 6.0);
      _customExtraLines = (map['customExtraLines'] is Iterable)
          ? List<String>.from((map['customExtraLines'] as Iterable).map((e) => e.toString()))
          : [];

      // Load section order
      if (map['sectionOrder'] is Iterable) {
        _sectionOrder = List<String>.from(map['sectionOrder'] as Iterable);
      }
      for (final def in PrinterHelper.defaultReceiptSectionOrder) {
        if (!_sectionOrder.contains(def)) {
          _sectionOrder.add(def);
        }
      }

      // Load section alignments
      _sectionAlignments = Map<String, String>.from(PrinterHelper.defaultReceiptSectionAlignments);
      if (map['sectionAlignments'] is Map) {
        (map['sectionAlignments'] as Map).forEach((k, v) {
          if (v is String) _sectionAlignments[k.toString()] = v;
        });
      } else if (map['headerAlignment'] is String) {
        _sectionAlignments['header'] = map['headerAlignment'];
      }
    } else {
      _shopNameCtrl = TextEditingController(text: defaultShopName);
      _sloganCtrl = TextEditingController(text: 'مرحباً بكم في متجرنا');
      _addressCtrl = TextEditingController(text: defaultAddress);
      _phoneCtrl = TextEditingController(text: defaultPhone);
      _fiscalCtrl = TextEditingController(text: 'NIF: 0998123456789 | RC: 16/00-12345');
      _cashierCtrl = TextEditingController(text: 'الكاشير: سليم');
      _socialCtrl = TextEditingController(text: 'FB / Insta: nayli.market');
      _footerNoteCtrl = TextEditingController(text: 'السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة');
      _thankYouCtrl = TextEditingController(text: '✨ شكراً لزيارتكم ونتشرف بخدمتكم دائماً ✨');
      _paperSize = box.get('printer_paper_size', defaultValue: '80mm') as String;
      _paperWidthMm = (box.get('receipt_paper_width_mm') as num?)?.toDouble() ?? (_paperSize == '58mm' ? 58.0 : 80.0);
      _receiptMarginMm = (box.get('receipt_margin_mm') as num?)?.toDouble() ?? (_paperSize == '58mm' ? 4.0 : 6.0);
      _sectionOrder = List<String>.from(PrinterHelper.defaultReceiptSectionOrder);
      _sectionAlignments = Map<String, String>.from(PrinterHelper.defaultReceiptSectionAlignments);
    }

    _paperWidthCtrl = TextEditingController(text: _paperWidthMm.toStringAsFixed(0));
    _marginCtrl = TextEditingController(text: _receiptMarginMm.toStringAsFixed(1));

    void triggerUpdate() {
      if (mounted) {
        setState(() {
          _previewRevision++;
        });
      }
    }

    _shopNameCtrl.addListener(triggerUpdate);
    _sloganCtrl.addListener(triggerUpdate);
    _addressCtrl.addListener(triggerUpdate);
    _phoneCtrl.addListener(triggerUpdate);
    _fiscalCtrl.addListener(triggerUpdate);
    _cashierCtrl.addListener(triggerUpdate);
    _socialCtrl.addListener(triggerUpdate);
    _footerNoteCtrl.addListener(triggerUpdate);
    _thankYouCtrl.addListener(triggerUpdate);
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _sloganCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _fiscalCtrl.dispose();
    _cashierCtrl.dispose();
    _socialCtrl.dispose();
    _footerNoteCtrl.dispose();
    _thankYouCtrl.dispose();
    _paperWidthCtrl.dispose();
    _marginCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildCurrentTemplateMap() {
    return {
      'shopName': _shopNameCtrl.text.trim(),
      'showSlogan': _showSlogan,
      'slogan': _sloganCtrl.text.trim(),
      'showAddress': _showAddress,
      'address': _addressCtrl.text.trim(),
      'showPhone': _showPhone,
      'phone': _phoneCtrl.text.trim(),
      'showFiscalInfo': _showFiscalInfo,
      'fiscalInfo': _fiscalCtrl.text.trim(),
      'showCashierName': _showCashierName,
      'cashierName': _cashierCtrl.text.trim(),
      'showSocialMedia': _showSocialMedia,
      'socialMedia': _socialCtrl.text.trim(),
      'showFooterNote': _showFooterNote,
      'footerNote': _footerNoteCtrl.text.trim(),
      'showThankYou': _showThankYou,
      'thankYou': _thankYouCtrl.text.trim(),
      'showBarcodeAtBottom': _showBarcodeAtBottom,
      'separatorStyle': _separatorStyle,
      'headerAlignment': _sectionAlignments['header'] ?? _headerAlignment,
      'paperSize': _paperSize,
      'paperWidthMm': _paperWidthMm,
      'marginMm': _receiptMarginMm,
      'customExtraLines': _customExtraLines,
      'sectionOrder': _sectionOrder,
      'sectionAlignments': _sectionAlignments,
    };
  }

  bool _isSectionEnabled(String id) {
    switch (id) {
      case 'header':
      case 'invoice_info':
      case 'items':
      case 'totals':
      case 'credit_info':
        return true;
      case 'slogan':
        return _showSlogan;
      case 'address':
        return _showAddress;
      case 'phone':
        return _showPhone;
      case 'fiscal':
        return _showFiscalInfo;
      case 'social':
        return _showSocialMedia;
      case 'cashier':
        return _showCashierName;
      case 'footer':
        return _showFooterNote;
      case 'thank_you':
        return _showThankYou;
      case 'barcode':
        return _showBarcodeAtBottom;
      case 'extra_lines':
        return _customExtraLines.isNotEmpty;
      default:
        return true;
    }
  }

  void _toggleSectionEnabled(String id, bool val) {
    setState(() {
      _previewRevision++;
      switch (id) {
        case 'slogan':
          _showSlogan = val;
          break;
        case 'address':
          _showAddress = val;
          break;
        case 'phone':
          _showPhone = val;
          break;
        case 'fiscal':
          _showFiscalInfo = val;
          break;
        case 'social':
          _showSocialMedia = val;
          break;
        case 'cashier':
          _showCashierName = val;
          break;
        case 'footer':
          _showFooterNote = val;
          break;
        case 'thank_you':
          _showThankYou = val;
          break;
        case 'barcode':
          _showBarcodeAtBottom = val;
          break;
      }
    });
  }

  void _setSectionAlignment(String id, String align) {
    setState(() {
      _sectionAlignments[id] = align;
      if (id == 'header') _headerAlignment = align;
      _previewRevision++;
    });
  }

  void _moveSectionUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _sectionOrder.removeAt(index);
      _sectionOrder.insert(index - 1, item);
      _previewRevision++;
    });
    SoundService.playTabSwitch();
  }

  void _moveSectionDown(int index) {
    if (index >= _sectionOrder.length - 1) return;
    setState(() {
      final item = _sectionOrder.removeAt(index);
      _sectionOrder.insert(index + 1, item);
      _previewRevision++;
    });
    SoundService.playTabSwitch();
  }

  void _resetSectionOrder() {
    setState(() {
      _sectionOrder = List<String>.from(PrinterHelper.defaultReceiptSectionOrder);
      _sectionAlignments = Map<String, String>.from(PrinterHelper.defaultReceiptSectionAlignments);
      _headerAlignment = 'center';
      _previewRevision++;
    });
    SoundService.playTabSwitch();
    SnackbarHelper.showSuccess(context, 'تمت استعادة الترتيب والمحاذاة الافتراضية بنجاح!');
  }

  Future<void> _saveTemplate() async {
    final template = _buildCurrentTemplateMap();

    final box = HiveDatabase.settingsBox;
    await box.put('receipt_template', template);
    await box.put('printer_paper_size', _paperSize);
    await box.put('receipt_paper_width_mm', _paperWidthMm);
    await box.put('receipt_margin_mm', _receiptMarginMm);
    SoundService.playSaveSuccess();

    if (!mounted) return;
    SnackbarHelper.showSuccess(context, '✅ تم حفظ تصميم وتخصيص الوصل بنجاح!');
  }

  String _getSeparatorLine() {
    switch (_separatorStyle) {
      case 'stars':
        return '********************************';
      case 'double':
        return '================================';
      case 'dots':
        return '................................';
      case 'dashed':
      default:
        return '--------------------------------';
    }
  }

  void _addCustomLineDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('➕ إضافة سطر مخصص للوصل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'النص المخصص (مثال: توصيل مجاني للطلبات فوق 3000 دج)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                setState(() => _customExtraLines.add(text));
              }
              Navigator.pop(ctx);
            },
            child: Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printTestReceipt() async {
    final testItems = [
      {'name': 'حليب كانديا 1 لتر', 'qty': 2, 'price': 130.0, 'total': 260.0},
      {'name': 'زيت عافية 5 لتر', 'qty': 1, 'price': 650.0, 'total': 650.0},
      {'name': 'شوكولاطة ماكسون', 'qty': 3, 'price': 120.0, 'total': 360.0},
    ];

    if (Platform.isWindows) {
      if (PrinterHelper.defaultThermalPrinter.isEmpty) {
        final chosen = await PrinterSelectionDialog.show(context, targetRole: PrinterRole.thermalReceipt);
        if (chosen == null || !mounted) return;
        setState(() {});
      }

      final ok = await PrinterHelper.printReceiptWindows(
        shopName: _shopNameCtrl.text.trim(),
        address1: _showAddress ? _addressCtrl.text.trim() : null,
        address2: _showSlogan ? _sloganCtrl.text.trim() : null,
        phone: _showPhone ? _phoneCtrl.text.trim() : '',
        items: testItems,
        total: 1270.0,
        footer: _showFooterNote ? _footerNoteCtrl.text.trim() : '--- Nayli Kiosk ---',
        customerName: 'زبون تجريبي',
        paidAmount: 1500.0,
        invoiceId: 'FAC-0089',
      );
      if (mounted) {
        if (ok) {
          final printerName = PrinterHelper.defaultThermalPrinter.isNotEmpty ? ' (${PrinterHelper.defaultThermalPrinter})' : '';
          SnackbarHelper.showSuccess(context, '🖨️ تم إرسال الوصل التجريبي إلى طابعة$printerName بنجاح!');
        } else {
          SnackbarHelper.showWarning(context, 'يرجى تحديد طابعة الوصولات الحرارية من شاشة اختيار الطابعات.');
        }
      }
      return;
    }

    final printer = PrinterHelper();
    if (!printer.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final ok = await printer.connect(savedMac);
        if (!ok) {
          if (mounted) SnackbarHelper.showError(context, 'الطابعة غير متصلة! يرجى ربطها من الإعدادات.');
          return;
        }
      } else {
        if (mounted) SnackbarHelper.showError(context, 'يرجى ربط طابعة البلوتوث أولاً من الإعدادات.');
        return;
      }
    }

    await printer.printReceipt(
      shopName: _shopNameCtrl.text.trim(),
      address1: _showAddress ? _addressCtrl.text.trim() : '',
      address2: _showSlogan ? _sloganCtrl.text.trim() : '',
      phone: _showPhone ? _phoneCtrl.text.trim() : '',
      items: testItems,
      total: 1270.0,
      footer: _showFooterNote ? _footerNoteCtrl.text.trim() : '--- Nayli Kiosk ---',
      customerName: 'زبون تجريبي',
      paidAmount: 1500.0,
    );

    if (mounted) {
      SnackbarHelper.showSuccess(context, '🖨️ تم إرسال الوصل التجريبي إلى الطابعة!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final separator = _getSeparatorLine();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900 || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isDesktop ? 'تخصيص وتصميم الوصل الحراري 🧾' : 'تخصيص الوصل 🧾',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: !isDesktop,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: isDesktop
            ? [
                // Thermal printer selector button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal.shade800 : Colors.deepOrange,
                    side: BorderSide(
                      color: PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal.shade400 : Colors.deepOrange,
                      width: 1.2,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    Icons.print,
                    size: 16,
                    color: PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal : Colors.deepOrange,
                  ),
                  label: Text(
                    PrinterHelper.defaultThermalPrinter.isNotEmpty
                        ? 'طابعة الوصل: ${PrinterHelper.defaultThermalPrinter}'
                        : '⚠️ اختر طابعة الإيصالات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () async {
                    final chosen = await PrinterSelectionDialog.show(context, targetRole: PrinterRole.thermalReceipt);
                    if (chosen != null && mounted) {
                      setState(() {});
                    }
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.print_outlined, size: 18),
                  label: Text('طباعة تجريبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _printTestReceipt,
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.save_rounded, size: 18),
                  label: Text('حفظ التصميم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _saveTemplate,
                ),
                SizedBox(width: 14),
              ]
            : [
                IconButton(
                  tooltip: 'اختيار الطابعة',
                  icon: Icon(Icons.tune_rounded, color: Colors.teal),
                  onPressed: () async {
                    final chosen = await PrinterSelectionDialog.show(context, targetRole: PrinterRole.thermalReceipt);
                    if (chosen != null && mounted) setState(() {});
                  },
                ),
                IconButton(
                  tooltip: 'طباعة تجريبية',
                  icon: Icon(Icons.print_outlined, color: Colors.teal),
                  onPressed: _printTestReceipt,
                ),
                IconButton(
                  tooltip: 'حفظ التصميم',
                  icon: Icon(Icons.save_rounded, color: Color(0xFF4F46E5)),
                  onPressed: _saveTemplate,
                ),
                SizedBox(width: 4),
              ],
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Right Pane (Editor Controls, 60% Width)
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: _buildEditorControls(),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                // Left Pane (Sticky Ticket Preview, 40% Width)
                Container(
                  width: 420,
                  color: Color(0xFFF1F5F9),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'معاينة حية للوصل مقاس ${_paperWidthMm.toStringAsFixed(0)} مم',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildLivePdfPreview(),
                        SizedBox(height: 16),
                        Text(
                          'معاينة طبق الأصل لمحرك الطباعة الحراري مع كل تعديل',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      indicatorColor: AppTheme.primaryColor,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(icon: Icon(Icons.edit_note_rounded), text: 'تخصيص الخيارات'),
                        Tab(icon: Icon(Icons.receipt_long_rounded), text: 'معاينة الوصل 🧾'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: _buildEditorControls(),
                        ),
                        SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: _buildLivePdfPreview(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// TRUE WYSIWYG NATIVE PDF RECEIPT PREVIEW
  Widget _buildLivePdfPreview() {
    final testItems = [
      {'name': 'حليب كانديا 1 لتر', 'qty': 2, 'price': 130.0, 'total': 260.0},
      {'name': 'زيت عافية 5 لتر', 'qty': 1, 'price': 650.0, 'total': 650.0},
      {'name': 'شوكولاطة ماكسون', 'qty': 3, 'price': 120.0, 'total': 360.0},
    ];

    final double previewWidth = (_paperWidthMm * 4.2).clamp(260.0, 420.0);

    return Container(
      width: previewWidth,
      constraints: const BoxConstraints(maxHeight: 700),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: PdfPreview(
        key: ValueKey(_previewRevision),
        dpi: 250,
        build: (format) async => await PrinterHelper.generateReceiptPdfBytes(
          items: testItems,
          total: 1270.0,
          paidAmount: 1500.0,
          invoiceId: 'FAC-0089',
          customTemplate: _buildCurrentTemplateMap(),
        ),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        maxPageWidth: previewWidth,
        loadingWidget: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  Widget _buildAlignBtn(String sectionId, String align, IconData icon, String currentAlign) {
    final isSelected = currentAlign == align;
    return InkWell(
      onTap: () => _setSectionAlignment(sectionId, align),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
    );
  }

  /// FULL EDITOR CONTROLS
  Widget _buildEditorControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SECTION 0: RECEIPT PAPER SIZE & CUSTOM DIMENSIONS
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten_rounded, color: Colors.teal.shade700, size: 22),
                    SizedBox(width: 8),
                    Text('أبعاد ومقاس ورق الوصل 📏', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_paperWidthMm.toStringAsFixed(0)} مم (هامش ${_receiptMarginMm.toStringAsFixed(1)} مم)',
                        style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text('اختر نوع رول الطابعة الحرارية:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text('80 مم (قياسي - Standard)'),
                      selected: _paperSize == '80mm',
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _paperSize = '80mm';
                            _paperWidthMm = 80.0;
                            _receiptMarginMm = 6.0;
                            _paperWidthCtrl.text = '80';
                            _marginCtrl.text = '6.0';
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text('58 مم (مدمج - Compact)'),
                      selected: _paperSize == '58mm',
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _paperSize = '58mm';
                            _paperWidthMm = 58.0;
                            _receiptMarginMm = 4.0;
                            _paperWidthCtrl.text = '58';
                            _marginCtrl.text = '4.0';
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text('مخصص بأبعاد يدوية (Custom)'),
                      selected: _paperSize == 'custom',
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _paperSize = 'custom';
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_paperSize == 'custom' || (_paperSize != '80mm' && _paperSize != '58mm')) ...[
                  SizedBox(height: 14),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _paperWidthCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'عرض الورق (مم)',
                                  hintText: 'مثال: 76 أو 72 أو 80',
                                  prefixIcon: Icon(Icons.width_normal_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final p = double.tryParse(val);
                                  if (p != null && p >= 40 && p <= 120) {
                                    setState(() => _paperWidthMm = p);
                                  }
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _marginCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'الهامش الجانبي (مم)',
                                  hintText: 'مثال: 6.0 أو 4.0',
                                  prefixIcon: Icon(Icons.margin_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final p = double.tryParse(val);
                                  if (p != null && p >= 1.0 && p <= 20) {
                                    setState(() => _receiptMarginMm = p);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('مقاسات شائعة:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ...[58, 72, 76, 80, 82].map((w) {
                              final widthVal = w.toDouble();
                              final isCurrent = _paperWidthMm == widthVal;
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text('$w مم', style: TextStyle(fontSize: 10, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                                backgroundColor: isCurrent ? Colors.teal.withOpacity(0.2) : Colors.grey.shade100,
                                onPressed: () {
                                  setState(() {
                                    _paperWidthMm = widthVal;
                                    _receiptMarginMm = widthVal <= 60 ? 4.0 : 6.0;
                                    _paperWidthCtrl.text = widthVal.toStringAsFixed(0);
                                    _marginCtrl.text = _receiptMarginMm.toStringAsFixed(1);
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // SECTION 1: REORDERABLE SECTIONS & ALIGNMENTS
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_vert_circle_outlined, color: const Color(0xFF4F46E5), size: 24),
                        const SizedBox(width: 8),
                        const Text('1. ترتيب ومواقع ومحاذاة الأقسام 🔀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('الترتيب الافتراضي', style: TextStyle(fontSize: 12)),
                      onPressed: _resetSectionOrder,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'يمكنك تحريك أي قسم للأعلى أو للأسفل (⬆️ / ⬇️)، وتحديد محاذاة النص (يمين / وسط / يسار)، وإظهار أو إخفاء القسم:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                ..._sectionOrder.asMap().entries.map((entry) {
                  final index = entry.key;
                  final secId = entry.value;
                  final info = kReceiptSectionsInfo[secId] ?? _ReceiptSectionInfo(
                    id: secId,
                    title: secId,
                    icon: Icons.article_outlined,
                  );
                  final isEnabled = _isSectionEnabled(secId);
                  final currentAlign = _sectionAlignments[secId] ?? 'center';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEnabled ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEnabled ? Colors.grey.shade300 : Colors.grey.shade200,
                        width: 1,
                      ),
                      boxShadow: isEnabled
                          ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))]
                          : [],
                    ),
                    child: Row(
                      children: [
                        // Move Up / Down Buttons
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: index > 0 ? () => _moveSectionUp(index) : null,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: index > 0 ? AppTheme.primaryColor : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: index < _sectionOrder.length - 1 ? () => _moveSectionDown(index) : null,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: index < _sectionOrder.length - 1 ? AppTheme.primaryColor : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),

                        // Order Index Badge
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isEnabled ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Icon and Title
                        Icon(info.icon, size: 20, color: isEnabled ? Colors.grey.shade800 : Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            info.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isEnabled ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),

                        // Alignment Selector (if supported)
                        if (info.hasAlignment && isEnabled) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAlignBtn(secId, 'right', Icons.format_align_right_rounded, currentAlign),
                                _buildAlignBtn(secId, 'center', Icons.format_align_center_rounded, currentAlign),
                                _buildAlignBtn(secId, 'left', Icons.format_align_left_rounded, currentAlign),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Enable / Disable switch (if canDisable)
                        if (info.canDisable) ...[
                          Switch(
                            value: isEnabled,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) => _toggleSectionEnabled(secId, val),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 2: MANDATORY STORE BRANDING
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 22),
                    SizedBox(width: 8),
                    Text('2. هوية المتجر ورأس الوصل 🏪', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _shopNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المحل / المتجر (الظاهر في أعلى الوصل)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Text('محاذاة رأس الوصل:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    SizedBox(width: 14),
                    ChoiceChip(
                      label: Text('توسيط (وسط)'),
                      selected: _headerAlignment == 'center',
                      onSelected: (v) => setState(() => _headerAlignment = 'center'),
                    ),
                    SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('يمين'),
                      selected: _headerAlignment == 'right',
                      onSelected: (v) => setState(() => _headerAlignment = 'right'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // SECTION 2: OPTIONAL STORE CONTACTS & SLOGAN
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contact_phone_outlined, color: Colors.blue, size: 22),
                    SizedBox(width: 8),
                    Text('2. معلومات الاتصال والعناوين 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 14),

                _buildToggleableSection(
                  title: 'الشعار التسويقي (Slogan)',
                  isEnabled: _showSlogan,
                  controller: _sloganCtrl,
                  onToggle: (v) => setState(() => _showSlogan = v),
                  hint: 'مثال: جودة عالية وأسعار في متناول الجميع',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'عنوان المتجر',
                  isEnabled: _showAddress,
                  controller: _addressCtrl,
                  onToggle: (v) => setState(() => _showAddress = v),
                  hint: 'مثال: حي النور، شارع الاستقلال، الجزائر',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'رقم هاتف المتجر',
                  isEnabled: _showPhone,
                  controller: _phoneCtrl,
                  onToggle: (v) => setState(() => _showPhone = v),
                  hint: 'مثال: 0550 12 34 56',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'السجل التجاري والضرائب (NIF / RC)',
                  isEnabled: _showFiscalInfo,
                  controller: _fiscalCtrl,
                  onToggle: (v) => setState(() => _showFiscalInfo = v),
                  hint: 'مثال: RC: 16/00-123456 | NIF: 0998123456789',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'صفحات التواصل الاجتماعي',
                  isEnabled: _showSocialMedia,
                  controller: _socialCtrl,
                  onToggle: (v) => setState(() => _showSocialMedia = v),
                  hint: 'مثال: FB / Insta: nayli.market',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // SECTION 3: CASHIER & FOOTER
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text('3. بيانات الكاشير وأسفل الوصل ✍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 14),

                _buildToggleableSection(
                  title: 'اسم الكاشير أو المنفذ',
                  isEnabled: _showCashierName,
                  controller: _cashierCtrl,
                  onToggle: (v) => setState(() => _showCashierName = v),
                  hint: 'مثال: الكاشير: سليم أو صندوق رقم 1',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'ملاحظة أسفل الوصل (سياسة الاسترجاع)',
                  isEnabled: _showFooterNote,
                  controller: _footerNoteCtrl,
                  onToggle: (v) => setState(() => _showFooterNote = v),
                  hint: 'مثال: السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة مع إحضار الوصل',
                ),
                SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'عبارة الشكر والختام',
                  isEnabled: _showThankYou,
                  controller: _thankYouCtrl,
                  onToggle: (v) => setState(() => _showThankYou = v),
                  hint: 'مثال: ✨ شكراً لزيارتكم ونتشرف بخدمتكم دائماً ✨',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // SECTION 4: SEPARATORS & BARCODE
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.teal, size: 22),
                    SizedBox(width: 8),
                    Text('4. الخطوط الفاصلة والباركود 🎛️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 14),

                Text('شكل الخط الفاصل بين الأقسام:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('شرطات (---)'),
                      selected: _separatorStyle == 'dashed',
                      onSelected: (v) => setState(() => _separatorStyle = 'dashed'),
                    ),
                    ChoiceChip(
                      label: Text('نجوم (***)'),
                      selected: _separatorStyle == 'stars',
                      onSelected: (v) => setState(() => _separatorStyle = 'stars'),
                    ),
                    ChoiceChip(
                      label: Text('مزدوج (===)'),
                      selected: _separatorStyle == 'double',
                      onSelected: (v) => setState(() => _separatorStyle = 'double'),
                    ),
                    ChoiceChip(
                      label: Text('نقط (...)'),
                      selected: _separatorStyle == 'dots',
                      onSelected: (v) => setState(() => _separatorStyle = 'dots'),
                    ),
                  ],
                ),
                Divider(height: 24),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('إظهار باركود / QR Code أسفل الوصل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('رمز استجابة سريعة للتحقق من صحة الفاتورة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _showBarcodeAtBottom,
                  onChanged: (v) => setState(() => _showBarcodeAtBottom = v),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // SECTION 5: CUSTOM EXTRA LINES
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '5. أسطر حرة مخصصة إضافية (${_customExtraLines.length}) ➕',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.add, size: 18),
                      label: Text('إضافة سطر حر', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _addCustomLineDialog,
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'أضف أي نصوص إعلانية خاصة كأوقات العمل، عروض نهاية الأسبوع، أو التوصيل:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (_customExtraLines.isNotEmpty) ...[
                  SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _customExtraLines.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(_customExtraLines[i], style: TextStyle(fontSize: 13))),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              tooltip: 'حذف',
                              onPressed: () => setState(() => _customExtraLines.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 24),

        // Bottom Save Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: Icon(Icons.save_rounded, size: 20),
          label: Text('حفظ تصميم وتخصيص الوصل 💾', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _saveTemplate,
        ),
        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildToggleableSection({
    required String title,
    required bool isEnabled,
    required TextEditingController controller,
    required ValueChanged<bool> onToggle,
    required String hint,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEnabled ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isEnabled ? Colors.black87 : Colors.grey)),
              Switch(
                value: isEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: onToggle,
              ),
            ],
          ),
          if (isEnabled) ...[
            SizedBox(height: 6),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

