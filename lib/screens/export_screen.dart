import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import '../models/tax_transaction.dart';
import '../services/export_service.dart';
import 'forms_screen.dart';

/// Lets the user preview and share a TurboTax-ready TXF file or a CSV.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.taxYear,
    required this.transactions,
  });

  final int taxYear;
  final List<TaxTransaction> transactions;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _exporter = ExportService();

  Future<void> _share(ExportResult result, String mimeType) async {
    // Dart 3's utf8.encode already returns a Uint8List.
    final file = XFile.fromData(
      utf8.encode(result.contents),
      mimeType: mimeType,
      name: result.filename,
    );
    await Share.shareXFiles(
      [file],
      subject: 'Taxes Helper export — ${widget.taxYear}',
    );
  }

  void _copy(String contents) {
    Clipboard.setData(ClipboardData(text: contents));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txf = _exporter.buildTxf(widget.transactions, widget.taxYear);
    final csv = _exporter.buildCsv(widget.transactions, widget.taxYear);

    return Scaffold(
      appBar: AppBar(title: Text('Export ${widget.taxYear}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Prepopulated tax forms (PDF)'),
              subtitle: const Text(
                  'Schedule C & Schedule A worksheet filled with your totals. '
                  'Preview, print or save.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FormsScreen(
                    taxYear: widget.taxYear,
                    transactions: widget.transactions,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FormatCard(
            title: 'TurboTax / tax software (.txf)',
            description:
                'Tax Exchange Format. In TurboTax Desktop choose '
                'File ▸ Import ▸ From Accounting Software ▸ Other Financial '
                'Software (TXF) and select this file. Schedule C and Schedule A '
                'line items are summed per form line.',
            icon: Icons.account_balance_outlined,
            preview: txf.contents,
            onShare: () => _share(txf, 'text/plain'),
            onCopy: () => _copy(txf.contents),
            warnings: txf.unmappedCategories.isEmpty
                ? null
                : 'Not included in TXF (no standard code — use the CSV for '
                    'these): ${txf.unmappedCategories.join(', ')}.',
          ),
          const SizedBox(height: 16),
          _FormatCard(
            title: 'Spreadsheet (.csv)',
            description:
                'Every transaction, line by line. Opens in Excel or Google '
                'Sheets and is handy for your accountant or as a backup.',
            icon: Icons.table_chart_outlined,
            preview: csv.contents,
            onShare: () => _share(csv, 'text/csv'),
            onCopy: () => _copy(csv.contents),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This export is a convenience to speed up data entry. '
                      'Always review the numbers in your tax software and '
                      'consult a tax professional — Taxes Helper is not tax '
                      'advice.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.preview,
    required this.onShare,
    required this.onCopy,
    this.warnings,
  });

  final String title;
  final String description;
  final IconData icon;
  final String preview;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final String? warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
            if (warnings != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(warnings!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview.isEmpty ? '(nothing to export)' : preview,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share / Save'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
