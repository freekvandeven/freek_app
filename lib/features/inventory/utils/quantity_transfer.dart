// Pure validation + computation for moving quantity between two
// inventory items (WISH-0083). Kept free of Flutter/Firestore imports
// so it can be unit-tested directly.

/// Outcome of applying a transfer: the new quantities for both items.
class TransferOutcome {
  final int fromNewQuantity;
  final int toNewQuantity;
  const TransferOutcome({
    required this.fromNewQuantity,
    required this.toNewQuantity,
  });
}

/// Validates moving [amount] units from the "from" item to the "to"
/// item. A negative [amount] reverses the direction (to → from), per
/// the wish. Returns an error message, or null when the transfer is
/// allowed.
///
/// Rules:
/// - amount must not be zero;
/// - neither item's resulting quantity may drop below zero.
String? validateTransfer({
  required int fromQuantity,
  required int toQuantity,
  required int amount,
}) {
  if (amount == 0) return 'Amount cannot be zero';
  final fromNew = fromQuantity - amount;
  final toNew = toQuantity + amount;
  if (fromNew < 0) {
    return 'Not enough quantity on the source item '
        '($fromQuantity available, $amount requested)';
  }
  if (toNew < 0) {
    return 'Not enough quantity on the target item '
        '($toQuantity available, ${-amount} requested)';
  }
  return null;
}

/// Computes the post-transfer quantities. Call [validateTransfer]
/// first; this throws [ArgumentError] on an invalid transfer as a
/// defensive backstop.
TransferOutcome applyTransfer({
  required int fromQuantity,
  required int toQuantity,
  required int amount,
}) {
  final error = validateTransfer(
    fromQuantity: fromQuantity,
    toQuantity: toQuantity,
    amount: amount,
  );
  if (error != null) throw ArgumentError(error);
  return TransferOutcome(
    fromNewQuantity: fromQuantity - amount,
    toNewQuantity: toQuantity + amount,
  );
}
