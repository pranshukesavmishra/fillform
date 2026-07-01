// Thin dart:js_interop wrapper around Razorpay's Checkout.js widget
// (loaded in web/index.html). Dart 3's js_interop is part of the SDK, no
// pubspec dependency needed.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Razorpay')
extension type _RazorpayConstructor._(JSObject _) implements JSObject {
  external _RazorpayConstructor(JSAny options);
}

/// Opens the Razorpay checkout modal. [onSuccess] fires with
/// (razorpay_payment_id, razorpay_order_id, razorpay_signature) once the
/// user completes payment; [onDismiss] fires if they close the modal
/// without paying.
void openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String currency,
  required String name,
  required String description,
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function() onDismiss,
}) {
  final options = {
    'key': keyId,
    'amount': amountPaise,
    'currency': currency,
    'name': name,
    'description': description,
    'order_id': orderId,
    'handler': (JSObject response) {
      final paymentId = (response.getProperty('razorpay_payment_id'.toJS) as JSString).toDart;
      final rOrderId = (response.getProperty('razorpay_order_id'.toJS) as JSString).toDart;
      final signature = (response.getProperty('razorpay_signature'.toJS) as JSString).toDart;
      onSuccess(paymentId, rOrderId, signature);
    }.toJS,
    'modal': {
      'ondismiss': () {
        onDismiss();
      }.toJS,
    }.jsify(),
  }.jsify();

  final instance = _RazorpayConstructor(options!);
  (instance as JSObject).callMethod('open'.toJS);
}
