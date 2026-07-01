import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class PaymentService {
  final Dio _dio;
  PaymentService(this._dio);

  Future<List<Map<String, dynamic>>> listPlans() async {
    final resp = await _dio.get('/api/v1/payments/plans');
    return (resp.data['plans'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final resp = await _dio.get('/api/v1/payments/subscription/status');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final resp = await _dio.get('/api/v1/payments/history');
    return (resp.data['payments'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrder({
    required int amountPaise,
    required String purpose,
    String? referenceId,
  }) async {
    final resp = await _dio.post('/api/v1/payments/order/create', data: {
      'amount_paise': amountPaise,
      'currency': 'INR',
      'purpose': purpose,
      if (referenceId != null) 'reference_id': referenceId,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String internalOrderId,
  }) async {
    final resp = await _dio.post('/api/v1/payments/verify', data: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'internal_order_id': internalOrderId,
    });
    return resp.data as Map<String, dynamic>;
  }
}

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(ref.watch(dioProvider)),
);
