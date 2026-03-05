import 'package:moneko/features/import/domain/import_models.dart';

// ---------------------------------------------------------------------------
// Auto-mapping: header → ImportField
// ---------------------------------------------------------------------------

/// Maps CSV column headers to import fields automatically by matching against
/// an extensive list of synonyms used by major banks and financial apps.
///
/// Returns the best [ImportMapping] found, and also sets [hasSplitDebitCredit]
/// when separate debit and credit columns are detected.
ImportMapping autoMapFields(List<String> headers) {
  final normalized = headers.map(_normalizeHeader).toList();
  final mapping = <ImportField, int>{};

  // ── Field synonym tables ─────────────────────────────────────────────────
  //
  // Keys: target ImportField
  // Values: list of normalized header strings that should map to that field.
  // Order matters within each list (first match wins).
  //
  const synonyms = <ImportField, List<String>>{
    ImportField.date: [
      // Generic
      'date', 'transactiondate', 'txdate', 'txndate',
      // Bank-specific
      'posteddate', 'postingdate', 'settlementdate', 'valuedate',
      'bookingdate', 'bookdate', 'statementdate', 'completeddate',
      'datestarted', 'datecompleted', 'processingdate', 'entrydate',
      'tradedate', 'effectivedate',
      // Named
      'time', 'datetime', 'timestamp',
    ],
    ImportField.amount: [
      // Generic
      'amount', 'amt', 'value', 'total', 'sum', 'price',
      // Bank-specific (single column, signed)
      'transactionamount', 'txamount', 'txnamt', 'netamount',
      'paymentamount', 'chargeamount', 'purchaseamount',
      // PayPal
      'net', 'gross',
    ],
    ImportField.debit: [
      // Bank statement split columns
      'debit', 'debitamount', 'withdrawal', 'withdrawals',
      'debiteur', 'charge', 'out', 'outflow', 'paid',
      'dr', 'dr.', 'money out',
    ],
    ImportField.credit: [
      // Bank statement split columns
      'credit', 'creditamount', 'deposit', 'deposits',
      'crediteur', 'payment', 'in', 'inflow', 'received',
      'cr', 'cr.', 'money in',
    ],
    ImportField.balance: [
      'balance',
      'runningbal',
      'runningbalance',
      'closingbalance',
      'availablebalance',
      'ledgerbalance',
      'accountbalance',
    ],
    ImportField.category: [
      'category',
      'cat',
      'subcategory',
      'transactioncategory',
      'merchantcategory',
      'spendingcategory',
      'type',
    ],
    ImportField.description: [
      // Generic
      'description', 'memo', 'note', 'notes', 'narrative',
      // Bank-specific
      'merchant', 'merchantname', 'payee', 'payeename',
      'name', 'counterparty', 'beneficiary', 'vendor',
      'details', 'particulars', 'narration', 'remarks',
      'information', 'label', 'title',
      // Revolut / Wise
      'productname', 'balanceamount',
    ],
    ImportField.currency: [
      'currency',
      'curr',
      'ccy',
      'code',
      'iso',
      'currencycode',
      'transactioncurrency',
      'accountcurrency',
    ],
    ImportField.type: [
      'type',
      'transactiontype',
      'txtype',
      'txntype',
      'kind',
      'direction',
      'drcr',
      'dr/cr',
      'creditdebit',
    ],
    ImportField.reference: [
      'reference',
      'ref',
      'refno',
      'referencenumber',
      'transactionid',
      'txid',
      'txnid',
      'id',
      'paymentreference',
      'checkno',
      'checknumber',
    ],
  };

  // ── First pass: exact / near-exact synonym matching ──────────────────────

  for (final entry in synonyms.entries) {
    final field = entry.key;
    if (mapping.containsKey(field)) continue; // already assigned
    final candidates = entry.value;
    for (var i = 0; i < normalized.length; i++) {
      if (candidates.contains(normalized[i])) {
        mapping[field] = i;
        break;
      }
    }
  }

  // ── Second pass: substring matching for headers not yet mapped ───────────
  // Example: "Transaction Date" → normalizes to "transactiondate" → exact.
  // But "Date of Transaction" → "dateoftransaction" → not exact.
  // We try partial substring matching as fallback.

  final unmapped = synonyms.keys.where((f) => !mapping.containsKey(f)).toList();
  for (final field in unmapped) {
    final candidates = synonyms[field]!;
    for (var i = 0; i < normalized.length; i++) {
      final h = normalized[i];
      if (candidates.any((c) => h.contains(c))) {
        mapping[field] = i;
        break;
      }
    }
  }

  // ── Detect split debit/credit mode ──────────────────────────────────────

  final hasSplit = mapping.containsKey(ImportField.debit) &&
      mapping.containsKey(ImportField.credit);

  // When split columns are found, remove generic 'amount' if it was mapped
  // to avoid ambiguity — the user can re-add it manually.
  if (hasSplit) {
    mapping.remove(ImportField.amount);
  }

  // ── Bank-specific overrides ──────────────────────────────────────────────
  //
  // Some banks put the transaction type embedded in the description column
  // rather than a separate type column. We don't need to handle this in
  // mapping — the type resolver in the parser uses amount sign as fallback.

  return ImportMapping(
    fieldToColumnIndex: mapping,
    hasSplitDebitCredit: hasSplit,
  );
}

// ---------------------------------------------------------------------------
// Header normalization
// ---------------------------------------------------------------------------

/// Normalizes a header string for comparison: lower-case, strips all
/// non-alphanumeric characters (spaces, dashes, parentheses, etc.).
String _normalizeHeader(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
