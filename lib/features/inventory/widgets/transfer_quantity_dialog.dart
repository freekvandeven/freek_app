import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/widgets/app_snackbar.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../utils/quantity_transfer.dart';

/// Dialog for moving quantity between two inventory items (WISH-0083).
///
/// When [fixedFromItemId] is provided (opened from an item's own page),
/// the source is locked to that item and the user only picks the target
/// and the amount. Without it (opened from the overview), both items
/// are selectable. A negative amount reverses the direction.
///
/// Returns true when a transfer was performed, so callers can refresh
/// any local state (e.g. the edit form's quantity field).
Future<bool?> showTransferQuantityDialog(
  BuildContext context, {
  String? fixedFromItemId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _TransferQuantityDialog(fixedFromItemId: fixedFromItemId),
  );
}

class _TransferQuantityDialog extends ConsumerStatefulWidget {
  final String? fixedFromItemId;
  const _TransferQuantityDialog({this.fixedFromItemId});

  @override
  ConsumerState<_TransferQuantityDialog> createState() =>
      _TransferQuantityDialogState();
}

class _TransferQuantityDialogState
    extends ConsumerState<_TransferQuantityDialog> {
  /// Sentinel dropdown value for "create a new item at another
  /// location" instead of picking an existing target (WISH-0088).
  static const _newItemSentinel = '__new_item__';

  final _amountController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  String? _fromId;
  String? _toId;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _fromId = widget.fixedFromItemId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountController.text.trim());

  bool get _isCreateNew => _toId == _newItemSentinel;

  /// Current validation error for the chosen items + amount, or null
  /// when the transfer is allowed. Also used to disable the button.
  String? _validationError(List<InventoryItem> items) {
    if (_fromId == null || _toId == null) return null; // incomplete, no error
    final from = items.where((i) => i.id == _fromId).firstOrNull;
    if (from == null) return 'Item not found';
    final amount = _amount;
    if (amount == null) return 'Enter a whole number';
    if (_isCreateNew) {
      if (_locationController.text.trim().isEmpty) {
        return 'Enter a location for the new item';
      }
      return validateTransferToNew(fromQuantity: from.quantity, amount: amount);
    }
    if (_fromId == _toId) return 'Choose two different items';
    final to = items.where((i) => i.id == _toId).firstOrNull;
    if (to == null) return 'Item not found';
    return validateTransfer(
      fromQuantity: from.quantity,
      toQuantity: to.quantity,
      amount: amount,
    );
  }

  /// Preview line like "Pasta: 5 → 3 · Rice: 1 → 3" once everything
  /// is filled in and valid.
  String? _preview(List<InventoryItem> items) {
    final amount = _amount;
    if (_fromId == null || _toId == null || amount == null) return null;
    final from = items.where((i) => i.id == _fromId).firstOrNull;
    if (from == null) return null;
    if (_validationError(items) != null) return null;
    if (_isCreateNew) {
      return '${from.name}: ${from.quantity} → ${from.quantity - amount}'
          '  ·  New item at ${_locationController.text.trim()}: $amount';
    }
    final to = items.where((i) => i.id == _toId).firstOrNull;
    if (to == null) return null;
    return '${from.name}: ${from.quantity} → ${from.quantity - amount}'
        '  ·  ${to.name}: ${to.quantity} → ${to.quantity + amount}';
  }

  Future<void> _transfer() async {
    setState(() => _isTransferring = true);
    try {
      final notifier = ref.read(inventoryListProvider.notifier);
      if (_isCreateNew) {
        await notifier.transferToNewItem(
          fromId: _fromId!,
          location: _locationController.text,
          amount: _amount!,
        );
      } else {
        await notifier.transferQuantity(
          fromId: _fromId!,
          toId: _toId!,
          amount: _amount!,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        context.showErrorSnackbar(e.message.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        context.showErrorSnackbar('Transfer failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inventoryListProvider).valueOrNull ?? const [];
    final sorted = items.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final error = _validationError(sorted);
    final preview = _preview(sorted);
    final ready =
        _fromId != null && _toId != null && _amount != null && error == null;

    return AlertDialog(
      title: const Text('Transfer quantity'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _itemDropdown(
              label: 'From',
              value: _fromId,
              items: sorted,
              enabled: widget.fixedFromItemId == null,
              onChanged: (v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: 12),
            _itemDropdown(
              label: 'To',
              value: _toId,
              items: sorted,
              excludeId: _fromId,
              includeNewItemOption: true,
              onChanged: (v) => setState(() => _toId = v),
            ),
            if (_isCreateNew) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'New item location',
                  border: OutlineInputBorder(),
                  helperText:
                      'A copy of the source item is created here with the '
                      'transferred amount (images are not copied).',
                  helperMaxLines: 3,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                helperText: _isCreateNew
                    ? 'How much to split off into the new item.'
                    : 'Negative amounts transfer in the other direction.',
                helperMaxLines: 2,
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (_) => setState(() {}),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ] else if (preview != null) ...[
              const SizedBox(height: 8),
              Text(preview, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTransferring
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready && !_isTransferring ? _transfer : null,
          child: _isTransferring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Transfer'),
        ),
      ],
    );
  }

  Widget _itemDropdown({
    required String label,
    required String? value,
    required List<InventoryItem> items,
    required ValueChanged<String?> onChanged,
    String? excludeId,
    bool enabled = true,
    bool includeNewItemOption = false,
  }) {
    final options = items.where((i) => i.id != excludeId).toList();
    // Guard against a stale selection (e.g. the excluded item).
    final effectiveValue =
        options.any((i) => i.id == value) ||
            (includeNewItemOption && value == _newItemSentinel)
        ? value
        : null;
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (includeNewItemOption)
          const DropdownMenuItem(
            value: _newItemSentinel,
            child: Text('➕ New item at another location…'),
          ),
        for (final item in options)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.name} (${item.quantity})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
