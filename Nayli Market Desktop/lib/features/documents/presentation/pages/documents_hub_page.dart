import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/commercial_pdf_generator.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../data/commercial_document_service.dart';
import '../../domain/entities/commercial_document.dart';
import '../widgets/document_editor_dialog.dart';
import '../widgets/receipt_ocr_scanner_dialog.dart';
import 'package:uuid/uuid.dart';

class DocumentsHubPage extends StatefulWidget {
  const DocumentsHubPage({super.key});

  @override
  State<DocumentsHubPage> createState() => _DocumentsHubPageState();
}

class _DocumentsHubPageState extends State<DocumentsHubPage> with SingleTickerProviderStateMixin {
  CommercialDocType? _selectedTypeFilter;
  bool _isArchivedView = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<CommercialDocument> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadDocuments() {
    setState(() {
      _documents = CommercialDocumentService.getDocuments(
        type: _selectedTypeFilter,
        isArchived: _isArchivedView,
        searchQuery: _searchQuery,
      );
    });
  }

  void _openEditor({CommercialDocument? doc, CommercialDocType? defaultType}) async {
    final result = await DocumentEditorDialog.show(
      context,
      initialDocument: doc,
      defaultType: defaultType ?? _selectedTypeFilter,
    );
    if (result == true) {
      _loadDocuments();
      if (mounted) {
        SnackbarHelper.showSuccess(context, '✅ تم حفظ وتحديث الوثيقة بنجاح!');
      }
    }
  }

  void _scanPaperReceipt() async {
    final result = await ReceiptOcrScannerDialog.show(context);
    if (result != null && result.items.isNotEmpty) {
      final docType = _selectedTypeFilter ?? CommercialDocType.facture;
      final newDoc = CommercialDocument(
        id: const Uuid().v4(),
        documentNumber: CommercialDocumentService.generateNextDocNumber(docType),
        type: docType,
        status: CommercialDocStatus.valide,
        date: result.date ?? DateTime.now(),
        entityName: result.entityName.isNotEmpty ? result.entityName : 'زبون عابر',
        items: result.items,
        amountPaid: 0.0,
      );
      _openEditor(doc: newDoc);
    }
  }

  void _convertDocument(CommercialDocument doc, CommercialDocType targetType) async {
    final converted = await CommercialDocumentService.convertDocument(
      sourceDoc: doc,
      targetType: targetType,
    );
    SoundService.playCheckoutSuccess();
    _loadDocuments();
    if (mounted) {
      context.showAppSnackBar('🎉 تم تحويل الوثيقة بنجاح إلى ${converted.typeLabelAr} (رقم: ${converted.documentNumber})');
    }
  }

  void _archiveOrUnarchive(CommercialDocument doc) async {
    if (doc.isArchived) {
      await CommercialDocumentService.unarchiveDocument(doc.id);
      SnackbarHelper.showSuccess(context, 'تم استرجاع الوثيقة من الأرشيف');
    } else {
      await CommercialDocumentService.archiveDocument(doc.id);
      SnackbarHelper.showSuccess(context, 'تم نقل الوثيقة إلى الأرشيف 📦');
    }
    SoundService.playTabSwitch();
    _loadDocuments();
  }

  void _deleteDocument(CommercialDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('تأكيد حذف الوثيقة'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الوثيقة رقم "${doc.documentNumber}" نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CommercialDocumentService.deleteDocument(doc.id);
      SoundService.playDeleteSound();
      _loadDocuments();
    }
  }

  void _showPosTicketsArchiveModal(BuildContext context) {
    SoundService.playTabSwitch();
    final rawInvoices = HiveDatabase.invoicesBox.values.whereType<Map>().toList().reversed.toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 8),
                Text('أرشيف وصولات الكاشير السريعة (${rawInvoices.length}) 🧾',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 480,
              child: rawInvoices.isEmpty
                  ? const Center(
                      child: Text('لا توجد وصولات مسجلة بعد في النظام',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    )
                  : ListView.separated(
                      itemCount: rawInvoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final inv = rawInvoices[idx];
                        final timeStr = inv['timestamp']?.toString() ?? '';
                        final dt = DateTime.tryParse(timeStr) ?? DateTime.now();
                        final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
                        final customer = inv['customerName']?.toString() ?? 'زبون عابر';
                        final method = inv['paymentMethod']?.toString() ?? (inv['isCredit'] == true ? 'Crédit' : 'Espèces');
                        final items = List<Map<String, dynamic>>.from(inv['items'] ?? []);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            child: const Icon(Icons.receipt_rounded, color: Colors.indigo),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('وصل #${inv['id'] ?? (idx + 1)} • $customer',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${total.toStringAsFixed(2)} DA',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.teal, fontSize: 14)),
                            ],
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy/MM/dd HH:mm').format(dt)}  |  طريقة الدفع: $method  |  عدد السلع: ${items.length}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                            label: const Text('طباعة نسخة (Duplicata)',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final shopName = HiveDatabase.settingsBox.get('shop_name', defaultValue: 'Nayli Market');
                              final shopPhone = HiveDatabase.settingsBox.get('shop_phone', defaultValue: '');
                              final printed = await PrinterHelper.printReceiptWindows(
                                shopName: '$shopName (DUPLICATA)',
                                phone: shopPhone,
                                items: items,
                                total: total,
                                customerName: customer,
                                isCredit: inv['isCredit'] == true,
                                paidAmount: (inv['paidAmount'] as num?)?.toDouble() ?? 0.0,
                              );
                              if (printed) {
                                SoundService.playCheckoutSuccess();
                                if (context.mounted) {
                                  SnackbarHelper.showSuccess(context, '✅ تم إرسال النسخة المطابقة إلى طابعة الويندوز');
                                }
                              } else {
                                if (context.mounted) {
                                  SnackbarHelper.showWarning(context, '⚠️ تعذر إرسال أمر الطباعة، تأكد من اتصال الطابعة');
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final dateFormat = DateFormat('yyyy/MM/dd');

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded, color: Colors.indigo, size: 22),
            const SizedBox(width: 6),
            Text(
              isWide ? 'مركز الوثائق والفواتير التجارية الشامل 📑' : 'الوثائق والفواتير 📑',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Toggle Archive View
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: _isArchivedView ? Colors.deepOrange : Colors.grey.shade700,
            ),
            icon: Icon(_isArchivedView ? Icons.inventory_2 : Icons.archive_outlined, size: 18),
            label: Text(
              _isArchivedView ? (isWide ? 'العودة للوثائق النشطة' : 'النشطة') : (isWide ? 'الأرشيف 📦' : 'الأرشيف'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () {
              setState(() {
                _isArchivedView = !_isArchivedView;
                _loadDocuments();
              });
              SoundService.playTabSwitch();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Top Filter Ribbon
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                // Search Bar & Action Buttons (Responsive)
                if (isWide)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'بحث برقم الوثيقة، اسم الزبون، أو رقم الهاتف...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _loadDocuments();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                              _loadDocuments();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'مسح وصل ورقي (OCR) 📸',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _scanPaperReceipt,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'وصولات الكاشير (Duplicata) 🧾',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _showPosTicketsArchiveModal(context),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
                        label: const Text(
                          'إنشاء وثيقة جديدة ➕',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _openEditor(),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'بحث برقم الوثيقة، اسم الزبون...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _loadDocuments();
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                            _loadDocuments();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_circle, color: Colors.white, size: 16),
                              label: const Text(
                                'إنشاء وثيقة ➕',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _openEditor(),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 16),
                              label: const Text(
                                'مسح وصل (OCR) 📸',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: _scanPaperReceipt,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade800,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                              label: const Text(
                                'وصولات الكاشير 🧾',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _showPosTicketsArchiveModal(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 10),

                // Document Types Horizontal Scroll Ribbon
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل (Tous)', null),
                      _buildFilterChip('Devis (عروض أسعار)', CommercialDocType.devis),
                      _buildFilterChip('Commandes (طلبيات)', CommercialDocType.commande),
                      _buildFilterChip('Bons de Livraison (BL)', CommercialDocType.bl),
                      _buildFilterChip('Factures (فواتير)', CommercialDocType.facture),
                      _buildFilterChip('Versements (قبض ودفع)', CommercialDocType.versement),
                      _buildFilterChip('Bons d\'Achat (شراء)', CommercialDocType.achat),
                      _buildFilterChip('Bons de Route (شحن)', CommercialDocType.bonDeRoute),
                      _buildFilterChip('Bons de Retour (إرجاع للمورد) 🔄', CommercialDocType.retourFournisseur),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Document List
          Expanded(
            child: _documents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isArchivedView ? Icons.inventory_2_outlined : Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isArchivedView ? 'لا توجد وثائق مؤرشفة' : 'لا توجد وثائق تجارية بعد في هذا القسم',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'اضغط على زر "إنشاء وثيقة جديدة" للبدء فوراً',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _documents.length,
                    itemBuilder: (ctx, idx) {
                      final doc = _documents[idx];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Info Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getDocTypeColor(doc.type).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getDocTypeColor(doc.type)),
                                        ),
                                        child: Text(
                                          doc.typeLabelAr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getDocTypeColor(doc.type),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        doc.documentNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dateFormat.format(doc.date),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Entity & Financials Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.entityName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (doc.entityPhone.isNotEmpty)
                                        Text(
                                          doc.entityPhone,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${doc.netTotal.toStringAsFixed(2)} DA',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                                      ),
                                      if (doc.remainingBalance > 0)
                                        Text(
                                          'الباقي: ${doc.remainingBalance.toStringAsFixed(2)} DA',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.red),
                                        )
                                      else
                                        const Text(
                                          'خالص بالكامل ✅',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                                        ),
                                    ],
                                  ),
                                ],
                              ),

                              const Divider(height: 18),

                              // Actions Row
                              Row(
                                children: [
                                  // Print PDF Button
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.print, size: 16, color: Colors.indigo),
                                    label: const Text('طباعة PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => CommercialPdfGenerator.printDocument(doc),
                                  ),
                                  const SizedBox(width: 6),

                                  // Desktop 1-Click Save
                                  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
                                    IconButton.filledTonal(
                                      tooltip: 'حفظ على سطح المكتب فوراً',
                                      icon: const Icon(Icons.desktop_windows_rounded, size: 16, color: Colors.indigo),
                                      onPressed: () async {
                                        final p = await CommercialPdfGenerator.exportToDesktop(doc);
                                        SoundService.playSaveSuccess();
                                        if (context.mounted) context.showAppSnackBar('🖥️ تم حفظ الوثيقة على سطح المكتب!\n$p');
                                      },
                                    ),
                                  ],

                                  // Share WhatsApp Button
                                  IconButton.filledTonal(
                                    tooltip: 'مشاركة PDF عبر WhatsApp',
                                    icon: const Icon(Icons.share, size: 16, color: Colors.green),
                                    onPressed: () => CommercialPdfGenerator.sharePdf(doc),
                                  ),

                                  const Spacer(),

                                  // 1-Click Conversion Menu
                                  if (doc.type == CommercialDocType.devis) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.sync_alt, size: 14, color: Colors.white),
                                      label: const Text('تحويل إلى BL ⚡', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _convertDocument(doc, CommercialDocType.bl),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else if (doc.type == CommercialDocType.bl) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.receipt, size: 14, color: Colors.white),
                                      label: const Text('تحويل لفاتورة ⚡', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _convertDocument(doc, CommercialDocType.facture),
                                    ),
                                    const SizedBox(width: 6),
                                  ],

                                  // Edit Button
                                  IconButton(
                                    tooltip: 'تعديل',
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                    onPressed: () => _openEditor(doc: doc),
                                  ),

                                  // Archive Toggle Button
                                  IconButton(
                                    tooltip: doc.isArchived ? 'استرجاع من الأرشيف' : 'أرشفة الوثيقة',
                                    icon: Icon(doc.isArchived ? Icons.unarchive : Icons.archive_outlined, size: 18, color: Colors.orange),
                                    onPressed: () => _archiveOrUnarchive(doc),
                                  ),

                                  // Delete Button
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deleteDocument(doc),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CommercialDocType? type) {
    final isSelected = _selectedTypeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.indigo.shade100,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.indigo.shade900 : Colors.black87,
        ),
        onSelected: (_) {
          setState(() {
            _selectedTypeFilter = type;
            _loadDocuments();
          });
          SoundService.playTabSwitch();
        },
      ),
    );
  }

  Color _getDocTypeColor(CommercialDocType type) {
    switch (type) {
      case CommercialDocType.devis:
        return Colors.orange;
      case CommercialDocType.commande:
        return Colors.blue;
      case CommercialDocType.bl:
        return Colors.teal;
      case CommercialDocType.facture:
        return Colors.indigo;
      case CommercialDocType.versement:
        return Colors.green;
      case CommercialDocType.achat:
        return Colors.purple;
      case CommercialDocType.bonDeRoute:
        return Colors.deepOrange;
      case CommercialDocType.retourFournisseur:
        return Colors.red.shade700;
    }
  }
}

