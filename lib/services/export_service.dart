import 'package:intl/intl.dart';

import '../models/tax_category.dart';
import '../models/tax_transaction.dart';

/// Result of building an export, including any data that could not be mapped.
class ExportResult {
  final String contents;

  /// Human-readable filename suggestion, e.g. `taxeshelper_2025.txf`.
  final String filename;

  /// Categories that were skipped because they have no TXF reference number.
  final List<String> unmappedCategories;

  const ExportResult({
    required this.contents,
    required this.filename,
    this.unmappedCategories = const [],
  });
}

/// Builds TurboTax-compatible TXF and spreadsheet-friendly CSV exports.
///
/// All methods are pure (no I/O), which keeps them trivially unit-testable.
class ExportService {
  static const String _appName = 'TaxesHelper';
  static const String _txfVersion = 'V042';

  final DateFormat _txfDateFormat = DateFormat('MM/dd/yyyy');
  final DateFormat _csvDateFormat = DateFormat('yyyy-MM-dd');

  /// Builds a TXF file that TurboTax (and other tax software) can import.
  ///
  /// Transactions are aggregated into one summary record (`TS`) per tax-form
  /// line, which is what tax software expects for Schedule C/A line items.
  ExportResult buildTxf(List<TaxTransaction> transactions, int taxYear) {
    final relevant =
        transactions.where((t) => t.taxYear == taxYear).toList(growable: false);

    // Sum amounts per category.
    final totals = <String, double>{};
    for (final t in relevant) {
      totals.update(t.categoryId, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }

    final buffer = StringBuffer()
      ..writeln(_txfVersion)
      ..writeln('A$_appName')
      ..writeln('D${_txfDateFormat.format(DateTime.now())}')
      ..writeln('^');

    final unmapped = <String>[];

    // Emit in a stable, form-order-friendly sequence.
    for (final category in TaxCategories.all) {
      final total = totals[category.id];
      if (total == null || total == 0) continue;

      if (category.txfCode == null) {
        unmapped.add(category.label);
        continue;
      }

      final signed = total.abs() * category.section.txfSign;
      buffer
        ..writeln('TS')
        ..writeln('N${category.txfCode}')
        ..writeln('C1')
        ..writeln('L1')
        ..writeln('\$${signed.toStringAsFixed(2)}')
        ..writeln('P${_sanitize(category.label)}')
        ..writeln('^');
    }

    return ExportResult(
      contents: buffer.toString(),
      filename: '${_appName.toLowerCase()}_$taxYear.txf',
      unmappedCategories: unmapped,
    );
  }

  /// Builds a per-transaction CSV that opens cleanly in Excel/Google Sheets and
  /// captures everything (including categories with no TXF code).
  ExportResult buildCsv(List<TaxTransaction> transactions, int taxYear) {
    final relevant = transactions
        .where((t) => t.taxYear == taxYear)
        .toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    const header = [
      'Date',
      'Section',
      'Category',
      'Form',
      'Form line',
      'TXF code',
      'Payee',
      'Description',
      'Amount',
    ];

    final rows = <String>[_csvRow(header)];
    for (final t in relevant) {
      final c = t.category;
      rows.add(_csvRow([
        _csvDateFormat.format(t.date),
        c.section.label,
        c.label,
        c.form,
        c.formLine,
        c.txfCode ?? '',
        t.payee,
        t.description,
        t.amount.toStringAsFixed(2),
      ]));
    }

    return ExportResult(
      contents: rows.join('\r\n'),
      filename: '${_appName.toLowerCase()}_$taxYear.csv',
    );
  }

  /// Section totals for the summary UI: income, expense, deduction, net.
  static Map<TaxFormSection, double> sectionTotals(
      List<TaxTransaction> transactions) {
    final result = {
      for (final s in TaxFormSection.values) s: 0.0,
    };
    for (final t in transactions) {
      result.update(t.section, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return result;
  }

  /// Net business profit estimate: income − expenses (deductions excluded as
  /// they apply to the personal return, not Schedule C).
  static double netBusiness(List<TaxTransaction> transactions) {
    final totals = sectionTotals(transactions);
    return (totals[TaxFormSection.income] ?? 0) -
        (totals[TaxFormSection.expense] ?? 0);
  }

  String _csvRow(List<String> values) => values.map(_csvField).join(',');

  String _csvField(String value) {
    final needsQuoting =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuoting ? '"$escaped"' : escaped;
  }

  /// TXF values are newline-delimited, so strip control characters.
  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[\r\n\^]'), ' ').trim();
}
