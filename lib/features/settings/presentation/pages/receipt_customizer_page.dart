import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../billing/presentation/widgets/printer_selection_dialog.dart';

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
                                'معاينة حية للوصل مقاس 80mm',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildReceiptPreview(separator),
                        SizedBox(height: 16),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 18,
            offset: Offset(0, 8),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'monospace'),
          ),

          // Optional Slogan
          if (_showSlogan && _sloganCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Text(
              _sloganCtrl.text,
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'monospace', color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],

          // Optional Address & Phone
          if (_showAddress && _addressCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Text('📍 ${_addressCtrl.text}', style: TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showPhone && _phoneCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Text('📞 ${_phoneCtrl.text}', style: TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showFiscalInfo && _fiscalCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Text(_fiscalCtrl.text, style: TextStyle(fontSize: 9.5, color: Colors.grey, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],
          if (_showSocialMedia && _socialCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Text('📱 ${_socialCtrl.text}', style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontFamily: 'monospace'), textAlign: TextAlign.center),
          ],

          SizedBox(height: 8),
          Text(separator, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          SizedBox(height: 6),

          // Mandatory Invoice Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('وصل رقم: #FAC-0089', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
            ],
          ),
          if (_showCashierName && _cashierCtrl.text.isNotEmpty) ...[
            SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_cashierCtrl.text, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.brown)),
            ),
          ],

          SizedBox(height: 6),
          Text(separator, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          SizedBox(height: 6),

          // Mandatory Items Table
          Row(
            children: [
              Expanded(flex: 5, child: Text('السلعة', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('السعر', textAlign: TextAlign.end, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
          SizedBox(height: 4),

          // Sample items preview
          _buildItemRow('حليب كانديا 1L', '2', '260.00'),
          _buildItemRow('زيت عافية 5L', '1', '650.00'),
          _buildItemRow('شوكولاطة ماكسون', '3', '360.00'),

          SizedBox(height: 6),
          Text(separator, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          SizedBox(height: 6),

          // Total & Payment info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموع الإجمالي (Total):', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
              Text('1,270.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ المدفوع (Espèce):', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
              Text('1,500.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ المتبقي (Rendu):', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
              Text('230.00 دج', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
            ],
          ),

          SizedBox(height: 6),
          Text(separator, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey), maxLines: 1),
          SizedBox(height: 6),

          // Custom Extra Lines in receipt
          if (_customExtraLines.isNotEmpty) ...[
            for (var line in _customExtraLines)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(line, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            SizedBox(height: 4),
          ],

          // Optional Footer Note & Thank You
          if (_showFooterNote && _footerNoteCtrl.text.isNotEmpty) ...[
            Text(_footerNoteCtrl.text, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87)),
            SizedBox(height: 4),
          ],
          if (_showThankYou && _thankYouCtrl.text.isNotEmpty) ...[
            Text(_thankYouCtrl.text, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
          ],

          if (_showBarcodeAtBottom) ...[
            SizedBox(height: 6),
            Center(child: Icon(Icons.qr_code_2, size: 40, color: Colors.black87)),
            SizedBox(height: 2),
            Center(
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
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(name, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5))),
          Expanded(flex: 2, child: Text(qty, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5))),
          Expanded(flex: 3, child: Text('$total دج', textAlign: TextAlign.end, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.bold))),
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
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 22),
                    SizedBox(width: 8),
                    Text('1. هوية المتجر ورأس الوصل 🏪', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

