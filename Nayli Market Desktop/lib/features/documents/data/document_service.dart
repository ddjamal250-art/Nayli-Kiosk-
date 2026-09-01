import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'commercial_document.dart';

class DocumentService {
  static const String boxName = 'commercial_documents_box';
  static Box? _box;

  static Future<Box> get box async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(boxName);
    return _box!;
  }

  /// Generate next sequential reference code, e.g. FAC-2026-0001
  static Future<String> generateNextReference(DocumentType type) async {
    final b = await box;
    final year = DateTime.now().year;
    final prefix = '${type.code}-$year';
    
    int maxNumber = 0;
    for (var key in b.keys) {
      final docMap = b.get(key);
      if (docMap is Map) {
        final ref = docMap['reference']?.toString() ?? '';
        if (ref.startsWith(prefix)) {
          final parts = ref.split('-');
          if (parts.length >= 3) {
            final numPart = int.tryParse(parts[2]) ?? 0;
            if (numPart > maxNumber) maxNumber = numPart;
          }
        }
      }
    }
    final nextNum = (maxNumber + 1).toString().padLeft(4, '0');
    return '$prefix-$nextNum';
  }

  /// Get all documents
  static Future<List<CommercialDocument>> getAllDocuments() async {
    final b = await box;
    final list = <CommercialDocument>[];
    for (var key in b.keys) {
      final docMap = b.get(key);
      if (docMap is Map) {
        try {
          list.add(CommercialDocument.fromMap(docMap));
        } catch (e) {
          debugPrint('Error parsing document $key: $e');
        }
      }
    }
    // Sort descending by creation date
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Save or update document
  static Future<void> saveDocument(CommercialDocument doc) async {
    final b = await box;
    await b.put(doc.id, doc.toMap());
  }

  /// Delete document
  static Future<void> deleteDocument(String id) async {
    final b = await box;
    await b.delete(id);
  }

  /// Convert document from one type to another (e.g. Devis -> Bon de Commande -> BL -> Facture)
  static Future<CommercialDocument> convertDocument({
    required CommercialDocument sourceDoc,
    required DocumentType targetType,
  }) async {
    final newRef = await generateNextReference(targetType);
    final newId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    
    final convertedDoc = CommercialDocument(
      id: newId,
      reference: newRef,
      type: targetType,
      createdAt: DateTime.now(),
      dueDate: sourceDoc.dueDate,
      status: 'valide',
      isDraft: false,
      clientName: sourceDoc.clientName,
      clientPhone: sourceDoc.clientPhone,
      clientAddress: sourceDoc.clientAddress,
      clientRc: sourceDoc.clientRc,
      clientNif: sourceDoc.clientNif,
      clientNis: sourceDoc.clientNis,
      clientAi: sourceDoc.clientAi,
      items: List.from(sourceDoc.items),
      timbreFiscal: sourceDoc.timbreFiscal,
      notes: 'تم التحويل من ${sourceDoc.type.titleAr} رقم ${sourceDoc.reference}',
      paymentMethod: sourceDoc.paymentMethod,
      isPaid: false,
    );

    await saveDocument(convertedDoc);
    return convertedDoc;
  }
}
