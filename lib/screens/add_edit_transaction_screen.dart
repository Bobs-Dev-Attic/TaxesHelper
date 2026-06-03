import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/tax_category.dart';
import '../models/tax_transaction.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/receipt_view.dart';

class AddEditTransactionScreen extends StatefulWidget {
  const AddEditTransactionScreen({
    super.key,
    required this.service,
    required this.storageService,
    required this.defaultTaxYear,
    this.existing,
  });

  final FirestoreService service;
  final StorageService storageService;
  final int defaultTaxYear;
  final TaxTransaction? existing;

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _payeeController;
  late final TextEditingController _descriptionController;

  late TaxFormSection _section;
  late TaxCategory _category;
  late DateTime _date;
  bool _busy = false;

  // Receipt state.
  // The receipt currently saved on the transaction (if any).
  String? _receiptPath;
  String? _receiptUrl;
  // The storage path that existed when the screen opened, so we can clean it
  // up if the user replaces or removes the receipt.
  String? _originalReceiptPath;
  // A freshly-picked image not yet uploaded.
  Uint8List? _pickedBytes;
  String? _pickedContentType;

  bool get _isEditing => widget.existing != null;
  bool get _hasReceipt => _pickedBytes != null || _receiptUrl != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _section = existing?.section ?? TaxFormSection.expense;
    _category = existing?.category ?? TaxCategories.forSection(_section).first;
    _date = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    _payeeController = TextEditingController(text: existing?.payee ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _receiptPath = existing?.receiptPath;
    _receiptUrl = existing?.receiptUrl;
    _originalReceiptPath = existing?.receiptPath;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSectionChanged(TaxFormSection section) {
    setState(() {
      _section = section;
      // Keep the chosen category if it still belongs to the new section,
      // otherwise reset to the first option.
      if (_category.section != section) {
        _category = TaxCategories.forSection(section).first;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedContentType = file.mimeType ?? 'image/jpeg';
        // Showing the freshly-picked image takes over from any saved one.
        _receiptUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach photo: $e')),
        );
      }
    }
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickReceipt(source);
  }

  void _removeReceipt() {
    setState(() {
      _pickedBytes = null;
      _pickedContentType = null;
      _receiptUrl = null;
      _receiptPath = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      // Upload a newly-picked receipt first, so the transaction we write
      // already points at the stored image.
      if (_pickedBytes != null) {
        final uploaded = await widget.storageService.uploadReceipt(
          _pickedBytes!,
          contentType: _pickedContentType ?? 'image/jpeg',
        );
        _receiptPath = uploaded.path;
        _receiptUrl = uploaded.url;
      }

      final amount =
          double.parse(_amountController.text.replaceAll(',', '').trim());
      final tx = TaxTransaction(
        id: widget.existing?.id,
        amount: amount,
        categoryId: _category.id,
        date: _date,
        description: _descriptionController.text.trim(),
        payee: _payeeController.text.trim(),
        // The tax year follows the transaction date so exports stay correct.
        taxYear: _date.year,
        createdAt: widget.existing?.createdAt,
        receiptPath: _receiptPath,
        receiptUrl: _receiptUrl,
      );

      if (_isEditing) {
        await widget.service.update(tx);
      } else {
        await widget.service.add(tx);
      }

      // Once the write succeeds, delete the old image if it was replaced or
      // removed. Best-effort: a failure here shouldn't block the save.
      if (_originalReceiptPath != null &&
          _originalReceiptPath != _receiptPath) {
        await widget.storageService.deleteReceipt(_originalReceiptPath!);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.delete(widget.existing!.id!);
      final path = widget.existing!.receiptPath;
      if (path != null) {
        await widget.storageService.deleteReceipt(path);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = TaxCategories.forSection(_section);
    final dateFmt = DateFormat.yMMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<TaxFormSection>(
                segments: const [
                  ButtonSegment(
                    value: TaxFormSection.income,
                    label: Text('Income'),
                    icon: Icon(Icons.trending_up),
                  ),
                  ButtonSegment(
                    value: TaxFormSection.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.trending_down),
                  ),
                  ButtonSegment(
                    value: TaxFormSection.deduction,
                    label: Text('Deduction'),
                    icon: Icon(Icons.savings_outlined),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (s) => _onSectionChanged(s.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed =
                      double.tryParse((v ?? '').replaceAll(',', '').trim());
                  if (parsed == null) return 'Enter a valid amount';
                  if (parsed <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaxCategory>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c,
                      child: Text(c.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (c) {
                  if (c != null) setState(() => _category = c);
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${_category.form} • ${_category.formLine}'
                  '${_category.txfCode == null ? '  (CSV only)' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(dateFmt.format(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _payeeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Payee / source',
                  hintText: 'e.g. Acme Corp, Client X',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _buildReceiptSection(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing ? 'Save changes' : 'Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Receipt', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        if (_hasReceipt)
          ReceiptThumbnail(
            bytes: _pickedBytes,
            url: _receiptUrl,
            onView: _viewReceipt,
            onRemove: _busy ? null : _removeReceipt,
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : _chooseReceiptSource,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Attach a receipt photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
      ],
    );
  }

  void _viewReceipt() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptViewerScreen(
          bytes: _pickedBytes,
          url: _receiptUrl,
        ),
      ),
    );
  }
}
