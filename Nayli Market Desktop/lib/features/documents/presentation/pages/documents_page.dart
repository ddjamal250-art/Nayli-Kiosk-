import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../data/document_pdf_generator.dart';
import '../data/document_service.dart';
import '../domain/entities/commercial_document.dart';
import 'create_edit_document_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<CommercialDocument> _allDocuments = [];
  bool _isLoading = true;
  String _selectedFilter = 'الكل';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await DocumentService.getAllDocuments();
    if (mounted) {
      setState(() {
        _allDocuments = docs;
        _isLoading = false;
      });
    }
  }

  List<CommercialDocument> get _filteredDocuments {
    return _allDocuments.where((doc) {
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          doc.reference.toLowerCase().contains(query) ||
          doc.clientName.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'Devis' && doc.type == DocumentType.devis) return true;
      if (_selectedFilter == 'BC' && doc.type == DocumentType.bonDeCommande) return true;
      if (_selectedFilter == 'BL' && doc.type == DocumentType.bonDeLivraison) return true;
      if (_selectedFilter == 'Factures' && doc.type == DocumentType.facture) return true;
      if (_selectedFilter == 'Brouillons' && (doc.isDraft || doc.status == 'brouillon')) return true;
      if (_selectedFilter == 'Achat' && doc.type == DocumentType.bonAchat) return true;
      return false;
    }).toList();
  }

  void _showConversionDialog(CommercialDocument doc) {
    SoundService.playTabSwitch();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.transform_rounded, color: Colors.teal, size: 28),
            const SizedBox(width: 8),
            Text('تحويل المستند: ${doc.reference}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر نوع المستند المستهدف للتحويل إليه:'),
            const SizedBox(height: 12),
            if (doc.type == DocumentType.devis) ...[
              _buildConvertTile(ctx, doc, DocumentType.bonDeCommande, 'تحويل إلى وصل طلبية (Bon de Commande)'),
              _buildConvertTile(ctx, doc, DocumentType.bonDeLivraison, 'تحويل إلى وصل تسليم (Bon de Livraison)'),
              _buildConvertTile(ctx, doc, DocumentType.facture, 'تحويل إلى فاتورة رسمية (Facture)'),
            ] else if (doc.type == DocumentType.bonDeCommande) ...[
              _buildConvertTile(ctx, doc, DocumentType.bonDeLivraison, 'تحويل إلى وصل تسليم (Bon de Livraison)'),
              _buildConvertTile(ctx, doc, DocumentType.facture, 'تحويل إلى فاتورة رسمية (Facture)'),
            ] else if (doc.type == DocumentType.bonDeLivraison) ...[
              _buildConvertTile(ctx, doc, DocumentType.facture, 'تحويل إلى فاتورة رسمية (Facture)'),
            ] else ...[
              _buildConvertTile(ctx, doc, DocumentType.bonDeLivraison, 'استخراج وصل تسليم مكرر'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  Widget _buildConvertTile(BuildContext ctx, CommercialDocument doc, DocumentType targetType, String label) {
    return ListTile(
      leading: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.teal),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      onTap: () async {
        Navigator.pop(ctx);
        final converted = await DocumentService.convertDocument(sourceDoc: doc, targetType: targetType);
        await _loadDocuments();
        SoundService.playSaveSuccess();
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'تم إنشاء ${targetType.titleAr} برقم ${converted.reference} بنجاح!');
        }
      },
    );
  }

  void _confirmDelete(CommercialDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستند'),
        content: Text('هل أنت متأكد من حذف ${doc.type.titleAr} رقم ${doc.reference} نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DocumentService.deleteDocument(doc.id);
              await _loadDocuments();
              SoundService.playDeleteSound();
              if (mounted) {
                SnackbarHelper.showSuccess(context, 'تم حذف المستند بنجاح');
              }
            },
            child: const Text('نعم، حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devisCount = _allDocuments.where((d) => d.type == DocumentType.devis).length;
    final bcCount = _allDocuments.where((d) => d.type == DocumentType.bonDeCommande).length;
    final blCount = _allDocuments.where((d) => d.type == DocumentType.bonDeLivraison).length;
    final facCount = _allDocuments.where((d) => d.type == DocumentType.facture).length;
    final draftCount = _allDocuments.where((d) => d.isDraft || d.status == 'brouillon').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text('الوثائق التجارية والفواتير (Devis, BC, BL, Factures)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 16)),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('إنشاء مستند جديد (+)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEditDocumentPage()),
              );
              if (result == true) {
                _loadDocuments();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Statistics Row (Dolisoft Inspired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildStatBadge('إجمالي الوثائق', _allDocuments.length.toString(), Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatBadge('Devis (عروض أسعار)', devisCount.toString(), Colors.indigo),
                      const SizedBox(width: 12),
                      _buildStatBadge('BC (طلبيات)', bcCount.toString(), Colors.orange),
                      const SizedBox(width: 12),
                      _buildStatBadge('BL (تسليم)', blCount.toString(), Colors.teal),
                      const SizedBox(width: 12),
                      _buildStatBadge('Factures (فواتير)', facCount.toString(), Colors.green),
                      const SizedBox(width: 12),
                      _buildStatBadge('Brouillons (مسودات)', draftCount.toString(), Colors.grey),
                    ],
                  ),
                ),

                // Filter & Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    children: [
                      // Filter Chips
                      Wrap(
                        spacing: 8,
                        children: ['الكل', 'Devis', 'BC', 'BL', 'Factures', 'Brouillons', 'Achat'].map((tab) {
                          final isSelected = _selectedFilter == tab;
                          return ChoiceChip(
                            label: Text(tab),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              setState(() => _selectedFilter = tab);
                              SoundService.playTabSwitch();
                            },
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      // Search box
                      SizedBox(
                        width: 320,
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث برقم الوثيقة أو اسم العميل...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // Document List
                Expanded(
                  child: _filteredDocuments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('لا توجد وثائق مسجلة مطابقة للبحث',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDocuments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = _filteredDocuments[index];
                            return _buildDocumentCard(doc);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatBadge(String title, String val, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(fontSize: 18, color: color.shade900, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(CommercialDocument doc) {
    Color typeColor = Colors.teal;
    if (doc.type == DocumentType.devis) typeColor = Colors.indigo;
    if (doc.type == DocumentType.bonDeCommande) typeColor = Colors.orange;
    if (doc.type == DocumentType.bonDeLivraison) typeColor = Colors.teal;
    if (doc.type == DocumentType.facture) typeColor = Colors.green;
    if (doc.type == DocumentType.bonAchat) typeColor = Colors.purple;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: typeColor),
              ),
              child: Column(
                children: [
                  Text(doc.type.code, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: typeColor)),
                  Text(doc.type.titleAr.split(' ').first, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Reference & Client
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(doc.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: doc.isDraft ? Colors.grey.shade200 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.isDraft ? 'مسودة (Brouillon)' : 'مؤكد (Validé)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: doc.isDraft ? Colors.grey.shade700 : Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('العميل: ${doc.clientName} ${doc.clientPhone != null ? "• ${doc.clientPhone}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(doc.createdAt)} • المواد: ${doc.items.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            // Total Amount
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('المبلغ الإجمالي TTC', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('${doc.totalTtc.toStringAsFixed(2)} د.ج',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.teal)),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Actions Buttons
            Row(
              children: [
                IconButton(
                  tooltip: 'طباعة ومعاينة PDF (A4)',
                  icon: const Icon(Icons.print_rounded, color: Colors.teal),
                  onPressed: () => DocumentPdfGenerator.printDocument(doc),
                ),
                if (doc.clientPhone != null && doc.clientPhone!.isNotEmpty)
                  IconButton(
                    tooltip: 'إرسال عبر واتساب (WhatsApp)',
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                    onPressed: () => DocumentPdfGenerator.sendViaWhatsApp(doc: doc, phoneNumber: doc.clientPhone!),
                  ),
                IconButton(
                  tooltip: 'تحويل المستند (Convertir)',
                  icon: const Icon(Icons.transform_rounded, color: Colors.indigo),
                  onPressed: () => _showConversionDialog(doc),
                ),
                IconButton(
                  tooltip: 'حذف المستند',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
