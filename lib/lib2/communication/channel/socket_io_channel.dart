import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:socket_io_client/socket_io_client.dart';

import '../../../src/utils/prints.dart';

class SocketIoChannel implements InOutChannel {
  final Socket _socket;
  final _listeners = <String, void Function(dynamic data)>{};

  SocketIoChannel(this._socket) {
    _socket.onAny((event, data) {
      log("SocketIoChannel.listen.on() === event=$event data=$data");
      _listeners[event]?.call(data);
    });
  }

  @override
  void emit(String event, data) {
    log("SocketIoChannel.emit() === event=$event  data=$data");
    _socket.emit(event, data);
  }

  @override
  void listen(String event, void Function(dynamic p1)? onData) {
    log("SocketIoChannel.listen() === event=$event");
    if(onData != null) {
      _listeners[event] = onData;
    } else {
      _listeners.remove(event);
    }
  }
}