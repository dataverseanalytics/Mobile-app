import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'razorpay_gateway.dart';

/// A Pro pass, priced for the customer's country by the server
/// (`/v1/payments/plans`), in their local currency.
@immutable
class ProPlan {
  const ProPlan({
    required this.id,
    required this.name,
    required this.currency,
    required this.amountMinor,
    required this.priceLabel,
    required this.days,
    this.perMonthLabel,
  });

  final String id;
  final String name;
  final String currency;

  /// In the currency's minor unit (paise, cents, pence…).
  final int amountMinor;
  final String priceLabel;
  final int days;

  /// Yearly only, e.g. "₹208".
  final String? perMonthLabel;

  /// UPI and net banking exist only for rupee payments.
  bool get supportsUpi => currency == 'INR';

  String get label => switch (id) {
    'yearly' => 'Yearly',
    'monthly' => 'Monthly',
    'weekly' => 'Weekly',
    _ => name,
  };

  String get period => switch (days) {
    365 => '1 year',
    30 => '1 month',
    7 => '1 week',
    _ => '$days days',
  };

  /// On-device demo mode / server unreachable (same as the backend's India tier).
  static const fallback = [
    ProPlan(
      id: 'yearly',
      name: 'Pro · 1 year',
      currency: 'INR',
      amountMinor: 249900,
      priceLabel: '₹2,499',
      days: 365,
      perMonthLabel: '₹208',
    ),
    ProPlan(
      id: 'monthly',
      name: 'Pro · 1 month',
      currency: 'INR',
      amountMinor: 69900,
      priceLabel: '₹699',
      days: 30,
    ),
    ProPlan(
      id: 'weekly',
      name: 'Pro · 1 week',
      currency: 'INR',
      amountMinor: 24900,
      priceLabel: '₹249',
      days: 7,
    ),
  ];

  static ProPlan fromJson(Map<String, Object?> j) => ProPlan(
    id: j['id']! as String,
    name: j['name']! as String,
    currency: j['currency']! as String,
    amountMinor: (j['amountMinor']! as num).toInt(),
    priceLabel: j['priceLabel']! as String,
    days: (j['days']! as num).toInt(),
    perMonthLabel: j['perMonthLabel'] as String?,
  );
}

/// Order created by our server; everything Razorpay Checkout needs.
@immutable
class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.keyId,
    required this.amountMinor,
    required this.currency,
    required this.name,
    required this.description,
    required this.contact,
    required this.email,
  });

  final String orderId;
  final String keyId;
  final int amountMinor;
  final String currency;
  final String name;
  final String description;
  final String contact;
  final String email;

  static CheckoutOrder fromJson(Map<String, Object?> j) => CheckoutOrder(
    orderId: j['orderId']! as String,
    keyId: j['keyId']! as String,
    amountMinor: (j['amountMinor']! as num).toInt(),
    currency: j['currency']! as String,
    name: j['name']! as String,
    description: j['description']! as String,
    contact: j['prefillContact'] as String? ?? '',
    email: j['prefillEmail'] as String? ?? '',
  );
}

sealed class PaymentOutcome {
  const PaymentOutcome();
}

final class PaymentSucceeded extends PaymentOutcome {
  const PaymentSucceeded({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
  final String paymentId;
  final String orderId;
  final String signature;
}

final class PaymentCancelled extends PaymentOutcome {
  const PaymentCancelled();
}

final class PaymentFailed extends PaymentOutcome {
  const PaymentFailed(this.message);
  final String message;
}

/// Opens the payment sheet. Razorpay on mobile; fakes in tests.
abstract interface class PaymentGateway {
  bool get isAvailable;
  Future<PaymentOutcome> checkout(CheckoutOrder order);
}

/// The user closed the payment sheet — not an error.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

class PurchaseFailed implements Exception {
  const PurchaseFailed(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Buy Pro: server creates the order (it decides the price), Razorpay
/// takes the payment, server verifies the signature and turns Pro on.
class PaymentsRepository {
  PaymentsRepository({required this.api, required this.gateway});

  final ApiClient? api;
  final PaymentGateway gateway;

  Future<List<ProPlan>> plans() async {
    final client = api;
    if (client == null) return ProPlan.fallback;
    try {
      final list = (await client.get('/v1/payments/plans')).asList;
      final plans = [for (final p in list) ProPlan.fromJson(p.asMap)];
      return plans.isEmpty ? ProPlan.fallback : plans;
    } on ApiException {
      return ProPlan.fallback;
    }
  }

  /// Returns the new Pro end date. Throws [PurchaseCancelled] or
  /// [PurchaseFailed].
  Future<DateTime?> purchase(ProPlan plan) async {
    final client = api;
    if (client == null) {
      // On-device demo mode: no money moves.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      return DateTime.now().add(Duration(days: plan.days));
    }

    final CheckoutOrder order;
    try {
      order = CheckoutOrder.fromJson(
        (await client.post('/v1/payments/order', {'plan': plan.id})).asMap,
      );
    } on ApiException catch (e) {
      if (e.status == 503 && kDebugMode) {
        // Razorpay keys not configured on a development server.
        return _parseUntil(await client.post('/v1/subscription/demo-activate'));
      }
      throw PurchaseFailed(e.message);
    }

    if (!gateway.isAvailable) {
      throw const PurchaseFailed(
        'Payments are available in the NutriLens Android and iOS apps.',
      );
    }

    final outcome = await gateway.checkout(order);
    switch (outcome) {
      case PaymentCancelled():
        throw const PurchaseCancelled();
      case PaymentFailed(:final message):
        throw PurchaseFailed(message);
      case PaymentSucceeded(:final paymentId, :final orderId, :final signature):
        try {
          final user = await client.post('/v1/payments/verify', {
            'orderId': orderId,
            'paymentId': paymentId,
            'signature': signature,
          });
          return _parseUntil(user);
        } on ApiException catch (e) {
          // The money is safe: the Razorpay webhook activates Pro even if
          // this call fails. Tell the user honestly.
          throw PurchaseFailed(
            e.isNetwork
                ? 'Payment received. Pro will switch on as soon as you are back online.'
                : 'Payment received but we couldn\'t confirm it yet. '
                      'Pro will switch on shortly — contact support if it doesn\'t.',
          );
        }
    }
  }

  DateTime? _parseUntil(Object? user) {
    final raw = user.asMap['premiumUntil'];
    return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
  }
}

PaymentGateway defaultPaymentGateway() =>
    kIsWeb ? const UnavailableGateway() : RazorpayGateway();
