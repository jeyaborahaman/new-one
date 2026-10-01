import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/network/socket_service.dart';

void main() {
  late SocketService s;
  late String? token;
  late int refreshes;
  late bool refreshOk;

  setUp(() {
    token = 'access-1'; refreshes = 0; refreshOk = true;
    s = SocketService()
      ..connect(() => token, refresh: () async { refreshes++; token = 'access-2'; return refreshOk; })
      ..disconnect(); // no server in tests: keep the configuration, drop the live socket
  });

  test('handshake reads the current token on every connect, not the one from sign-in', () {
    expect(s.authPayload(), {'token': 'access-1'});
    token = 'rotated';
    expect(s.authPayload(), {'token': 'rotated'});
    token = null;
    expect(s.authPayload(), {'token': ''});
  });

  test('an unauthorized handshake refreshes the tokens once, then reconnects with the new token', () async {
    var reconnects = 0;
    await s.handleConnectError({'message': 'unauthorized'}, reconnect: () => reconnects++);
    expect(refreshes, 1); expect(reconnects, 1);
    expect(s.authPayload(), {'token': 'access-2'});
    // A second rejection in a row does not loop; the next successful connect re-arms the retry.
    await s.handleConnectError({'message': 'unauthorized'}, reconnect: () => reconnects++);
    expect(refreshes, 1); expect(reconnects, 1);
  });

  test('network errors are left to built-in reconnection; a failed refresh does not reconnect', () async {
    var reconnects = 0;
    await s.handleConnectError('websocket error', reconnect: () => reconnects++);
    await s.handleConnectError({'message': 'xhr poll error'}, reconnect: () => reconnects++);
    expect(refreshes, 0); expect(reconnects, 0);
    refreshOk = false;
    await s.handleConnectError({'message': 'unauthorized'}, reconnect: () => reconnects++);
    expect(refreshes, 1); expect(reconnects, 0); // signed out: stay disconnected
  });
}
