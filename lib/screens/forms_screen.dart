import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/tax_transaction.dart';
import '../services/form_pdf_service.dart';

/// Previews the prepopulated Schedule C / Schedule A worksheet PDF and lets the
/// user print, share or save it. Rendering is delegated to [PdfPreview].
class FormsScreen extends StatelessWidget {
  const FormsScreen({
    super.key,
    required this.taxYear,
    required this.transactions,
  });

  final int taxYear;
  final List<TaxTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final service = FormPdfService();
    return Scaffold(
      appBar: AppBar(title: Text('Tax forms — $taxYear')),
      body: PdfPreview(
        // The worksheet has a fixed Letter layout, so ignore page-format
        // changes and just (re)build the same document.
        build: (_) => service.buildWorksheet(transactions, taxYear),
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'taxeshelper_worksheet_$taxYear.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
