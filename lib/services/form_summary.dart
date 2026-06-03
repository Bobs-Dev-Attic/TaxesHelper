import '../models/tax_category.dart';
import '../models/tax_transaction.dart';

/// One line of a tax form: its line reference, label and computed amount.
class FormLineItem {
  final String lineRef; // e.g. "Line 22"
  final String label; // e.g. "Supplies"
  final double amount;

  const FormLineItem({
    required this.lineRef,
    required this.label,
    required this.amount,
  });
}

/// Splits a category's `formLine` (e.g. "Line 22 — Supplies") into its parts.
({String ref, String label}) _splitFormLine(TaxCategory c) {
  final parts = c.formLine.split(' — ');
  if (parts.length >= 2) {
    return (ref: parts.first.trim(), label: parts.sublist(1).join(' — ').trim());
  }
  return (ref: c.formLine, label: c.label);
}

double _sum(Map<String, double> totals, String id) => totals[id] ?? 0;

/// Computes per-category totals for a single tax year. Pure & testable.
Map<String, double> _categoryTotals(List<TaxTransaction> txs, int taxYear) {
  final totals = <String, double>{};
  for (final t in txs) {
    if (t.taxYear != taxYear) continue;
    totals.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
  }
  return totals;
}

/// Schedule C (Profit or Loss From Business) worksheet figures.
class ScheduleCSummary {
  final double grossReceipts; // Line 1
  final double returnsAllowances; // Line 2
  final double netReceipts; // Line 3 = 1 - 2
  final double costOfGoodsSold; // Line 4 (from Part III)
  final double grossProfit; // Line 5 = 3 - 4
  final double otherIncome; // Line 6
  final double grossIncome; // Line 7 = 5 + 6

  final List<FormLineItem> expenses; // Lines 8–27a (excludes COGS)
  final double totalExpenses; // Line 28
  final double tentativeProfit; // Line 29 = 7 - 28
  final double netProfit; // Line 31 (no home-office line tracked)

  const ScheduleCSummary({
    required this.grossReceipts,
    required this.returnsAllowances,
    required this.netReceipts,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.otherIncome,
    required this.grossIncome,
    required this.expenses,
    required this.totalExpenses,
    required this.tentativeProfit,
    required this.netProfit,
  });

  factory ScheduleCSummary.from(List<TaxTransaction> txs, int taxYear) {
    final totals = _categoryTotals(txs, taxYear);

    final grossReceipts = _sum(totals, 'gross_receipts');
    final returns = _sum(totals, 'returns_allowances');
    final netReceipts = grossReceipts - returns;
    final cogs = _sum(totals, 'cogs_purchases');
    final grossProfit = netReceipts - cogs;
    final otherIncome = _sum(totals, 'other_income');
    final grossIncome = grossProfit + otherIncome;

    final expenses = <FormLineItem>[];
    var totalExpenses = 0.0;
    for (final c in TaxCategories.forSection(TaxFormSection.expense)) {
      if (c.id == 'cogs_purchases') continue; // belongs to Part III / Line 4
      final amount = _sum(totals, c.id);
      final parts = _splitFormLine(c);
      expenses.add(FormLineItem(
        lineRef: parts.ref,
        label: parts.label,
        amount: amount,
      ));
      totalExpenses += amount;
    }

    final tentativeProfit = grossIncome - totalExpenses;

    return ScheduleCSummary(
      grossReceipts: grossReceipts,
      returnsAllowances: returns,
      netReceipts: netReceipts,
      costOfGoodsSold: cogs,
      grossProfit: grossProfit,
      otherIncome: otherIncome,
      grossIncome: grossIncome,
      expenses: expenses,
      totalExpenses: totalExpenses,
      tentativeProfit: tentativeProfit,
      // No home-office (Line 30) is tracked, so Line 31 == Line 29.
      netProfit: tentativeProfit,
    );
  }

  bool get hasData =>
      grossIncome != 0 || totalExpenses != 0 || costOfGoodsSold != 0;
}

/// Schedule A (Itemized Deductions) worksheet figures.
class ScheduleASummary {
  final List<FormLineItem> items;
  final double total;

  const ScheduleASummary({required this.items, required this.total});

  factory ScheduleASummary.from(List<TaxTransaction> txs, int taxYear) {
    final totals = _categoryTotals(txs, taxYear);
    final items = <FormLineItem>[];
    var total = 0.0;
    for (final c in TaxCategories.forSection(TaxFormSection.deduction)) {
      final amount = _sum(totals, c.id);
      if (amount == 0) continue; // only show deductions the user actually has
      final parts = _splitFormLine(c);
      items.add(FormLineItem(
        lineRef: parts.ref,
        label: parts.label,
        amount: amount,
      ));
      total += amount;
    }
    return ScheduleASummary(items: items, total: total);
  }

  bool get hasData => items.isNotEmpty;
}
