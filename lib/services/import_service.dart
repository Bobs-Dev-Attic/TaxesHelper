import '../models/tax_category.dart';
import '../models/tax_transaction.dart';

/// A row that could not be turned into a transaction, with the reason.
class ImportProblem {
  final int line; // 1-based line number in the file
  final String message;
  final String raw;

  const ImportProblem({
    required this.line,
    required this.message,
    required this.raw,
  });
}

/// The outcome of parsing a CSV: the transactions we could build plus any
/// rows that were skipped and why. Nothing is written to Firestore here —
/// this is purely for the preview/confirm step.
class ImportPreview {
  final List<TaxTransaction> transactions;
  final List<ImportProblem> problems;

  const ImportPreview({required this.transactions, required this.problems});

  bool get isEmpty => transactions.isEmpty;
  int get total => transactions.length;
}

/// Parses CSV files previously produced by [ExportService] (and reasonable
/// variants) back into [TaxTransaction]s. Pure — no I/O, fully unit-testable.
class ImportService {
  /// Column header aliases we accept (lower-cased), mapped to a logical field.
  static const Map<String, String> _headerAliases = {
    'date': 'date',
    'category': 'category',
    'amount': 'amount',
    'payee': 'payee',
    'payee / source': 'payee',
    'description': 'description',
    'notes': 'description',
    'txf code': 'txf',
    'txf': 'txf',
  };

  ImportPreview parseCsv(String contents) {
    final transactions = <TaxTransaction>[];
    final problems = <ImportProblem>[];

    // Strip a UTF-8 BOM that spreadsheets often prepend.
    final cleaned =
        contents.startsWith('﻿') ? contents.substring(1) : contents;

    final rows = _parseRows(cleaned);
    if (rows.isEmpty) {
      return const ImportPreview(transactions: [], problems: []);
    }

    // Map header names -> column index.
    final header = rows.first;
    final colIndex = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final field = _headerAliases[header[i].trim().toLowerCase()];
      if (field != null) colIndex.putIfAbsent(field, () => i);
    }

    for (final required in ['date', 'category', 'amount']) {
      if (!colIndex.containsKey(required)) {
        return ImportPreview(
          transactions: const [],
          problems: [
            ImportProblem(
              line: 1,
              message:
                  'Missing required column "$required". Expected a header row '
                  'like: Date, Category, Amount, Payee, Description.',
              raw: header.join(','),
            ),
          ],
        );
      }
    }

    String cell(List<String> row, String field) {
      final i = colIndex[field];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final lineNo = r + 1;
      final raw = row.join(',');

      // Skip fully blank lines silently.
      if (row.every((c) => c.trim().isEmpty)) continue;

      final dateStr = cell(row, 'date');
      final date = _parseDate(dateStr);
      if (date == null) {
        problems.add(ImportProblem(
          line: lineNo,
          message: 'Unrecognized date "$dateStr" (expected YYYY-MM-DD).',
          raw: raw,
        ));
        continue;
      }

      final amountStr = cell(row, 'amount');
      final amount = _parseAmount(amountStr);
      if (amount == null) {
        problems.add(ImportProblem(
          line: lineNo,
          message: 'Unrecognized amount "$amountStr".',
          raw: raw,
        ));
        continue;
      }

      final categoryLabel = cell(row, 'category');
      final category = TaxCategories.byLabel(categoryLabel) ??
          TaxCategories.byTxfCode(cell(row, 'txf'));
      if (category == null) {
        problems.add(ImportProblem(
          line: lineNo,
          message: 'Unknown category "$categoryLabel".',
          raw: raw,
        ));
        continue;
      }

      transactions.add(TaxTransaction(
        amount: amount.abs(),
        categoryId: category.id,
        date: date,
        description: cell(row, 'description'),
        payee: cell(row, 'payee'),
        // Tax year follows the date, matching how the app records new entries.
        taxYear: date.year,
      ));
    }

    return ImportPreview(transactions: transactions, problems: problems);
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  /// RFC 4180-ish CSV tokenizer: handles quoted fields, escaped quotes ("")
  /// and both \n and \r\n line endings, including newlines inside quotes.
  List<List<String>> _parseRows(String input) {
    final rows = <List<String>>[];
    var fields = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      fields.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(fields);
      fields = <String>[];
    }

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++; // skip the escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        switch (ch) {
          case '"':
            inQuotes = true;
          case ',':
            endField();
          case '\r':
            // Handle \r\n as a single line break.
            if (i + 1 < input.length && input[i + 1] == '\n') i++;
            endRow();
          case '\n':
            endRow();
          default:
            field.write(ch);
        }
      }
    }

    // Flush the final field/row if the file didn't end with a newline.
    if (field.isNotEmpty || fields.isNotEmpty) endRow();
    return rows;
  }

  DateTime? _parseDate(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    // Primary format produced by the exporter: YYYY-MM-DD.
    final iso = DateTime.tryParse(v);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // Fall back to MM/DD/YYYY (common spreadsheet locale).
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(v);
    if (m != null) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      final year = int.parse(m.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  double? _parseAmount(String value) {
    var v = value.trim();
    if (v.isEmpty) return null;
    final negative = v.startsWith('(') && v.endsWith(')'); // (123.45)
    v = v
        .replaceAll(RegExp(r'[(),$\s]'), '')
        .replaceAll('−', '-'); // unicode minus
    final parsed = double.tryParse(v);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }
}
