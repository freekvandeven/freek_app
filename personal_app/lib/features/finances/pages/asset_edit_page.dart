import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

class AssetEditPage extends ConsumerStatefulWidget {
  final String? assetId;
  const AssetEditPage({super.key, this.assetId});

  @override
  ConsumerState<AssetEditPage> createState() => _AssetEditPageState();
}

class _AssetEditPageState extends ConsumerState<AssetEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  AssetType _type = AssetType.bankAccount;
  String _currency = 'EUR';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.assetId != null) {
      _loadAsset();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadAsset() async {
    final asset = await ref
        .read(financeServiceProvider)
        .getAsset(widget.assetId!);
    if (asset != null && mounted) {
      setState(() {
        _nameController.text = asset.name;
        _valueController.text = asset.currentValue.toStringAsFixed(2);
        _descriptionController.text = asset.description ?? '';
        _type = asset.type;
        _currency = asset.currency;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final asset = FinancialAsset(
      id: widget.assetId,
      name: _nameController.text.trim(),
      type: _type,
      currentValue: double.parse(_valueController.text.trim()),
      currency: _currency,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    final notifier = ref.read(assetListProvider.notifier);
    if (widget.assetId != null) {
      await notifier.updateAsset(asset);
    } else {
      await notifier.addAsset(asset);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.assetId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Asset' : 'New Asset')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Asset' : 'New Asset'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<AssetType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: AssetType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t.name[0].toUpperCase() + t.name.substring(1),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Current Value',
                border: OutlineInputBorder(),
                prefixText: '\u20AC ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'EUR', child: Text('EUR (\u20AC)')),
                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP (\u00A3)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _currency = v);
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
