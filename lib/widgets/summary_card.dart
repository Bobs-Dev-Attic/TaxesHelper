import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tax_category.dart';
import '../models/tax_transaction.dart';
import '../services/export_service.dart';
import '../theme.dart';

/// Dashboard header summarising income, expenses, deductions and net profit.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.transactions});

  final List<TaxTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final totals = ExportService.sectionTotals(transactions);
    final net = ExportService.netBusiness(transactions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Stat(
                  label: 'Income',
                  value: currency.format(totals[TaxFormSection.income] ?? 0),
                  color: SectionColors.income(context),
                ),
                _Stat(
                  label: 'Expenses',
                  value: currency.format(totals[TaxFormSection.expense] ?? 0),
                  color: SectionColors.expense(context),
                ),
                _Stat(
                  label: 'Deductions',
                  value: currency.format(totals[TaxFormSection.deduction] ?? 0),
                  color: SectionColors.deduction(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net business profit (Sch. C)',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  currency.format(net),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: net >= 0
                            ? SectionColors.income(context)
                            : SectionColors.expense(context),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
