import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';

class ReceiptCustomizerPage extends StatefulWidget {
  const ReceiptCustomizerPage({super.key});

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

  List<String> _customExtraLines = [];

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
      _shopNameCtrl = TextEditingController(text: map['shopName'] ?? defaultShopName);
      _showSlogan = map['showSlogan'] ?? true;
      _sloganCtrl = TextEditingController(text: map['slogan'] ?? 'مرحباً بكم في متجرنا');
      _showAddress = map['showAddress'] ?? true;
      _addressCtrl = TextEditingController(text: map['address'] ?? defaultAddress);
      _showPhone = map['showPhone'] ?? true;
      _phoneCtrl = TextEditingController(text: map['phone'] ?? defaultPhone);
      _showFiscalInfo = map['showFiscalInfo'] ?? false;
      _fiscalCtrl = TextEditingController(text: map['fiscalInfo'] ?? 'NIF: 0998123456789 | RC: 16/00-12345');
      _showCashierName = map['showCashierName'] ?? true;
      _cashierCtrl = TextEditingController(text: map['cashierName'] ?? 'الكاشير: سليم');
      _showSocialMedia = map['showSocialMedia'] ?? false;
      _socialCtrl = TextEditingController(text: map['socialMedia'] ?? 'FB / Insta: nayli.market');
      _showFooterNote = map['showFooterNote'] ?? true;
      _footerNoteCtrl = TextEditingController(text: map['footerNote'] ?? 'السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة');
      _showThankYou = map['showThankYou'] ?? true;
      _thankYouCtrl = TextEditingController(text: map['thankYou'] ?? '✨ شكراً لزيارتكم ونتشرف بخدمتكم دائماً ✨');
      _showBarcodeAtBottom = map['showBarcodeAtBottom'] ?? true;
      _separatorStyle = map['separatorStyle'] ?? 'dashed';
      _headerAlignment = map['headerAlignment'] ?? 'center';
      _customExtraLines = List<String>.from(map['customExtraLines'] ?? []);
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
    }

    _shopNameCtrl.addListener(() => setState(() {}));
    _sloganCtrl.addListener(() => setState(() {}));
    _addressCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() => setState(() {}));
    _fiscalCtrl.addListener(() => setState(() {}));
    _cashierCtrl.addListener(() => setState(() {}));
    _socialCtrl.addListener(() => setState(() {}));
    _footerNoteCtrl.addListener(() => setState(() {}));
    _thankYouCtrl.addListener(() => setState(() {}));
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
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    final template = {
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
      'headerAlignment': _headerAlignment,
      'customExtraLines': _customExtraLines,
    };

    await HiveDatabase.settingsBox.put('receipt_template', template);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم حفظ تصميم وتخصيص الوصل بنجاح!'),
        backgroundColor: Colors.green,
        duration: Duration(milliseconds: 1500),
      ),
    );
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
        title: const Text('➕ إضافة سطر مخصص للوصل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'النص المخصص (مثال: توصيل مجاني للطلبات فوق 3000 دج)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                setState(() => _customExtraLines.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printTestReceipt() async {
    final printer = PrinterHelper();
    if (!printer.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final ok = await printer.connect(savedMac);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الطابعة غير متصلة! يرجى ربطها من الإعدادات.'), backgroundColor: Colors.red),
          );
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى ربط طابعة البلوتوث أولاً من الإعدادات.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final testItems = [
      {'name': 'حليب كوندي 1 لتر', 'qty': 2, 'price': 130.0, 'total': 260.0},
      {'name': 'زيت عافية 5 لتر', 'qty': 1, 'price': 650.0, 'total': 650.0},
      {'name': 'شوكولاطة ماكسون', 'qty': 3, 'price': 120.0, 'total': 360.0},
    ];

    await printer.printReceipt(
      shopName: _shopNameCtrl.text.trim(),
      address1: _showAddress ? _addressCtrl.text.trim() : '',
      address2: _showSlogan ? _sloganCtrl.text.trim() : '',
      phone: _showPhone ? _phoneCtrl.text.trim() : '',
      items: testItems,
      total: 1270.0,
      footer: _showFooterNote ? _footerNoteCtrl.text.trim() : '--- NAYLI MARKET ---',
      customerName: 'زبون تجريبي',
      paidAmount: 1500.0,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🖨️ تم إرسال الوصل التجريبي إلى الطابعة!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final separator = _getSeparatorLine();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص وتصميم الوصل 🧾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppTheme.primaryColor),
            tooltip: 'طباعة وصل تجريبي',
            onPressed: _printTestReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.green),
            tooltip: 'حفظ التصميم',
            onPressed: _saveTemplate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LIVE TICKET PREVIEW CARD
            const Text('معاينة حية للوصل الحراري (Live Preview) 🖨️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: _headerAlignment == 'center'
                    ? CrossAxisAlignment.center
                    : (_headerAlignment == 'left' ? CrossAxisAlignment.start : CrossAxisAlignment.end),
                children: [
                  // Mandatory Header: Shop Name
                  Text(
                    _shopNameCtrl.text.isEmpty ? 'اسم المحل' : _shopNameCtrl.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'monospace'),
                  ),

                  // Optional Slogan
                  if (_showSlogan && _sloganCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_sloganCtrl.text, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'monospace')),
                  ],

                  // Optional Address & Phone
                  if (_showAddress && _addressCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📍 ${_addressCtrl.text}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                  if (_showPhone && _phoneCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📞 ${_phoneCtrl.text}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                  if (_showFiscalInfo && _fiscalCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_fiscalCtrl.text, style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
                  ],
                  if (_showSocialMedia && _socialCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📱 ${_socialCtrl.text}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontFamily: 'monospace')),
                  ],

                  const SizedBox(height: 6),
                  Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
                  const SizedBox(height: 4),

                  // Mandatory Invoice Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('وصل رقم: #FAC-0089', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                    ],
                  ),
                  if (_showCashierName && _cashierCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(_cashierCtrl.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.brown)),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
                  const SizedBox(height: 4),

                  // Mandatory Items Table
                  const Row(
                    children: [
                      Expanded(flex: 4, child: Text('السلعة', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('السعر', textAlign: TextAlign.left, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Expanded(flex: 4, child: Text('حليب كوندي 1 لتر', style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                      Expanded(flex: 1, child: Text('2', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                      Expanded(flex: 2, child: Text('260 دج', textAlign: TextAlign.left, style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                    ],
                  ),
                  const Row(
                    children: [
                      Expanded(flex: 4, child: Text('زيت عافية 5 لتر', style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                      Expanded(flex: 1, child: Text('1', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                      Expanded(flex: 2, child: Text('650 دج', textAlign: TextAlign.left, style: TextStyle(fontFamily: 'monospace', fontSize: 11))),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
                  const SizedBox(height: 4),

                  // Mandatory Total & Payment
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المجموع الإجمالي:', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('910.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المستلم نقداً:', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                      Text('1000.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    ],
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الباقي المرجع:', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.green)),
                      Text('90.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  // Custom Extra Lines
                  if (_customExtraLines.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final line in _customExtraLines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.indigo)),
                      ),
                  ],

                  // Optional Footer Note & Thank you
                  if (_showFooterNote && _footerNoteCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
                    const SizedBox(height: 2),
                    Text(_footerNoteCtrl.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black87)),
                  ],
                  if (_showThankYou && _thankYouCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_thankYouCtrl.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
                  ],

                  if (_showBarcodeAtBottom) ...[
                    const SizedBox(height: 6),
                    const Icon(Icons.qr_code_2, size: 36, color: Colors.black87),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 1: MANDATORY IMMUTABLE FIELDS (لا تحذف - قابلة للتعديل والتنسيق فقط)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 8),
                      Text('البيانات الأساسية الإلزامية (تعديل فقط 🔒)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _shopNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المحل / المتجر (يظهر في رأس الوصل)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('توسيط الرأس:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('وسط', style: TextStyle(fontSize: 11)),
                        selected: _headerAlignment == 'center',
                        onSelected: (v) => setState(() => _headerAlignment = 'center'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('يمين', style: TextStyle(fontSize: 11)),
                        selected: _headerAlignment == 'right',
                        onSelected: (v) => setState(() => _headerAlignment = 'right'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 2: OPTIONAL CUSTOMIZABLE FIELDS (إضافة، تعديل، أو حذف/إخفاء)
            const Text('عناصر إضافية قابلة للإضافة والتعديل والحذف ⚙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'عبارة ترحيبية / شعار المحل',
              isEnabled: _showSlogan,
              controller: _sloganCtrl,
              onToggle: (v) => setState(() => _showSlogan = v),
              hint: 'مثال: جودة مضمونة وأسعار لا تقبل المنافسة',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'عنوان المحل والموقع',
              isEnabled: _showAddress,
              controller: _addressCtrl,
              onToggle: (v) => setState(() => _showAddress = v),
              hint: 'مثال: حي 500 مسكن بجانب مسجد الفرقان',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'رقم الهاتف للتواصل أو الطلبيات',
              isEnabled: _showPhone,
              controller: _phoneCtrl,
              onToggle: (v) => setState(() => _showPhone = v),
              hint: '0550 XX XX XX / 0660 XX XX XX',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'المعرف الجبائي والسجل التجاري (NIF / RC)',
              isEnabled: _showFiscalInfo,
              controller: _fiscalCtrl,
              onToggle: (v) => setState(() => _showFiscalInfo = v),
              hint: 'NIF: 0998... | RC: 16/...',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'اسم الكاشير / البائع',
              isEnabled: _showCashierName,
              controller: _cashierCtrl,
              onToggle: (v) => setState(() => _showCashierName = v),
              hint: 'الكاشير: اسم البائع',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'حسابات التواصل الاجتماعي (فيسبوك / انستغرام)',
              isEnabled: _showSocialMedia,
              controller: _socialCtrl,
              onToggle: (v) => setState(() => _showSocialMedia = v),
              hint: 'صفحتنا: @ShopNameDz',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'شروط وملاحظة الفاتورة السفلية',
              isEnabled: _showFooterNote,
              controller: _footerNoteCtrl,
              onToggle: (v) => setState(() => _showFooterNote = v),
              hint: 'السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة مع ضرورة إحضار الوصل',
            ),
            const SizedBox(height: 10),

            _buildToggleableSection(
              title: 'عبارة الشكر الختامية',
              isEnabled: _showThankYou,
              controller: _thankYouCtrl,
              onToggle: (v) => setState(() => _showThankYou = v),
              hint: 'شكراً لزيارتكم ونتشرف بخدمتكم دائماً',
            ),
            const SizedBox(height: 14),

            // Style & Extras
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('خيارات شكل وتصميم الخطوط الفاصلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('خط متقطع (---)', style: TextStyle(fontSize: 11)),
                        selected: _separatorStyle == 'dashed',
                        onSelected: (v) => setState(() => _separatorStyle = 'dashed'),
                      ),
                      ChoiceChip(
                        label: const Text('نجوم (***)', style: TextStyle(fontSize: 11)),
                        selected: _separatorStyle == 'stars',
                        onSelected: (v) => setState(() => _separatorStyle = 'stars'),
                      ),
                      ChoiceChip(
                        label: const Text('مزدوج (===)', style: TextStyle(fontSize: 11)),
                        selected: _separatorStyle == 'double',
                        onSelected: (v) => setState(() => _separatorStyle = 'double'),
                      ),
                      ChoiceChip(
                        label: const Text('نقاط (...)', style: TextStyle(fontSize: 11)),
                        selected: _separatorStyle == 'dots',
                        onSelected: (v) => setState(() => _separatorStyle = 'dots'),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إظهار باركود / QR Code أسفل الوصل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    value: _showBarcodeAtBottom,
                    onChanged: (v) => setState(() => _showBarcodeAtBottom = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Custom Extra Lines Builder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('أسطر حرة مخصصة إضافية (${_customExtraLines.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة سطر حر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _addCustomLineDialog,
                ),
              ],
            ),
            if (_customExtraLines.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customExtraLines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(_customExtraLines[i], style: const TextStyle(fontSize: 12))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _customExtraLines.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // Save Template Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('حفظ تصميم وتخصيص الوصل 💾', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: _saveTemplate,
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[100],
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
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
