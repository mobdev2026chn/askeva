import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

/// Wallet top-up against apiv2.askeva.io/v1/payments/* — mirrors the
/// my.askeva.io AddFundModal exactly (online gateway + bank challan).
class PaymentsRepository {
  final ApiClient client;
  final Session session;
  PaymentsRepository(this.client, this.session);

  /// POST /v1/payments/addWallet { amount } -> the gateway HTML page (a form
  /// that auto-submits to the PG). The web opens this in a popup; the app
  /// renders it in a WebView. [amount] is the grand total (amount + charges).
  Future<String> addWallet(num amount) =>
      client.postText('/payments/addWallet', body: {'amount': amount});

  /// POST /v1/filehandler/upload/chat (multipart 'file') -> uploaded fileUrl.
  Future<String?> uploadChallanFile(List<int> bytes, String filename) async {
    final res = await client.uploadFile('/filehandler/upload/chat', field: 'file', bytes: bytes, filename: filename);
    if (res is Map) {
      final url = res['fileUrl'] ?? res['url'] ?? (res['data'] is Map ? res['data']['fileUrl'] : null);
      return url?.toString();
    }
    return null;
  }

  /// POST /v1/users/paywallet — buy / renew a plan from the wallet balance.
  /// Returns the server result (e.g. { success, message }).
  Future<Map<String, dynamic>> payWithWallet({
    required String planName,
    required num price,
    required String billingPeriod,
    bool upgradeFromExpiry = false,
    bool isSamePlan = false,
  }) async {
    final res = await client.post('/users/paywallet', body: {
      'planName': planName,
      'price': price,
      'billingPeriod': billingPeriod,
      'upgradeFromExpiry': upgradeFromExpiry,
      'isSamePlan': isSamePlan,
    });
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// POST /v1/users/pay-online — returns the PayU gateway HTML (payment_post
  /// form) to render/open, mirroring the web RateLimitModal online flow.
  Future<String> payOnline({
    required String planName,
    required num price,
    required String billingPeriod,
    required num gatewayCharges,
    required num gstAmount,
    required num displayGst,
    required num totalWithGst,
    bool upgradeFromExpiry = false,
    bool isSamePlan = false,
  }) {
    return client.postText('/users/pay-online', body: {
      'planName': planName,
      'price': price,
      'billingPeriod': billingPeriod,
      'upgradeFromExpiry': upgradeFromExpiry,
      'isSamePlan': isSamePlan,
      'gatewayCharges': gatewayCharges,
      'gstAmount': gstAmount,
      'displayGst': displayGst,
      'totalWithGst': totalWithGst,
    });
  }

  /// POST /v1/payments/upload-challan — submit a bank transfer for approval.
  /// Field shapes match the web uploadChallan payload exactly.
  Future<void> uploadChallan({
    required String paymentMode,
    required String challanDate,
    required String challanFile,
    required String referenceNum,
    required String accountNumber,
    required num gstAmount,
    required num totalAmountPaid,
    required num addedAmount,
  }) async {
    await client.post('/payments/upload-challan', body: {
      'paymentMode': paymentMode,
      'paymentMethod': 'bank',
      'challanDate': challanDate,
      'challanFile': challanFile,
      'referenceNum': referenceNum,
      'accountNumber': accountNumber,
      'gstAmount': gstAmount,
      'totalAmountPaid': totalAmountPaid,
      'addedAmount': addedAmount,
    });
  }

  /// GET /v1/payments/get-wallet-transactions  (matches web PaymentsApis.js exactly)
  Future<List<PaymentTransactionDto>> fetchTransactions() async {
    final res = await client.get('/payments/get-wallet-transactions');
    if (res is List) {
      return res.whereType<Map>().map((m) => PaymentTransactionDto.fromJson(m.cast<String, dynamic>())).toList();
    }
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).whereType<Map>().map((m) => PaymentTransactionDto.fromJson(m.cast<String, dynamic>())).toList();
    }
    return const [];
  }

  /// GET /v1/whatsapp-pays/transactions
  Future<List<PaymentTransactionDto>> fetchAppointmentTransactions() async {
    final res = await client.get('/whatsapp-pays/transactions');
    final List<dynamic> list;
    if (res is Map && res['data'] is List) {
      list = res['data'];
    } else if (res is List) {
      list = res;
    } else {
      list = const [];
    }
    return list
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .where((m) => m['type'] == 'appointment')
        .map(PaymentTransactionDto.fromJson)
        .toList();
  }

  /// POST /v1/whatsapp-pays/notifyPayment
  Future<void> notifyPayment(Map<String, dynamic> payload) async {
    await client.post('/whatsapp-pays/notifyPayment', body: payload);
  }
}
