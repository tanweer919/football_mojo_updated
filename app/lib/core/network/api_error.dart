import 'package:dio/dio.dart';

/// The backend's machine-readable error code for an exception.
///
/// NestJS errors serialise as `{ statusCode, message, error }` where `message`
/// is a String (e.g. `"insufficient_gems"`) or a `List<String>` (validation).
/// Reading the response BODY is far more reliable than `DioException.toString()`,
/// which usually omits the body — so a `.contains('insufficient_gems')` check
/// on the raw exception silently misses and falls through to a generic message.
/// Falls back to the exception string for non-Dio errors.
String apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final m = data['message'] ?? data['error'];
      if (m is String && m.isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
  }
  return error.toString();
}

/// Human-readable message for a gem card/bundle purchase failure. Maps the
/// backend's error codes to clear copy — most importantly a precise
/// "not enough gems" instead of a vague "try again".
String gemPurchaseErrorMessage(Object error) {
  final code = apiErrorCode(error);
  if (code.contains('insufficient_gems')) {
    return 'Not enough gems — earn more, or watch an ad for a free card.';
  }
  if (code.contains('sold_out')) return 'Sold out — that drop is gone.';
  if (code.contains('drop_closed')) return 'This drop has closed.';
  if (code.contains('drop_not_open')) return 'This drop hasn’t opened yet.';
  if (code.contains('per_user_cap')) return 'You’ve reached the limit for this card.';
  if (code.contains('not_purchasable')) return 'This card isn’t for sale.';
  return 'Could not complete the purchase. Please try again.';
}
