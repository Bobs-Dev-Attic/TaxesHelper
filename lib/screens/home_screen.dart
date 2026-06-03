import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tax_transaction.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_edit_transaction_screen.dart';
import 'export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});

  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FirestoreService _service = FirestoreService(widget.uid);
  late int _taxYear = DateTime.now().year;
  // Cache the stream so rebuilds don't resubscribe to Firestore on every frame.
  late Stream<List<TaxTransaction>> _stream = _service.watchTransactions(_taxYear);

  void _setTaxYear(int year) {
    if (year == _taxYear) return;
    setState(() {
      _taxYear = year;
      _stream = _service.watchTransactions(year);
    });
  }

  List<int> get _yearChoices {
    final current = DateTime.now().year;
    // Offer the current year plus the previous four.
    return [for (var y = current; y >= current - 4; y--) y];
  }

  Future<void> _openEditor([TaxTransaction? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(
          service: _service,
          defaultTaxYear: _taxYear,
          existing: existing,
        ),
      ),
    );
  }

  void _openExport(List<TaxTransaction> transactions) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExportScreen(
          taxYear: _taxYear,
          transactions: transactions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A single subscription feeds both the body and the FAB. Firestore's
    // snapshots() stream is single-subscription, so we must not listen twice.
    return StreamBuilder<List<TaxTransaction>>(
      stream: _stream,
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? const <TaxTransaction>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Taxes Helper'),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Tax year',
                onSelected: _setTaxYear,
                itemBuilder: (_) => [
                  for (final y in _yearChoices)
                    PopupMenuItem(value: y, child: Text('Tax year $y')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text('$_taxYear'),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthService>().signOut(),
              ),
            ],
          ),
          body: _buildBody(snapshot, transactions),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (transactions.isNotEmpty)
                FloatingActionButton.small(
                  heroTag: 'export',
                  tooltip: 'Export for taxes',
                  onPressed: () => _openExport(transactions),
                  child: const Icon(Icons.ios_share),
                ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'add',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<TaxTransaction>> snapshot,
    List<TaxTransaction> transactions,
  ) {
    if (snapshot.hasError) {
      return _ErrorState(message: snapshot.error.toString());
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SummaryCard(transactions: transactions),
        ),
        Expanded(
          child: transactions.isEmpty
              ? _EmptyState(year: _taxYear, onAdd: _openEditor)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96, top: 8),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) => TransactionTile(
                    transaction: transactions[i],
                    onTap: () => _openEditor(transactions[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.year, required this.onAdd});

  final int year;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Nothing logged for $year yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap “Add” to record your first piece of income,\nan expense, or a deduction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('Could not load your data.',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
