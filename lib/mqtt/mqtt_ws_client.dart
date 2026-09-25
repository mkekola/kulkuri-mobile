import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Minimal MQTT 3.1.1 client over WebSocket - just enough to connect,
// subscribe to one topic, and receive PUBLISH messages.
//
// Written by hand instead of using the `mqtt_client` package: that package's
// own byte parser froze silently (no error, no disconnect) the first time a
// message contained a non-ASCII character (both failures seen were Finnish
// place names with "ä") - a classic byte-length-vs-character-length bug in
// hand-rolled MQTT parsers. Everything below works in raw bytes until the
// final UTF-8 decode of a complete, already-length-known field, so that
// class of bug can't happen here.

class MqttMessage {
  final String topic;
  final Uint8List payload;

  MqttMessage(this.topic, this.payload);
}

class MqttWsClient {
  WebSocket? _socket;
  final _buffer = BytesBuilder();
  final _messagesController = StreamController<MqttMessage>.broadcast();
  Timer? _pingTimer;

  Stream<MqttMessage> get messages => _messagesController.stream;

  Future<void> connect(String url, {required String clientId}) async {
    final socket = await WebSocket.connect(url, protocols: ['mqtt']);
    _socket = socket;
    socket.listen(_onSocketData, onDone: _onSocketDone, onError: _onSocketError);

    socket.add(_buildConnectPacket(clientId));

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _socket?.add(Uint8List.fromList([0xc0, 0x00])); // PINGREQ
    });
  }

  void subscribe(String topic) {
    _socket?.add(_buildSubscribePacket(topic));
  }

  void dispose() {
    _pingTimer?.cancel();
    _socket?.close();
  }

  void _onSocketDone() {
    _messagesController.addError(StateError('MQTT WebSocket closed'));
  }

  void _onSocketError(Object error) {
    _messagesController.addError(error);
  }

  void _onSocketData(dynamic data) {
    final bytes = data is String ? utf8.encode(data) : data as List<int>;
    _buffer.add(bytes);
    _drainBuffer();
  }

  // Parses as many complete MQTT packets as are currently buffered, leaving
  // any trailing partial packet for the next data event.
  void _drainBuffer() {
    var bytes = _buffer.toBytes();

    while (true) {
      if (bytes.length < 2) break;

      final packetType = bytes[0] >> 4;
      final flags = bytes[0] & 0x0f;

      var multiplier = 1;
      var remainingLength = 0;
      var index = 1;
      var lengthComplete = false;
      while (index <= 4 && index < bytes.length) {
        final encodedByte = bytes[index];
        remainingLength += (encodedByte & 127) * multiplier;
        multiplier *= 128;
        index++;
        if ((encodedByte & 128) == 0) {
          lengthComplete = true;
          break;
        }
      }
      if (!lengthComplete) break; // Need more bytes to even know the length.

      final headerLength = index;
      final totalLength = headerLength + remainingLength;
      if (bytes.length < totalLength) break; // Full packet not buffered yet.

      final packetBody = bytes.sublist(headerLength, totalLength);
      _handlePacket(packetType, flags, packetBody);

      bytes = bytes.sublist(totalLength);
    }

    _buffer.clear();
    if (bytes.isNotEmpty) _buffer.add(bytes);
  }

  void _handlePacket(int packetType, int flags, Uint8List body) {
    const publish = 3;
    if (packetType != publish) return; // CONNACK/SUBACK/PINGRESP: nothing to do for our use case.

    final qos = (flags >> 1) & 0x03;
    var offset = 0;

    final topicLength = (body[offset] << 8) | body[offset + 1];
    offset += 2;
    final topic = utf8.decode(body.sublist(offset, offset + topicLength));
    offset += topicLength;

    if (qos > 0) offset += 2; // Packet identifier, unused (we only publish/subscribe at QoS 0).

    final payload = body.sublist(offset);
    _messagesController.add(MqttMessage(topic, payload));
  }

  List<int> _buildConnectPacket(String clientId) {
    final variableHeader = <int>[
      ..._encodedString('MQTT'),
      0x04, // Protocol level: MQTT 3.1.1
      0x02, // Connect flags: clean session
      0x00, 0x3c, // Keep alive: 60s
    ];
    final payload = _encodedString(clientId);
    return _packet(0x10, [...variableHeader, ...payload]);
  }

  List<int> _buildSubscribePacket(String topic) {
    final variableHeader = [0x00, 0x01]; // Packet identifier
    final payload = [..._encodedString(topic), 0x00]; // Requested QoS 0
    // Reserved bits for SUBSCRIBE must be 0010 per the spec.
    return _packet(0x82, [...variableHeader, ...payload]);
  }

  List<int> _packet(int fixedHeaderByte1, List<int> rest) {
    return [fixedHeaderByte1, ..._encodeRemainingLength(rest.length), ...rest];
  }

  List<int> _encodedString(String value) {
    final bytes = utf8.encode(value);
    return [bytes.length >> 8, bytes.length & 0xff, ...bytes];
  }

  List<int> _encodeRemainingLength(int length) {
    final bytes = <int>[];
    var remaining = length;
    do {
      var encodedByte = remaining % 128;
      remaining ~/= 128;
      if (remaining > 0) encodedByte |= 128;
      bytes.add(encodedByte);
    } while (remaining > 0);
    return bytes;
  }
}
