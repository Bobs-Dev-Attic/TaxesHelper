import 'package:cloud_firestore/cloud_firestore.dart';

import 'tax_category.dart';

/// A single recorded money movement: income, an expense or a deduction.
class TaxTransaction {
  final String? id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String description;
  final String payee;
  final int taxYear;
  final DateTime? createdAt;

  /// Firebase Storage object path of the attached receipt, if any.
  final String? receiptPath;

  /// Download URL for the attached receipt, if any.
  final String? receiptUrl;

  const TaxTransaction({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.description,
    required this.payee,
    required this.taxYear,
    this.createdAt,
    this.receiptPath,
    this.receiptUrl,
  });

  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  TaxCategory get category =>
      TaxCategories.byId(categoryId) ?? TaxCategories.unknown;

  TaxFormSection get section => category.section;

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'description': description,
      'payee': payee,
      'taxYear': taxYear,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'receiptPath': receiptPath,
      'receiptUrl': receiptUrl,
    };
  }

  factory TaxTransaction.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];
    final rawCreated = map['createdAt'];
    return TaxTransaction(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: map['categoryId'] as String? ?? TaxCategories.unknown.id,
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      description: map['description'] as String? ?? '',
      payee: map['payee'] as String? ?? '',
      taxYear: (map['taxYear'] as num?)?.toInt() ?? DateTime.now().year,
      createdAt: rawCreated is Timestamp ? rawCreated.toDate() : null,
      receiptPath: map['receiptPath'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }
}
