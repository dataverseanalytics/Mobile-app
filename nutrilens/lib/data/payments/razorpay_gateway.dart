import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payments.dart';

/// Razorpay Checkout (UPI, cards, net banking, wallets) on Android/iOS.
class RazorpayGateway implements PaymentGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<PaymentOutcome> checkout(CheckoutOrder order) {
    final done = Completer<PaymentOutcome>();
    final razorpay = Razorpay();

    void finish(PaymentOutcome outcome) {
      if (!done.isCompleted) done.complete(outcome);
      razorpay.clear();
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        final paymentId = r.paymentId;
        final orderId = r.orderId;
        final signature = r.signature;
        if (paymentId == null || orderId == null || signature == null) {
          finish(
            const PaymentFailed(
              'Payment response was incomplete. Please try again.',
            ),
          );
        } else {
          finish(
            PaymentSucceeded(
              paymentId: paymentId,
              orderId: orderId,
              signature: signature,
            ),
          );
        }
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        finish(
          r.code == Razorpay.PAYMENT_CANCELLED
              ? const PaymentCancelled()
              : PaymentFailed(
                  r.code == Razorpay.NETWORK_ERROR
                      ? "You're offline. Check your connection and try again."
                      : 'Payment failed. No money was taken — please try again.',
                ),
        );
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
        // External wallets complete outside the sheet; the webhook confirms.
        finish(
          PaymentFailed(
            'Finish paying in ${r.walletName ?? 'your wallet'}. Pro switches on once it is confirmed.',
          ),
        );
      })
      ..open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountMinor,
        'currency': order.currency,
        'name': order.name,
        'description': order.description,
        'prefill': {'contact': order.contact, 'email': order.email},
        'theme': {'color': '#14140F'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    return done.future;
  }
}

/// Web builds: the Razorpay plugin is mobile-only.
class UnavailableGateway implements PaymentGateway {
  const UnavailableGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<PaymentOutcome> checkout(CheckoutOrder order) async =>
      const PaymentFailed(
        'Payments are available in the NutriLens Android and iOS apps.',
      );
}
