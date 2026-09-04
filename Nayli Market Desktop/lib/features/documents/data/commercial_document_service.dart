import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/hive_database.dart';
import '../domain/entities/commercial_document.dart';

class CommercialDocumentService {
  static const String _boxName = 'commercial_documents_box';

  static Box get _box => Hive.box(_boxName);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  /// Get all documents with optional filters
  static List<CommercialDocument> getDocuments({
    CommercialDocType? type,
    bool isArchived = false,
    String searchQuery = '',
  }) {
    if (!Hive.isBoxOpen(_boxName)) return [];

    final rawList = _box.values.whereType<Map>().map((m) => CommercialDocument.fromMap(m)).toList();

    return rawList.where((doc) {
      if (doc.isArchived != isArchived) return false;
      if (type != null && doc.type != type) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchNum = doc.documentNumber.toLowerCase().contains(q);
        final matchEntity = doc.entityName.toLowerCase().contains(q);
        final matchPhone = doc.entityPhone.contains(q);
        if (!matchNum && !matchEntity && !matchPhone) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Generate next formatted sequential document number (e.g. FAC-2026-0001)
  static String generateNextDocNumber(CommercialDocType type) {
    final prefix = type.name.toUpperCase();
    final year = DateTime.now().year;
    final allDocs = getDocuments(type: type, isArchived: false) + getDocuments(type: type, isArchived: true);
    final count = allDocs.length + 1;
    final paddedCount = count.toString().padLeft(4, '0');
    return '$prefix-$year-$paddedCount';
  }

  /// Save or Update Document
  static Future<void> saveDocument(CommercialDocument document) async {
    await _box.put(document.id, document.toMap());
    
    // Auto-sync to desktop if mobile paired
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      final ip = HiveDatabase.settingsBox.get('sync_server_ip', defaultValue: '') as String;
      final port = HiveDatabase.settingsBox.get('sync_server_port', defaultValue: 8080);
      if (ip.isNotEmpty) {
        try {
          final urlStr = ip.contains(':') ? 'http://$ip/api/documents' : 'http://$ip:$port/api/documents';
          final url = Uri.parse(urlStr);
          await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(document.toMap()),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
    }
  }

  /// Delete Document
  static Future<void> deleteDocument(String id) async {
    await _box.delete(id);
  }

  /// Archive Document
  static Future<void> archiveDocument(String id) async {
    final raw = _box.get(id);
    if (raw is Map) {
      final doc = CommercialDocument.fromMap(raw);
      final updated = doc.copyWith(isArchived: true);
      await _box.put(id, updated.toMap());
    }
  }

  /// Unarchive Document
  static Future<void> unarchiveDocument(String id) async {
    final raw = _box.get(id);
    if (raw is Map) {
      final doc = CommercialDocument.fromMap(raw);
      final updated = doc.copyWith(isArchived: false);
      await _box.put(id, updated.toMap());
    }
  }

  /// 1-Click Document Conversion Engine (Devis ➔ Commande ➔ BL ➔ Facture)
  static Future<CommercialDocument> convertDocument({
    required CommercialDocument sourceDoc,
    required CommercialDocType targetType,
  }) async {
    final newDocNumber = generateNextDocNumber(targetType);
    final newId = const Uuid().v4();

    final convertedDoc = sourceDoc.copyWith(
      id: newId,
      documentNumber: newDocNumber,
      type: targetType,
      date: DateTime.now(),
      status: targetType == CommercialDocType.facture ? CommercialDocStatus.valide : CommercialDocStatus.enAttente,
      convertedFromId: sourceDoc.id,
      isArchived: false,
    );

    // Save new converted document
    await saveDocument(convertedDoc);

    // Mark original document with convertedToId
    final updatedOriginal = sourceDoc.copyWith(convertedToId: newId);
    await saveDocument(updatedOriginal);

    return convertedDoc;
  }

  /// Get Detailed Account Statement (Situation Client / Fournisseur)
  static Map<String, dynamic> getEntityStatement(String entityName) {
    if (entityName.trim().isEmpty) {
      return {'totalInvoiced': 0.0, 'totalPaid': 0.0, 'currentBalance': 0.0, 'history': []};
    }

    final allDocs = (_box.values.whereType<Map>().map((m) => CommercialDocument.fromMap(m)).toList())
        .where((d) => d.entityName.trim().toLowerCase() == entityName.trim().toLowerCase())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = 0.0;
    final List<Map<String, dynamic>> statementLines = [];

    for (final doc in allDocs) {
      if (doc.type == CommercialDocType.facture || doc.type == CommercialDocType.bl) {
        runningBalance += doc.netTotal;
        runningBalance -= doc.amountPaid;
        statementLines.add({
          'date': DateFormat('yyyy-MM-dd').format(doc.date),
          'type': doc.typeLabelAr,
          'number': doc.documentNumber,
          'debit': doc.netTotal,
          'credit': doc.amountPaid,
          'balance': runningBalance,
        });
      } else if (doc.type == CommercialDocType.versement) {
        runningBalance -= doc.amountPaid;
        statementLines.add({
          'date': DateFormat('yyyy-MM-dd').format(doc.date),
          'type': 'وصل تسديد دفعة',
          'number': doc.documentNumber,
          'debit': 0.0,
          'credit': doc.amountPaid,
          'balance': runningBalance,
        });
      }
    }

    return {
      'entityName': entityName,
      'currentBalance': runningBalance,
      'statementLines': statementLines,
    };
  }
}

