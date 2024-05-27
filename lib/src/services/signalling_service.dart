import 'dart:developer';
import 'package:cob_duplication_flutter_webrtc/src/utils/prints.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SignallingService {
  // instance of Socket
  Socket? socket;

  final _eventListeners = <String, void Function(dynamic)?>{};

  SignallingService._();
  static final instance = SignallingService._();

  void on(String event, void Function(dynamic)? listener) {
    _eventListeners[event] = listener;
    socket?.on(event, (data) => listener?.call(data));
  }

  void emit(String event, data) {
    socket?.emit(event, data);
  }

  init({
    required String websocketUrl,
    required String selfCallerID,
    void Function(dynamic)? onConnect,
    void Function(dynamic)? onConnectError,
    void Function(dynamic)? onDisConnect,
  }) {
    socket?.dispose();

    // init Socket
    socket = io(websocketUrl, {
      "transports": ['websocket'],
      "query": {"callerId": selfCallerID}
    });

    // listen onConnect event
    socket!.onConnect((data) {
      log("Socket connected !!");
      printFromSocket("onConnect", data);
      onConnect?.call(data);
    });

    // listen onConnectError event
    socket!.onConnectError((data) {
      log("Connect Error $data");
      printFromSocket("onConnectError", data);
      onConnectError?.call(data);
    });

    socket!.onDisconnect((data) {
      log("Socket disconnected !");
      onDisConnect?.call(data);
    });

    _eventListeners.forEach((event, listener) {
      socket!.on(event, (data) => listener?.call(data));
    });

    // connect channel
    socket!.connect();
  }
}