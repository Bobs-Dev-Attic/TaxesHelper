/// Tax categories and their mapping to TXF (Tax Exchange Format) reference
/// numbers.
///
/// TXF is the de-facto standard import format consumed by TurboTax, H&R Block
/// and other tax software. Each line of a tax form has a numeric "reference
/// number" (the `N` record). The codes below were taken from the public TXF
/// v042 specification (https://taxdataexchange.org/docs/txf/v042/).
///
/// Categories without a [txfCode] (e.g. depreciation, which is normally
/// computed on Form 4562) are still tracked in the app and included in the CSV
/// export, but are reported as "not exported" in the TXF file.
library;

/// Which part of a tax return a category feeds into.
enum TaxFormSection { income, expense, deduction }

extension TaxFormSectionLabel on TaxFormSection {
  String get label {
    switch (this) {
      case TaxFormSection.income:
        return 'Income';
      case TaxFormSection.expense:
        return 'Expense';
      case TaxFormSection.deduction:
        return 'Deduction';
    }
  }

  /// Sign applied to amounts when written to a TXF file. The TXF spec uses
  /// positive dollar amounts for income/gains and negative for
  /// expenses/deductions.
  int get txfSign => this == TaxFormSection.income ? 1 : -1;
}

class TaxCategory {
  /// Stable identifier persisted in Firestore. Never change these strings.
  final String id;

  /// Human-readable name shown in the UI.
  final String label;

  final TaxFormSection section;

  /// TXF reference number (the digits after `N`). Null when the line cannot be
  /// expressed as a simple TXF summary record.
  final String? txfCode;

  /// Tax form this category maps to, e.g. "Schedule C".
  final String form;

  /// Line description on the form, for the export report.
  final String formLine;

  const TaxCategory({
    required this.id,
    required this.label,
    required this.section,
    required this.txfCode,
    required this.form,
    required this.formLine,
  });
}

/// Registry of all supported categories.
class TaxCategories {
  TaxCategories._();

  static const List<TaxCategory> all = [
    // ---------------------------------------------------------------------
    // Income — Schedule C (Profit or Loss From Business)
    // ---------------------------------------------------------------------
    TaxCategory(
      id: 'gross_receipts',
      label: 'Gross receipts / sales',
      section: TaxFormSection.income,
      txfCode: '293',
      form: 'Schedule C',
      formLine: 'Line 1 — Gross receipts',
    ),
    TaxCategory(
      id: 'returns_allowances',
      label: 'Returns and allowances',
      section: TaxFormSection.income,
      txfCode: '296',
      form: 'Schedule C',
      formLine: 'Line 2 — Returns and allowances',
    ),
    TaxCategory(
      id: 'other_income',
      label: 'Other business income',
      section: TaxFormSection.income,
      txfCode: null, // No clean 1:1 TXF summary line; CSV only.
      form: 'Schedule C',
      formLine: 'Line 6 — Other income',
    ),

    // ---------------------------------------------------------------------
    // Expenses — Schedule C, Part II
    // ---------------------------------------------------------------------
    TaxCategory(
      id: 'advertising',
      label: 'Advertising',
      section: TaxFormSection.expense,
      txfCode: '304',
      form: 'Schedule C',
      formLine: 'Line 8 — Advertising',
    ),
    TaxCategory(
      id: 'car_truck',
      label: 'Car and truck expenses',
      section: TaxFormSection.expense,
      txfCode: '306',
      form: 'Schedule C',
      formLine: 'Line 9 — Car and truck expenses',
    ),
    TaxCategory(
      id: 'commissions_fees',
      label: 'Commissions and fees',
      section: TaxFormSection.expense,
      txfCode: '307',
      form: 'Schedule C',
      formLine: 'Line 10 — Commissions and fees',
    ),
    TaxCategory(
      id: 'contract_labor',
      label: 'Contract labor',
      section: TaxFormSection.expense,
      txfCode: '685',
      form: 'Schedule C',
      formLine: 'Line 11 — Contract labor',
    ),
    TaxCategory(
      id: 'depletion',
      label: 'Depletion',
      section: TaxFormSection.expense,
      txfCode: '309',
      form: 'Schedule C',
      formLine: 'Line 12 — Depletion',
    ),
    TaxCategory(
      id: 'depreciation',
      label: 'Depreciation',
      section: TaxFormSection.expense,
      txfCode: null, // Computed on Form 4562; CSV only.
      form: 'Schedule C',
      formLine: 'Line 13 — Depreciation',
    ),
    TaxCategory(
      id: 'employee_benefits',
      label: 'Employee benefit programs',
      section: TaxFormSection.expense,
      txfCode: '308',
      form: 'Schedule C',
      formLine: 'Line 14 — Employee benefit programs',
    ),
    TaxCategory(
      id: 'insurance',
      label: 'Insurance (other than health)',
      section: TaxFormSection.expense,
      txfCode: '310',
      form: 'Schedule C',
      formLine: 'Line 15 — Insurance',
    ),
    TaxCategory(
      id: 'interest_mortgage',
      label: 'Interest — mortgage',
      section: TaxFormSection.expense,
      txfCode: '311',
      form: 'Schedule C',
      formLine: 'Line 16a — Interest (mortgage)',
    ),
    TaxCategory(
      id: 'interest_other',
      label: 'Interest — other',
      section: TaxFormSection.expense,
      txfCode: '312',
      form: 'Schedule C',
      formLine: 'Line 16b — Interest (other)',
    ),
    TaxCategory(
      id: 'legal_professional',
      label: 'Legal and professional services',
      section: TaxFormSection.expense,
      txfCode: '298',
      form: 'Schedule C',
      formLine: 'Line 17 — Legal and professional',
    ),
    TaxCategory(
      id: 'office_expense',
      label: 'Office expense',
      section: TaxFormSection.expense,
      txfCode: '313',
      form: 'Schedule C',
      formLine: 'Line 18 — Office expense',
    ),
    TaxCategory(
      id: 'pension_profit_sharing',
      label: 'Pension and profit-sharing plans',
      section: TaxFormSection.expense,
      txfCode: '314',
      form: 'Schedule C',
      formLine: 'Line 19 — Pension and profit-sharing',
    ),
    TaxCategory(
      id: 'rent_vehicles_equipment',
      label: 'Rent — vehicles, machinery, equipment',
      section: TaxFormSection.expense,
      txfCode: '299',
      form: 'Schedule C',
      formLine: 'Line 20a — Rent (vehicles/equipment)',
    ),
    TaxCategory(
      id: 'rent_other_property',
      label: 'Rent — other business property',
      section: TaxFormSection.expense,
      txfCode: '300',
      form: 'Schedule C',
      formLine: 'Line 20b — Rent (other property)',
    ),
    TaxCategory(
      id: 'repairs_maintenance',
      label: 'Repairs and maintenance',
      section: TaxFormSection.expense,
      txfCode: '315',
      form: 'Schedule C',
      formLine: 'Line 21 — Repairs and maintenance',
    ),
    TaxCategory(
      id: 'supplies',
      label: 'Supplies',
      section: TaxFormSection.expense,
      txfCode: '301',
      form: 'Schedule C',
      formLine: 'Line 22 — Supplies',
    ),
    TaxCategory(
      id: 'taxes_licenses',
      label: 'Taxes and licenses',
      section: TaxFormSection.expense,
      txfCode: '316',
      form: 'Schedule C',
      formLine: 'Line 23 — Taxes and licenses',
    ),
    TaxCategory(
      id: 'travel',
      label: 'Travel',
      section: TaxFormSection.expense,
      txfCode: '317',
      form: 'Schedule C',
      formLine: 'Line 24a — Travel',
    ),
    TaxCategory(
      id: 'meals',
      label: 'Meals',
      section: TaxFormSection.expense,
      txfCode: '294',
      form: 'Schedule C',
      formLine: 'Line 24b — Meals',
    ),
    TaxCategory(
      id: 'utilities',
      label: 'Utilities',
      section: TaxFormSection.expense,
      txfCode: '318',
      form: 'Schedule C',
      formLine: 'Line 25 — Utilities',
    ),
    TaxCategory(
      id: 'wages',
      label: 'Wages paid',
      section: TaxFormSection.expense,
      txfCode: '297',
      form: 'Schedule C',
      formLine: 'Line 26 — Wages',
    ),
    TaxCategory(
      id: 'cogs_purchases',
      label: 'Cost of goods — purchases',
      section: TaxFormSection.expense,
      txfCode: '493',
      form: 'Schedule C',
      formLine: 'Line 36 — Purchases (COGS)',
    ),
    TaxCategory(
      id: 'other_expenses',
      label: 'Other business expenses',
      section: TaxFormSection.expense,
      txfCode: '302',
      form: 'Schedule C',
      formLine: 'Line 27a — Other expenses',
    ),

    // ---------------------------------------------------------------------
    // Personal itemized deductions — Schedule A
    // ---------------------------------------------------------------------
    TaxCategory(
      id: 'charity_cash',
      label: 'Charitable contributions — cash',
      section: TaxFormSection.deduction,
      txfCode: '280',
      form: 'Schedule A',
      formLine: 'Line 11 — Cash charitable gifts',
    ),
    TaxCategory(
      id: 'charity_noncash',
      label: 'Charitable contributions — non-cash',
      section: TaxFormSection.deduction,
      txfCode: '485',
      form: 'Schedule A',
      formLine: 'Line 12 — Non-cash charitable gifts',
    ),
    TaxCategory(
      id: 'mortgage_interest',
      label: 'Home mortgage interest (1098)',
      section: TaxFormSection.deduction,
      txfCode: '283',
      form: 'Schedule A',
      formLine: 'Line 8a — Home mortgage interest',
    ),
    TaxCategory(
      id: 'state_income_tax',
      label: 'State and local income taxes',
      section: TaxFormSection.deduction,
      txfCode: '275',
      form: 'Schedule A',
      formLine: 'Line 5a — State/local income taxes',
    ),
    TaxCategory(
      id: 'real_estate_tax',
      label: 'Real estate taxes',
      section: TaxFormSection.deduction,
      txfCode: '276',
      form: 'Schedule A',
      formLine: 'Line 5b — Real estate taxes',
    ),
    TaxCategory(
      id: 'personal_property_tax',
      label: 'Personal property taxes',
      section: TaxFormSection.deduction,
      txfCode: '535',
      form: 'Schedule A',
      formLine: 'Line 5c — Personal property taxes',
    ),
    TaxCategory(
      id: 'medical',
      label: 'Medical and dental expenses',
      section: TaxFormSection.deduction,
      txfCode: '273',
      form: 'Schedule A',
      formLine: 'Line 1 — Medical and dental',
    ),
    TaxCategory(
      id: 'investment_fees',
      label: 'Investment management fees',
      section: TaxFormSection.deduction,
      txfCode: '282',
      form: 'Schedule A',
      formLine: 'Investment management fees',
    ),
  ];

  static final Map<String, TaxCategory> _byId = {
    for (final c in all) c.id: c,
  };

  static final Map<String, TaxCategory> _byLabel = {
    for (final c in all) c.label.toLowerCase(): c,
  };

  static final Map<String, TaxCategory> _byTxfCode = {
    for (final c in all)
      if (c.txfCode != null) c.txfCode!: c,
  };

  static TaxCategory? byId(String? id) => id == null ? null : _byId[id];

  /// Used when importing: matches the human-readable label (case-insensitive).
  static TaxCategory? byLabel(String? label) =>
      label == null ? null : _byLabel[label.trim().toLowerCase()];

  /// Used when importing: matches a TXF reference number.
  static TaxCategory? byTxfCode(String? code) {
    final trimmed = code?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : _byTxfCode[trimmed];
  }

  static List<TaxCategory> forSection(TaxFormSection section) =>
      all.where((c) => c.section == section).toList(growable: false);

  /// Fallback used when a stored category id is no longer recognised.
  static const TaxCategory unknown = TaxCategory(
    id: 'unknown',
    label: 'Uncategorized',
    section: TaxFormSection.expense,
    txfCode: null,
    form: '—',
    formLine: '—',
  );
}
