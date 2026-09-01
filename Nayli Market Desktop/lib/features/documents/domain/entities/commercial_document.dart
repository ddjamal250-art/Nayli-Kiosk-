import 'package:uuid/uuid.dart';

enum CommercialDocType {
  devis, // عرض سعر Devis / Proforma
  commande, // طلبية زبون Bon de Commande
  bl, // وصل تسليم Bon de Livraison
  facture, // فاتورة رسمية Facture de Vente
  versement, // وصل دفع وقبض Bon de Versement
  achat, // وصل شراء من مورد Bon d'Achat
  bonDeRoute, // وصل شحن وطريق Bon de Route
}

enum CommercialDocStatus {
  enAttente, // قيد الانتظار / مسودة
  valide, // مؤكد ومقبول
  paye, // مدفوع كلياً
  partiel, // مدفوع جزئياً
  annule, // ملغى
  livre, // تم التسليم
}

class CommercialDocItem {
  final String id;
  final String productId;
  final String designation;
  final String barcode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
  final double tvaPercent;

  CommercialDocItem({
    required this.id,
    required this.productId,
    required this.designation,
    this.barcode = '',
    required this.quantity,
    this.unit = 'حبة',
    required this.unitPrice,
    this.discount = 0.0,
    this.tvaPercent = 0.0,
  });

  double get totalHT => (quantity * unitPrice) - discount;
  double get totalTVA => totalHT * (tvaPercent / 100.0);
  double get totalTTC => totalHT + totalTVA;

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'designation': designation,
        'barcode': barcode,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discount': discount,
        'tvaPercent': tvaPercent,
      };

  factory CommercialDocItem.fromMap(Map<dynamic, dynamic> map) => CommercialDocItem(
        id: map['id']?.toString() ?? const Uuid().v4(),
        productId: map['productId']?.toString() ?? '',
        designation: map['designation']?.toString() ?? '',
        barcode: map['barcode']?.toString() ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: map['unit']?.toString() ?? 'حبة',
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        tvaPercent: (map['tvaPercent'] as num?)?.toDouble() ?? 0.0,
      );
}

class CommercialDocument {
  final String id;
  final String documentNumber; // رقم الوثيقة: مثلا FAC-2026-0042 أو BL-0012
  final CommercialDocType type;
  final CommercialDocStatus status;
  final DateTime date;
  final DateTime? dueDate; // تاريخ الاستحقاق

  // Customer / Supplier Info
  final String entityId;
  final String entityName;
  final String entityPhone;
  final String entityAddress;
  final String entityRc;
  final String entityNif;
  final String entityNis;
  final String entityArt;

  // Items
  final List<CommercialDocItem> items;

  // Financials
  final double globalDiscount;
  final double amountPaid; // المبلغ المدفوع حالياً
  final double previousBalance; // الرصيد القديم للزبون
  final String paymentMethod; // كاش، TPE، صك، تحويل
  final String? notes;

  // Archiving & Conversion flags
  final bool isArchived;
  final String? convertedFromId; // تم التحويل من وثيقة أخرى
  final String? convertedToId; // تم تحويلها إلى وثيقة تالية

  CommercialDocument({
    required this.id,
    required this.documentNumber,
    required this.type,
    required this.status,
    required this.date,
    this.dueDate,
    this.entityId = '',
    required this.entityName,
    this.entityPhone = '',
    this.entityAddress = '',
    this.entityRc = '',
    this.entityNif = '',
    this.entityNis = '',
    this.entityArt = '',
    required this.items,
    this.globalDiscount = 0.0,
    this.amountPaid = 0.0,
    this.previousBalance = 0.0,
    this.paymentMethod = 'كاش',
    this.notes,
    this.isArchived = false,
    this.convertedFromId,
    this.convertedToId,
  });

  double get subtotalHT => items.fold(0.0, (sum, item) => sum + item.totalHT);
  double get totalTVA => items.fold(0.0, (sum, item) => sum + item.totalTVA);
  double get netTotal => (subtotalHT - globalDiscount) + totalTVA;
  double get totalWithPreviousBalance => netTotal + previousBalance;
  double get remainingBalance => totalWithPreviousBalance - amountPaid;

  String get typeLabelAr {
    switch (type) {
      case CommercialDocType.devis:
        return 'عرض سعر (Devis)';
      case CommercialDocType.commande:
        return 'طلبية زبون (Commande)';
      case CommercialDocType.bl:
        return 'وصل تسليم (BL)';
      case CommercialDocType.facture:
        return 'فاتورة بيع (Facture)';
      case CommercialDocType.versement:
        return 'وصل دفع وقبض (Versement)';
      case CommercialDocType.achat:
        return 'وصل شراء مورد (Bon d\'Achat)';
      case CommercialDocType.bonDeRoute:
        return 'وصل الشحن والتوزيع (Bon de Route)';
    }
  }

  String get typeCodePrefix {
    switch (type) {
      case CommercialDocType.devis:
        return 'DEV';
      case CommercialDocType.commande:
        return 'CMD';
      case CommercialDocType.bl:
        return 'BL';
      case CommercialDocType.facture:
        return 'FAC';
      case CommercialDocType.versement:
        return 'REC';
      case CommercialDocType.achat:
        return 'ACH';
      case CommercialDocType.bonDeRoute:
        return 'ROU';
    }
  }

  String get statusLabelAr {
    switch (status) {
      case CommercialDocStatus.enAttente:
        return 'قيد الانتظار ⏳';
      case CommercialDocStatus.valide:
        return 'مؤكد ومقبول ✅';
      case CommercialDocStatus.paye:
        return 'خالص بالكامل 🟢';
      case CommercialDocStatus.partiel:
        return 'مدفوع جزئياً 🟡';
      case CommercialDocStatus.annule:
        return 'ملغى ❌';
      case CommercialDocStatus.livre:
        return 'تم التسليم 🚚';
    }
  }

  CommercialDocument copyWith({
    String? id,
    String? documentNumber,
    CommercialDocType? type,
    CommercialDocStatus? status,
    DateTime? date,
    DateTime? dueDate,
    String? entityId,
    String? entityName,
    String? entityPhone,
    String? entityAddress,
    String? entityRc,
    String? entityNif,
    String? entityNis,
    String? entityArt,
    List<CommercialDocItem>? items,
    double? globalDiscount,
    double? amountPaid,
    double? previousBalance,
    String? paymentMethod,
    String? notes,
    bool? isArchived,
    String? convertedFromId,
    String? convertedToId,
  }) {
    return CommercialDocument(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      entityPhone: entityPhone ?? this.entityPhone,
      entityAddress: entityAddress ?? this.entityAddress,
      entityRc: entityRc ?? this.entityRc,
      entityNif: entityNif ?? this.entityNif,
      entityNis: entityNis ?? this.entityNis,
      entityArt: entityArt ?? this.entityArt,
      items: items ?? this.items,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      amountPaid: amountPaid ?? this.amountPaid,
      previousBalance: previousBalance ?? this.previousBalance,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      convertedFromId: convertedFromId ?? this.convertedFromId,
      convertedToId: convertedToId ?? this.convertedToId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'documentNumber': documentNumber,
        'type': type.name,
        'status': status.name,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'entityId': entityId,
        'entityName': entityName,
        'entityPhone': entityPhone,
        'entityAddress': entityAddress,
        'entityRc': entityRc,
        'entityNif': entityNif,
        'entityNis': entityNis,
        'entityArt': entityArt,
        'items': items.map((e) => e.toMap()).toList(),
        'globalDiscount': globalDiscount,
        'amountPaid': amountPaid,
        'previousBalance': previousBalance,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'isArchived': isArchived,
        'convertedFromId': convertedFromId,
        'convertedToId': convertedToId,
      };

  factory CommercialDocument.fromMap(Map<dynamic, dynamic> map) => CommercialDocument(
        id: map['id']?.toString() ?? const Uuid().v4(),
        documentNumber: map['documentNumber']?.toString() ?? '',
        type: CommercialDocType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => CommercialDocType.facture,
        ),
        status: CommercialDocStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => CommercialDocStatus.valide,
        ),
        date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
        dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'].toString()) : null,
        entityId: map['entityId']?.toString() ?? '',
        entityName: map['entityName']?.toString() ?? 'زبون عابر',
        entityPhone: map['entityPhone']?.toString() ?? '',
        entityAddress: map['entityAddress']?.toString() ?? '',
        entityRc: map['entityRc']?.toString() ?? '',
        entityNif: map['entityNif']?.toString() ?? '',
        entityNis: map['entityNis']?.toString() ?? '',
        entityArt: map['entityArt']?.toString() ?? '',
        items: (map['items'] as List<dynamic>?)
                ?.map((itemMap) => CommercialDocItem.fromMap(itemMap as Map<dynamic, dynamic>))
                .toList() ??
            [],
        globalDiscount: (map['globalDiscount'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
        previousBalance: (map['previousBalance'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: map['paymentMethod']?.toString() ?? 'كاش',
        notes: map['notes']?.toString(),
        isArchived: map['isArchived'] == true,
        convertedFromId: map['convertedFromId']?.toString(),
        convertedToId: map['convertedToId']?.toString(),
      );
}

