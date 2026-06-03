import 'package:flutter_test/flutter_test.dart';
import 'package:taxes_helper/models/tax_transaction.dart';
import 'package:taxes_helper/services/form_summary.dart';

TaxTransaction _tx(double amount, String categoryId, {int year = 2025}) {
  return TaxTransaction(
    amount: amount,
    categoryId: categoryId,
    date: DateTime(year, 5, 1),
    description: '',
    payee: '',
    taxYear: year,
  );
}

void main() {
  group('ScheduleCSummary', () {
    test('computes income, expenses and net profit', () {
      final txs = [
        _tx(10000, 'gross_receipts'),
        _tx(500, 'returns_allowances'),
        _tx(2000, 'cogs_purchases'),
        _tx(300, 'other_income'),
        _tx(400, 'advertising'),
        _tx(600, 'supplies'),
      ];
      final s = ScheduleCSummary.from(txs, 2025);

      expect(s.grossReceipts, 10000);
      expect(s.returnsAllowances, 500);
      expect(s.netReceipts, 9500); // 10000 - 500
      expect(s.costOfGoodsSold, 2000);
      expect(s.grossProfit, 7500); // 9500 - 2000
      expect(s.otherIncome, 300);
      expect(s.grossIncome, 7800); // 7500 + 300
      expect(s.totalExpenses, 1000); // 400 + 600 (COGS excluded)
      expect(s.tentativeProfit, 6800); // 7800 - 1000
      expect(s.netProfit, 6800);
    });

    test('excludes COGS purchases from the Part II expense list', () {
      final s = ScheduleCSummary.from([_tx(2000, 'cogs_purchases')], 2025);
      expect(s.expenses.any((e) => e.label.contains('Cost of goods')), isFalse);
      expect(s.costOfGoodsSold, 2000);
    });

    test('only counts the requested tax year', () {
      final txs = [
        _tx(1000, 'gross_receipts', year: 2025),
        _tx(9999, 'gross_receipts', year: 2024),
      ];
      expect(ScheduleCSummary.from(txs, 2025).grossReceipts, 1000);
    });
  });

  group('ScheduleASummary', () {
    test('lists only non-zero deductions and totals them', () {
      final txs = [
        _tx(1200, 'charity_cash'),
        _tx(8000, 'mortgage_interest'),
        _tx(3000, 'state_income_tax'),
      ];
      final s = ScheduleASummary.from(txs, 2025);
      expect(s.hasData, isTrue);
      expect(s.items.length, 3);
      expect(s.total, 12200);
    });

    test('is empty when there are no deductions', () {
      final s = ScheduleASummary.from([_tx(100, 'supplies')], 2025);
      expect(s.hasData, isFalse);
      expect(s.total, 0);
    });
  });
}
