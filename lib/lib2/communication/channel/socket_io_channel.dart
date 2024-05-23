import 'dart:developer';

import 'package:cob_duplication_flutter_webrtc/lib2/communication/channel/channels.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SocketIoChannel implements InOutChannel {
  final Socket _socket;

  SocketIoChannel(this._socket);

  @override
  void emit(String event, data) {
    log("SocketIoChannel.emit() === event=$event  data=$data");
    _socket.emit(event, data);
  }

  @override
  void listen(String event, void Function(dynamic p1)? onData) {
    log("SocketIoChannel.listen() === event=$event");
    _socket.on(event, (data) {
      log("SocketIoChannel.listen() === event=$event data=$data");
      onData?.call(data);
    });
  }
}