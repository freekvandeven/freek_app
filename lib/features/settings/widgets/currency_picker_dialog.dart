import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Codes the app supports for the user's preferred display currency.
/// Internal prices are always stored in EUR.
const currencyOptions = {
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'CHF': 'Fr',
  'CNY': '¥',
  'JPY': '¥',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'SEK': 'kr',
  'NOK': 'kr',
  'DKK': 'kr',
  'PLN': 'zł',
  'CZK': 'Kč',
};

String currencySymbol(String code) => currencyOptions[code] ?? code;

/// Dialog that shows available currencies with live EUR conversion rates
/// fetched from the Frankfurter API (ECB exchange rates, no API key needed).
class CurrencyPickerDialog extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelected;

  const CurrencyPickerDialog({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  State<CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<CurrencyPickerDialog> {
  Map<String, double>? _rates;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final codes = currencyOptions.keys.where((c) => c != 'EUR').join(',');
      final response = await http.get(
        Uri.parse(
          'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=$codes',
        ),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = (body['rates'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
        if (mounted) setState(() => _rates = rates);
      }
    } catch (_) {
      // Rates are informational — silently ignore failures
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Default Currency'),
      children: [
        for (final entry in currencyOptions.entries)
          ListTile(
            leading: SizedBox(
              width: 36,
              child: Text(
                entry.value,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            title: Text(entry.key),
            subtitle: _rateSubtitle(entry.key),
            trailing: widget.current == entry.key
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              widget.onSelected(entry.key);
              Navigator.pop(context);
            },
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget? _rateSubtitle(String code) {
    if (code == 'EUR') return const Text('Base currency');
    if (_rates == null) return null;
    final rate = _rates![code];
    if (rate == null) return null;
    return Text('1 EUR = ${rate.toStringAsFixed(rate < 10 ? 4 : 2)} $code');
  }
}
