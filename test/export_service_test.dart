import 'package:flutter_test/flutter_test.dart';
import 'package:taxes_helper/models/tax_category.dart';
import 'package:taxes_helper/models/tax_transaction.dart';
import 'package:taxes_helper/services/export_service.dart';

TaxTransaction _tx({
  required double amount,
  required String categoryId,
  int year = 2025,
  DateTime? date,
}) {
  return TaxTransaction(
    amount: amount,
    categoryId: categoryId,
    date: date ?? DateTime(year, 3, 15),
    description: 'desc',
    payee: 'payee',
    taxYear: year,
  );
}

void main() {
  final exporter = ExportService();

  group('TXF export', () {
    test('writes a valid v042 header', () {
      final result = exporter.buildTxf(
        [_tx(amount: 100, categoryId: 'gross_receipts')],
        2025,
      );
      final lines = result.contents.split('\n');
      expect(lines.first.trim(), 'V042');
      expect(lines[1].trim(), 'ATaxesHelper');
      expect(lines[2].trim(), startsWith('D'));
      expect(lines[3].trim(), '^');
      expect(result.filename, 'taxeshelper_2025.txf');
    });

    test('income is positive, expenses negative', () {
      final result = exporter.buildTxf(
        [
          _tx(amount: 1000, categoryId: 'gross_receipts'),
          _tx(amount: 250, categoryId: 'advertising'),
        ],
        2025,
      );
      expect(result.contents, contains('N293'));
      expect(result.contents, contains('\$1000.00'));
      expect(result.contents, contains('N304'));
      expect(result.contents, contains('\$-250.00'));
    });

    test('sums multiple transactions in the same category', () {
      final result = exporter.buildTxf(
        [
          _tx(amount: 100, categoryId: 'supplies'),
          _tx(amount: 50, categoryId: 'supplies'),
        ],
        2025,
      );
      // 150 expense -> negative summary record.
      expect(result.contents, contains('\$-150.00'));
      // Only one summary record for the category.
      expect('N301'.allMatches(result.contents).length, 1);
    });

    test('reports categories without a TXF code', () {
      final result = exporter.buildTxf(
        [_tx(amount: 500, categoryId: 'depreciation')],
        2025,
      );
      expect(result.unmappedCategories, contains('Depreciation'));
      // Depreciation has no code, so no TS record should be emitted.
      expect(result.contents.contains('TS'), isFalse);
    });

    test('ignores transactions from other tax years', () {
      final result = exporter.buildTxf(
        [
          _tx(amount: 100, categoryId: 'gross_receipts', year: 2025),
          _tx(amount: 999, categoryId: 'gross_receipts', year: 2024),
        ],
        2025,
      );
      expect(result.contents, contains('\$100.00'));
      expect(result.contents, isNot(contains('999')));
    });
  });

  group('CSV export', () {
    test('has a header row and one row per transaction', () {
      final result = exporter.buildCsv(
        [
          _tx(amount: 100, categoryId: 'gross_receipts'),
          _tx(amount: 25, categoryId: 'supplies'),
        ],
        2025,
      );
      final rows = result.contents.split('\r\n');
      expect(rows.first, startsWith('Date,Section,Category'));
      expect(rows.length, 3); // header + 2
    });

    test('escapes commas and quotes', () {
      final tx = TaxTransaction(
        amount: 10,
        categoryId: 'supplies',
        date: DateTime(2025, 1, 1),
        description: 'pens, pencils and "stuff"',
        payee: 'Acme, Inc.',
        taxYear: 2025,
      );
      final result = exporter.buildCsv([tx], 2025);
      expect(result.contents, contains('"Acme, Inc."'));
      expect(result.contents, contains('"pens, pencils and ""stuff"""'));
    });
  });

  group('summaries', () {
    test('section totals and net business profit', () {
      final txs = [
        _tx(amount: 1000, categoryId: 'gross_receipts'),
        _tx(amount: 300, categoryId: 'supplies'),
        _tx(amount: 200, categoryId: 'charity_cash'),
      ];
      final totals = ExportService.sectionTotals(txs);
      expect(totals[TaxFormSection.income], 1000);
      expect(totals[TaxFormSection.expense], 300);
      expect(totals[TaxFormSection.deduction], 200);
      // Net = income - expenses (deductions excluded).
      expect(ExportService.netBusiness(txs), 700);
    });
  });
}
