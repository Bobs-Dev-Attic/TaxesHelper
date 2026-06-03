import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tax_category.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../services/import_service.dart';
import '../widgets/transaction_tile.dart';

/// Lets the user pick a CSV file, preview what will be imported, then confirm.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.service});

  final FirestoreService service;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importer = ImportService();

  String? _fileName;
  ImportPreview? _preview;
  bool _busy = false;

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return; // cancelled
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showError('Could not read the selected file.');
        return;
      }
      final contents = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _fileName = file.name;
        _preview = _importer.parseCsv(contents);
      });
    } catch (e) {
      _showError('Could not open file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null || preview.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.addAll(preview.transactions);
      if (mounted) {
        Navigator.of(context).pop(preview.total);
      }
    } catch (e) {
      _showError('Import failed: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from CSV')),
      body: preview == null
          ? _ChooseFile(busy: _busy, onPick: _pickFile)
          : _Preview(
              fileName: _fileName ?? '',
              preview: preview,
              busy: _busy,
              onPickAnother: _pickFile,
            ),
      bottomNavigationBar: (preview == null || preview.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _confirmImport,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done),
                  label: Text('Import ${preview.total} transaction'
                      '${preview.total == 1 ? '' : 's'}'),
                ),
              ),
            ),
    );
  }
}

class _ChooseFile extends StatelessWidget {
  const _ChooseFile({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Import transactions from a CSV',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Choose a CSV exported by Taxes Helper (or one with Date, '
              'Category and Amount columns). You can review everything before '
              'anything is saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : onPick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose CSV file'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.fileName,
    required this.preview,
    required this.busy,
    required this.onPickAnother,
  });

  final String fileName;
  final ImportPreview preview;
  final bool busy;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();
    final totals = ExportService.sectionTotals(preview.transactions);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fileName,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              onPressed: busy ? null : onPickAnother,
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (preview.isEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No valid transactions found in this file.'),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ready to import ${preview.total} transaction'
                      '${preview.total == 1 ? '' : 's'}',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _totalRow(context, 'Income',
                      totals[TaxFormSection.income] ?? 0, currency),
                  _totalRow(context, 'Expenses',
                      totals[TaxFormSection.expense] ?? 0, currency),
                  _totalRow(context, 'Deductions',
                      totals[TaxFormSection.deduction] ?? 0, currency),
                ],
              ),
            ),
          ),
        ],

        if (preview.problems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('${preview.problems.length} row'
                          '${preview.problems.length == 1 ? '' : 's'} skipped',
                          style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final p in preview.problems.take(20))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Line ${p.line}: ${p.message}',
                          style: theme.textTheme.bodySmall),
                    ),
                  if (preview.problems.length > 20)
                    Text('…and ${preview.problems.length - 20} more',
                        style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],

        if (!preview.isEmpty) ...[
          const SizedBox(height: 16),
          Text('Preview', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          ...preview.transactions.take(50).map(
                (t) => TransactionTile(transaction: t),
              ),
          if (preview.transactions.length > 50)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '…and ${preview.transactions.length - 50} more',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 80), // room above the bottom button
        ],
      ],
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    double value,
    NumberFormat currency,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(currency.format(value),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
