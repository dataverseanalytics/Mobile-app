import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrilens/data/api/api_client.dart';
import 'package:nutrilens/data/payments/payments.dart';

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Stands in for the Razorpay sheet.
class FakeGateway implements PaymentGateway {
  FakeGateway(this.outcome);
  final PaymentOutcome outcome;
  CheckoutOrder? opened;

  @override
  bool get isAvailable => true;

  @override
  Future<PaymentOutcome> checkout(CheckoutOrder order) async {
    opened = order;
    return outcome;
  }
}

const yearly = ProPlan(
  id: 'yearly',
  name: 'Pro · 1 year',
  currency: 'INR',
  amountMinor: 249900,
  priceLabel: '₹2,499',
  days: 365,
  perMonthLabel: '₹208',
);

ApiClient server({bool verifyOffline = false, List<String>? calls}) =>
    ApiClient(
      baseUrl: 'http://api',
      tokens: MemoryTokenStore()..access = 't',
      httpClient: MockClient((req) async {
        calls?.add('${req.method} ${req.url.path}');
        switch (req.url.path) {
          case '/v1/payments/order':
            expect(jsonDecode(req.body), {'plan': 'yearly'});
            return json({
              'orderId': 'order_1',
              'keyId': 'rzp_test_key',
              'amountMinor': 249900,
              'currency': 'INR',
              'name': 'NutriLens',
              'description': 'Pro · 1 year',
              'prefillContact': '+919876543210',
              'prefillEmail': '',
            });
          case '/v1/payments/verify':
            if (verifyOffline) throw http.ClientException('offline');
            expect(jsonDecode(req.body), {
              'orderId': 'order_1',
              'paymentId': 'pay_1',
              'signature': 'sig',
            });
            return json({
              'premiumUntil': '2027-11-21T10:00:00Z',
              'isPremium': true,
            });
          case '/v1/payments/plans':
            throw http.ClientException('offline');
        }
        return json({'detail': 'not found'}, 404);
      }),
    );

const success = PaymentSucceeded(
  paymentId: 'pay_1',
  orderId: 'order_1',
  signature: 'sig',
);

void main() {
  test('order → Razorpay → server verification unlocks Pro', () async {
    final calls = <String>[];
    final gateway = FakeGateway(success);
    final repo = PaymentsRepository(
      api: server(calls: calls),
      gateway: gateway,
    );

    final until = await repo.purchase(yearly);

    expect(until?.toUtc(), DateTime.utc(2027, 11, 21, 10));
    expect(gateway.opened?.keyId, 'rzp_test_key');
    expect(
      gateway.opened?.amountMinor,
      249900,
      reason: 'amount comes from the server',
    );
    expect(gateway.opened?.contact, '+919876543210');
    expect(calls, ['POST /v1/payments/order', 'POST /v1/payments/verify']);
  });

  test('closing the payment sheet is a quiet cancel', () async {
    final repo = PaymentsRepository(
      api: server(),
      gateway: FakeGateway(const PaymentCancelled()),
    );
    await expectLater(repo.purchase(yearly), throwsA(isA<PurchaseCancelled>()));
  });

  test('a failed payment explains itself', () async {
    final repo = PaymentsRepository(
      api: server(),
      gateway: FakeGateway(
        const PaymentFailed(
          'Payment failed. No money was taken — please try again.',
        ),
      ),
    );
    await expectLater(
      repo.purchase(yearly),
      throwsA(
        isA<PurchaseFailed>().having(
          (e) => e.message,
          'message',
          contains('No money was taken'),
        ),
      ),
    );
  });

  test(
    'paid but offline: tells the user Pro will follow (webhook covers it)',
    () async {
      final repo = PaymentsRepository(
        api: server(verifyOffline: true),
        gateway: FakeGateway(success),
      );
      await expectLater(
        repo.purchase(yearly),
        throwsA(
          isA<PurchaseFailed>().having(
            (e) => e.message,
            'message',
            startsWith('Payment received'),
          ),
        ),
      );
    },
  );

  test('plans fall back to bundled prices when offline', () async {
    final repo = PaymentsRepository(
      api: server(),
      gateway: FakeGateway(success),
    );
    final plans = await repo.plans();
    expect(plans.map((p) => p.priceLabel), ['₹2,499', '₹699', '₹249']);
  });

  test("plans arrive in the customer's currency", () {
    final usd = ProPlan.fromJson({
      'id': 'yearly',
      'name': 'Pro · 1 year',
      'days': 365,
      'currency': 'USD',
      'amountMinor': 3999,
      'priceLabel': r'$39.99',
      'perMonthLabel': r'$3.33',
    });
    expect(usd.priceLabel, r'$39.99');
    expect(usd.perMonthLabel, r'$3.33');
    expect(usd.supportsUpi, isFalse, reason: 'UPI is INR-only');
    expect(ProPlan.fallback.first.supportsUpi, isTrue);
  });

  test('on-device demo mode needs no server or gateway', () async {
    final repo = PaymentsRepository(
      api: null,
      gateway: FakeGateway(const PaymentCancelled()),
    );
    final until = await repo.purchase(yearly);
    expect(
      until!.difference(DateTime.now()).inDays,
      inInclusiveRange(364, 365),
    );
  });
}
