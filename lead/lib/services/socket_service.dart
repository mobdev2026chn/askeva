import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  // Use production backend by default, update for local development if needed
  final String _socketUrl = 'https://socket.askeva.net';

  IO.Socket? get socket => _socket;

  bool get connected => _socket?.connected ?? false;

  void init() async {
    if (_socket != null) return;

    final roomId = await AuthService.getRoomId();
    if (roomId == null) {
      debugPrint('SocketService: No roomId found, cannot connect.');
      return;
    }

    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('SocketService: Connected to $_socketUrl');
      _joinRoom(roomId);
    });

    _socket!.onDisconnect((_) {
      debugPrint('SocketService: Disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('SocketService: Connection Error: $err');
      debugPrint(
        'SocketService: Note - Socket server may not be available in local development',
      );
      // Don't retry if it's a local development environment issue
      _socket?.disconnect();
    });

    _socket!.connect();
  }

  void _joinRoom(String roomId) {
    debugPrint('SocketService: Joining room: $roomId');
    _socket!.emit('joinRoom', {
      'roomId': roomId,
      // React frontend also sends userType and isAgent sometimes, but joinRoom usually only needs roomId
    });
  }

  void leaveRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      debugPrint('SocketService: Leaving room: $roomId');
      _socket!.emit('leaveRoom', {'roomId': roomId});
    }
  }

  void onMessage(Function(dynamic) handler) {
    _socket?.on('message', handler);
  }

  void offMessage() {
    _socket?.off('message');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
