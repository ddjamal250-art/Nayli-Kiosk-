import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';

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
      _customExtraLines = (map['customExtraLines'] is Iterable)
          ? List<String>.from((map['customExtraLines'] as Iterable).map((e) => e.toString()))
          : [];
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
    final testItems = [
      {'name': 'حليب كانديا 1 لتر', 'qty': 2, 'price': 130.0, 'total': 260.0},
      {'name': 'زيت عافية 5 لتر', 'qty': 1, 'price': 650.0, 'total': 650.0},
      {'name': 'شوكولاطة ماكسون', 'qty': 3, 'price': 120.0, 'total': 360.0},
    ];

    if (Platform.isWindows) {
      final ok = await PrinterHelper.printReceiptWindows(
        shopName: _shopNameCtrl.text.trim(),
        address1: _showAddress ? _addressCtrl.text.trim() : null,
        address2: _showSlogan ? _sloganCtrl.text.trim() : null,
        phone: _showPhone ? _phoneCtrl.text.trim() : null,
        items: testItems,
        total: 1270.0,
        footer: _showFooterNote ? _footerNoteCtrl.text.trim() : '--- NAYLI MARKET ---',
        customerName: 'زبون تجريبي',
        paidAmount: 1500.0,
      );
      if (mounted) {
        if (ok) {
          SnackbarHelper.showSuccess(context, '🖨️ تم إرسال الوصل التجريبي إلى طابعة Windows بنجاح!');
        } else {
          SnackbarHelper.showWarning(context, 'يرجى تحديد طابعة الويندوز الافتراضية من شاشة إعدادات الطابعات.');
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
      footer: _showFooterNote ? _footerNoteCtrl.text.trim() : '--- NAYLI MARKET ---',
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('تخصيص وتصميم الوصل الحراري 🧾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: !isDesktop,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('طباعة تجريبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _printTestReceipt,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('حفظ التصميم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _saveTemplate,
          ),
          const SizedBox(width: 14),
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
                    padding: const EdgeInsets.all(24),
                    child: _buildEditorControls(),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                // Left Pane (Sticky Ticket Preview, 40% Width)
                Container(
                  width: 420,
                  color: const Color(0xFFF1F5F9),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'معاينة حية للوصل مقاس 80mm',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReceiptPreview(separator),
                        const SizedBox(height: 16),
                        Text(
                          'تتحدث المعاينة مباشرة مع كل حرف تدخله في لوحة التخصيص',
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
                    child: const TabBar(
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
                          padding: const EdgeInsets.all(16),
                          child: _buildEditorControls(),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _buildReceiptPreview(separator),
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

  /// REALISTIC THERMAL RECEIPT TICKET PREVIEW
  Widget _buildReceiptPreview(String separator) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'monospace'),
          ),

          // Optional Slogan
          if (_showSlogan && _sloganCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _sloganCtrl.text,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'monospace', color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],

          // Optional Address & Phone
          if (_showAddress && _addressCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('📍 ${_addressCtrl.text}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showPhone && _phoneCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('📞 ${_phoneCtrl.text}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showFiscalInfo && _fiscalCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_fiscalCtrl.text, style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showSocialMedia && _socialCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('📱 ${_socialCtrl.text}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],

          const SizedBox(height: 8),
          Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          const SizedBox(height: 6),

          // Mandatory Invoice Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وصل رقم: #FAC-0089', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
            ],
          ),
          if (_showCashierName && _cashierCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_cashierCtrl.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.brown)),
            ),
          ],

          const SizedBox(height: 6),
          Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          const SizedBox(height: 6),

          // Mandatory Items Table
          const Row(
            children: [
              Expanded(flex: 5, child: Text('السلعة', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('السعر', textAlign: TextAlign.end, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),

          // Sample items preview
          _buildItemRow('حليب كانديا 1L', '2', '260.00'),
          _buildItemRow('زيت عافية 5L', '1', '650.00'),
          _buildItemRow('شوكولاطة ماكسون', '3', '360.00'),

          const SizedBox(height: 6),
          Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          const SizedBox(height: 6),

          // Total & Payment info
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموع الإجمالي (Total):', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
              Text('1,270.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ المدفوع (Espèce):', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
              Text('1,500.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ المتبقي (Rendu):', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
              Text('230.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
            ],
          ),

          const SizedBox(height: 6),
          Text(separator, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          const SizedBox(height: 6),

          // Custom Extra Lines in receipt
          if (_customExtraLines.isNotEmpty) ...[
            for (var line in _customExtraLines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(line, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
          ],

          // Optional Footer Note & Thank You
          if (_showFooterNote && _footerNoteCtrl.text.isNotEmpty) ...[
            Text(_footerNoteCtrl.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87)),
            const SizedBox(height: 4),
          ],
          if (_showThankYou && _thankYouCtrl.text.isNotEmpty) ...[
            Text(_thankYouCtrl.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
          ],

          if (_showBarcodeAtBottom) ...[
            const SizedBox(height: 6),
            const Center(child: Icon(Icons.qr_code_2, size: 40, color: Colors.black87)),
            const SizedBox(height: 2),
            const Center(
              child: Text(
                '* FAC-0089 *',
                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, String qty, String total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5))),
          Expanded(flex: 2, child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5))),
          Expanded(flex: 3, child: Text('$total دج', textAlign: TextAlign.end, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  /// FULL EDITOR CONTROLS
  Widget _buildEditorControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SECTION 1: MANDATORY STORE BRANDING
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 22),
                    SizedBox(width: 8),
                    Text('1. هوية المتجر ورأس الوصل 🏪', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _shopNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المحل / المتجر (الظاهر في أعلى الوصل)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('محاذاة رأس الوصل:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 14),
                    ChoiceChip(
                      label: const Text('توسيط (وسط)'),
                      selected: _headerAlignment == 'center',
                      onSelected: (v) => setState(() => _headerAlignment = 'center'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('يمين'),
                      selected: _headerAlignment == 'right',
                      onSelected: (v) => setState(() => _headerAlignment = 'right'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 2: OPTIONAL STORE CONTACTS & SLOGAN
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.contact_phone_outlined, color: Colors.blue, size: 22),
                    SizedBox(width: 8),
                    Text('2. معلومات الاتصال والعناوين 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 14),

                _buildToggleableSection(
                  title: 'الشعار التسويقي (Slogan)',
                  isEnabled: _showSlogan,
                  controller: _sloganCtrl,
                  onToggle: (v) => setState(() => _showSlogan = v),
                  hint: 'مثال: جودة عالية وأسعار في متناول الجميع',
                ),
                const SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'عنوان المتجر',
                  isEnabled: _showAddress,
                  controller: _addressCtrl,
                  onToggle: (v) => setState(() => _showAddress = v),
                  hint: 'مثال: حي النور، شارع الاستقلال، الجزائر',
                ),
                const SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'رقم هاتف المتجر',
                  isEnabled: _showPhone,
                  controller: _phoneCtrl,
                  onToggle: (v) => setState(() => _showPhone = v),
                  hint: 'مثال: 0550 12 34 56',
                ),
                const SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'السجل التجاري والضرائب (NIF / RC)',
                  isEnabled: _showFiscalInfo,
                  controller: _fiscalCtrl,
                  onToggle: (v) => setState(() => _showFiscalInfo = v),
                  hint: 'مثال: RC: 16/00-123456 | NIF: 0998123456789',
                ),
                const SizedBox(height: 10),

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
        const SizedBox(height: 16),

        // SECTION 3: CASHIER & FOOTER
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notes_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text('3. بيانات الكاشير وأسفل الوصل ✍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 14),

                _buildToggleableSection(
                  title: 'اسم الكاشير أو المنفذ',
                  isEnabled: _showCashierName,
                  controller: _cashierCtrl,
                  onToggle: (v) => setState(() => _showCashierName = v),
                  hint: 'مثال: الكاشير: سليم أو صندوق رقم 1',
                ),
                const SizedBox(height: 10),

                _buildToggleableSection(
                  title: 'ملاحظة أسفل الوصل (سياسة الاسترجاع)',
                  isEnabled: _showFooterNote,
                  controller: _footerNoteCtrl,
                  onToggle: (v) => setState(() => _showFooterNote = v),
                  hint: 'مثال: السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة مع إحضار الوصل',
                ),
                const SizedBox(height: 10),

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
        const SizedBox(height: 16),

        // SECTION 4: SEPARATORS & BARCODE
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.teal, size: 22),
                    SizedBox(width: 8),
                    Text('4. الخطوط الفاصلة والباركود 🎛️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('شكل الخط الفاصل بين الأقسام:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('شرطات (---)'),
                      selected: _separatorStyle == 'dashed',
                      onSelected: (v) => setState(() => _separatorStyle = 'dashed'),
                    ),
                    ChoiceChip(
                      label: const Text('نجوم (***)'),
                      selected: _separatorStyle == 'stars',
                      onSelected: (v) => setState(() => _separatorStyle = 'stars'),
                    ),
                    ChoiceChip(
                      label: const Text('مزدوج (===)'),
                      selected: _separatorStyle == 'double',
                      onSelected: (v) => setState(() => _separatorStyle = 'double'),
                    ),
                    ChoiceChip(
                      label: const Text('نقط (...)'),
                      selected: _separatorStyle == 'dots',
                      onSelected: (v) => setState(() => _separatorStyle = 'dots'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إظهار باركود / QR Code أسفل الوصل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('رمز استجابة سريعة للتحقق من صحة الفاتورة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _showBarcodeAtBottom,
                  onChanged: (v) => setState(() => _showBarcodeAtBottom = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 5: CUSTOM EXTRA LINES
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
                    Text(
                      '5. أسطر حرة مخصصة إضافية (${_customExtraLines.length}) ➕',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة سطر حر', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _addCustomLineDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'أضف أي نصوص إعلانية خاصة كأوقات العمل، عروض نهاية الأسبوع، أو التوصيل:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (_customExtraLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _customExtraLines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(_customExtraLines[i], style: const TextStyle(fontSize: 13))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
        const SizedBox(height: 24),

        // Bottom Save Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: const Icon(Icons.save_rounded, size: 20),
          label: const Text('حفظ تصميم وتخصيص الوصل 💾', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _saveTemplate,
        ),
        const SizedBox(height: 30),
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
      padding: const EdgeInsets.all(12),
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
