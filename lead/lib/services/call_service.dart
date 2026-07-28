import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class CallService {
  Function(String)? onAddLeadRequest;
  StreamSubscription? _subscription;

  Future<void> init() async {
    // Request permissions
    await [
      Permission.phone,
      Permission.contacts, // Sometimes needed for number identification
    ].request();

    _subscription = PhoneState.stream.listen((event) {
      if (event.status == PhoneStateStatus.CALL_INCOMING ||
          event.status == PhoneStateStatus.CALL_STARTED) {
        if (event.number != null && event.number!.isNotEmpty) {
          onAddLeadRequest?.call(event.number!);
        }
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
