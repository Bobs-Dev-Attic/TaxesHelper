# Taxes Helper

A cross-platform **Flutter** app with a **Firebase** backend for recording
**income, expenses, and deductions** throughout the year, then exporting them at
tax time in a format you can **import into TurboTax** (and most other tax
software) — plus a CSV for your spreadsheet or accountant.

> ⚠️ Taxes Helper is a bookkeeping convenience, **not tax advice**. Always
> review the figures in your tax software and consult a professional.

---

## Features

- 🔐 **Email/password auth** (Firebase Auth) — each user only sees their own data.
- 🧾 **Record transactions** as Income, Expense, or Deduction, each mapped to a
  real tax-form line (Schedule C for business, Schedule A for itemized
  deductions).
- 📊 **Dashboard** with per-section totals and an estimated net business profit.
- 🗓️ **Per-tax-year** filtering; the tax year follows the transaction date.
- 📤 **Exports**
  - **`.txf`** (Tax Exchange Format v042) — import into TurboTax / H&R Block.
    Amounts are summed per tax-form line, income positive / expenses negative,
    using the official TXF reference numbers.
  - **`.csv`** — every transaction, line by line, for Excel/Sheets.
- ☁️ **Realtime sync** across devices via Cloud Firestore.

## Project structure

```
lib/
  main.dart                       App bootstrap + Firebase init
  firebase_options.dart           TEMPLATE — regenerate with flutterfire
  theme.dart                      Material 3 theming
  models/
    tax_category.dart             Categories + verified TXF reference codes
    tax_transaction.dart          Transaction model + Firestore (de)serialize
  services/
    auth_service.dart             Firebase Auth wrapper (ChangeNotifier)
    firestore_service.dart        Per-user transaction CRUD + streams
    export_service.dart           Pure-Dart TXF + CSV generation (unit-tested)
  screens/
    auth_gate.dart                Routes to login vs. home
    login_screen.dart            Sign in / register / reset
    home_screen.dart              Dashboard + list + year picker
    add_edit_transaction_screen.dart
    export_screen.dart            Preview + share/copy TXF & CSV
  widgets/
    summary_card.dart
    transaction_tile.dart
test/
  export_service_test.dart        Unit tests for the export logic
firestore.rules                   Per-user security rules
firestore.indexes.json            Composite index (taxYear + date)
firebase.json
```

## Getting started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.27+
- A [Firebase](https://console.firebase.google.com/) project

### 2. Generate the platform folders

This repo contains the Dart source and config. Generate the
`android/ios/web/...` runners (this merges with the existing files and will
**not** overwrite `lib/`):

```bash
flutter create .
flutter pub get
```

### 3. Connect Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This regenerates `lib/firebase_options.dart` with your project's real values.
Then, in the Firebase console:

1. **Authentication → Sign-in method →** enable **Email/Password**.
2. **Firestore Database →** create a database (production mode).
3. Deploy the security rules and index:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

### 4. Run

```bash
flutter run            # mobile / desktop
flutter run -d chrome  # web
```

### 5. Test

```bash
flutter test
```

## How the TXF export works

Each tax-form line has a numeric **reference number** in the TXF v042 spec. The
app stores a verified mapping in `lib/models/tax_category.dart`, e.g.:

| Category                 | Form        | TXF code |
|--------------------------|-------------|----------|
| Gross receipts           | Schedule C  | 293      |
| Advertising              | Schedule C  | 304      |
| Supplies                 | Schedule C  | 301      |
| Cash charitable gifts    | Schedule A  | 280      |
| Home mortgage interest   | Schedule A  | 283      |

On export, transactions are summed per category and written as TXF **summary**
(`TS`) records:

```
V042
ATaxesHelper
D06/03/2026
^
TS
N293
C1
L1
$12000.00
PGross receipts / sales
^
```

A few categories (e.g. **Depreciation**, computed on Form 4562) have no clean
TXF line; those are listed as "not exported" on the export screen and are
captured in the CSV instead.

**Importing into TurboTax Desktop:** `File ▸ Import ▸ From Accounting Software ▸
Other Financial Software (TXF)` and choose the `.txf` file.
(TurboTax *Online* has limited import support; the CSV is provided as a
fallback for manual entry, and TXF works best with the desktop editions.)

TXF reference numbers are from the public spec at
<https://taxdataexchange.org/docs/txf/v042/>.

## Notes & limitations

- Categories cover Schedule C (sole-proprietor business) and common Schedule A
  itemized deductions. Extend `TaxCategories.all` to add more.
- Sign convention follows the TXF spec (income positive, expenses/deductions
  negative). Some tax importers prefer positive expense amounts — verify after
  import.
- Receipts/attachments are not stored; add Firebase Storage if you need them.
