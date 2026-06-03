import 'package:flutter_test/flutter_test.dart';
import 'package:taxes_helper/models/tax_transaction.dart';
import 'package:taxes_helper/services/export_service.dart';
import 'package:taxes_helper/services/import_service.dart';

void main() {
  final importer = ImportService();

  group('CSV import', () {
    test('parses a basic file', () {
      const csv = 'Date,Section,Category,Form,Form line,TXF code,Payee,'
          'Description,Amount\r\n'
          '2025-03-15,Income,Gross receipts / sales,Schedule C,Line 1,293,'
          'Client X,Project work,1500.00\r\n'
          '2025-04-01,Expense,Supplies,Schedule C,Line 22,301,Staples,'
          'Paper,42.50';
      final preview = importer.parseCsv(csv);

      expect(preview.problems, isEmpty);
      expect(preview.total, 2);
      expect(preview.transactions[0].categoryId, 'gross_receipts');
      expect(preview.transactions[0].amount, 1500.00);
      expect(preview.transactions[0].taxYear, 2025);
      expect(preview.transactions[1].categoryId, 'supplies');
      expect(preview.transactions[1].payee, 'Staples');
    });

    test('round-trips with the exporter', () {
      final original = [
        TaxTransaction(
          amount: 1200,
          categoryId: 'gross_receipts',
          date: DateTime(2025, 1, 10),
          description: 'invoice, paid',
          payee: 'Acme, Inc.',
          taxYear: 2025,
        ),
        TaxTransaction(
          amount: 99.99,
          categoryId: 'advertising',
          date: DateTime(2025, 6, 2),
          description: 'ads with "quotes"',
          payee: 'Google',
          taxYear: 2025,
        ),
      ];

      final csv = ExportService().buildCsv(original, 2025).contents;
      final preview = importer.parseCsv(csv);

      expect(preview.problems, isEmpty);
      expect(preview.total, original.length);
      for (var i = 0; i < original.length; i++) {
        final a = original[i];
        // Exporter sorts by date; both inputs are already in date order.
        final b = preview.transactions[i];
        expect(b.amount, a.amount);
        expect(b.categoryId, a.categoryId);
        expect(b.date, a.date);
        expect(b.payee, a.payee);
        expect(b.description, a.description);
        expect(b.taxYear, a.taxYear);
      }
    });

    test('matches category by TXF code when label is unknown', () {
      const csv = 'Date,Category,TXF code,Amount\n'
          '2025-02-02,Some Renamed Label,301,10.00';
      final preview = importer.parseCsv(csv);
      expect(preview.total, 1);
      expect(preview.transactions.first.categoryId, 'supplies');
    });

    test('reports bad dates and amounts', () {
      const csv = 'Date,Category,Amount\n'
          'not-a-date,Supplies,10\n'
          '2025-02-02,Supplies,abc\n'
          '2025-02-03,Supplies,15.00';
      final preview = importer.parseCsv(csv);
      expect(preview.total, 1);
      expect(preview.problems.length, 2);
      expect(preview.problems.first.line, 2);
    });

    test('handles reordered columns and aliases', () {
      const csv = 'Amount,Notes,Category,Payee / source,Date\n'
          '25.00,lunch,Meals,Cafe,2025-07-04';
      final preview = importer.parseCsv(csv);
      expect(preview.total, 1);
      final t = preview.transactions.first;
      expect(t.categoryId, 'meals');
      expect(t.amount, 25.00);
      expect(t.payee, 'Cafe');
      expect(t.description, 'lunch');
    });

    test('accepts MM/DD/YYYY dates and parenthesised/\$ amounts', () {
      const csv = 'Date,Category,Amount\n'
          '07/04/2025,Supplies,"\$1,250.00"\n'
          '07/05/2025,Supplies,(50.00)';
      final preview = importer.parseCsv(csv);
      expect(preview.total, 2);
      expect(preview.transactions[0].date, DateTime(2025, 7, 4));
      expect(preview.transactions[0].amount, 1250.00);
      // Negative is normalised to a positive stored amount.
      expect(preview.transactions[1].amount, 50.00);
    });

    test('fails clearly when a required column is missing', () {
      const csv = 'Date,Payee,Amount\n2025-01-01,Acme,10';
      final preview = importer.parseCsv(csv);
      expect(preview.isEmpty, isTrue);
      expect(preview.problems.single.message, contains('category'));
    });
  });
}
