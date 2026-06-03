import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tax_category.dart';
import '../models/tax_transaction.dart';
import '../theme.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final TaxTransaction transaction;
  final VoidCallback? onTap;

  Color _color(BuildContext context) {
    switch (transaction.section) {
      case TaxFormSection.income:
        return SectionColors.income(context);
      case TaxFormSection.expense:
        return SectionColors.expense(context);
      case TaxFormSection.deduction:
        return SectionColors.deduction(context);
    }
  }

  IconData get _icon {
    switch (transaction.section) {
      case TaxFormSection.income:
        return Icons.trending_up;
      case TaxFormSection.expense:
        return Icons.trending_down;
      case TaxFormSection.deduction:
        return Icons.savings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final currency = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat.MMMd();
    final category = transaction.category;
    final sign = transaction.section == TaxFormSection.income ? '+' : '−';
    final title = transaction.payee.isNotEmpty
        ? transaction.payee
        : category.label;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(_icon),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${category.label} • ${dateFmt.format(transaction.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$sign${currency.format(transaction.amount)}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
