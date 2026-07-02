import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/payment_service.dart';

final plansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(paymentServiceProvider).listPlans();
});

final subscriptionStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(paymentServiceProvider).getSubscriptionStatus();
});

final paymentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(paymentServiceProvider).getPaymentHistory();
});

class CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  final PaymentService _service;
  final Ref _ref;

  CheckoutNotifier(this._service, this._ref) : super(const AsyncData(null));

  /// Creates a real Razorpay order. Returns the order data so the UI layer
  /// (which owns the JS-interop checkout call) can open the checkout modal.
  Future<Map<String, dynamic>> createOrderForPlan(Map<String, dynamic> plan) async {
    state = const AsyncLoading();
    try {
      final order = await _service.createOrder(
        amountPaise: plan['price_paise'] as int,
        purpose: 'subscription',
        referenceId: plan['id'] as String,
      );
      state = const AsyncData(null);
      return order;
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }

  Future<void> confirmPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String internalOrderId,
  }) async {
    await _service.verifyPayment(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      internalOrderId: internalOrderId,
    );
    _ref.invalidate(subscriptionStatusProvider);
    _ref.invalidate(paymentHistoryProvider);
  }
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>(
  (ref) => CheckoutNotifier(ref.watch(paymentServiceProvider), ref),
);
