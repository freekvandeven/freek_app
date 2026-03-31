import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../auth/providers/auth_providers.dart';

const currencySymbols = <String, String>{
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

class CurrencyConverter {
  final String currency;
  final String symbol;
  final Map<String, double> _rates;
  late final NumberFormat _format;

  CurrencyConverter({
    required this.currency,
    required this.symbol,
    required Map<String, double> rates,
  }) : _rates = rates,
       _format = NumberFormat.currency(symbol: '$symbol ', decimalDigits: 2);

  String format(double eurAmount) => _format.format(fromEur(eurAmount));

  double fromEur(double eurAmount) {
    if (currency == 'EUR') return eurAmount;
    return eurAmount * (_rates[currency] ?? 1.0);
  }

  double toEur(double amount) {
    if (currency == 'EUR') return amount;
    return amount / (_rates[currency] ?? 1.0);
  }
}

final _exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final uri = Uri.parse('https://api.frankfurter.dev/v1/latest?base=EUR');
  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final rates = (data['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      rates['EUR'] = 1.0;
      return rates;
    }
  } catch (_) {
    // Network error — fall back to EUR-only
  }
  return {'EUR': 1.0};
});

final userCurrencyProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.settings.defaultCurrency ?? 'EUR';
});

final currencyConverterProvider = Provider<CurrencyConverter>((ref) {
  final currency = ref.watch(userCurrencyProvider);
  final rates = ref.watch(_exchangeRatesProvider).valueOrNull;

  if (rates != null && (currency == 'EUR' || rates.containsKey(currency))) {
    return CurrencyConverter(
      currency: currency,
      symbol: currencySymbols[currency] ?? currency,
      rates: rates,
    );
  }

  return CurrencyConverter(currency: 'EUR', symbol: '€', rates: {'EUR': 1.0});
});
