import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:start/start.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';

import 'rpc_methods.dart';

/*
 * Test server. Uses start.dart and works with test_client.dart
 * Run this first.
 */

final Logger _logger = new Logger('test_server');

void main() => startServer();

void startServer() {
  //Logger.root.level = Level.ALL;
  //Logger.root.onRecord.listen(new LogPrintHandler());

  TestServer server = new TestServer('127.0.0.1', 8394);
  server.startServer();
  print("Test Server running at http://${server.host}:${server.port}");
}

void doJsonRpc(Request request, dynamic instance) {
  request.response.type("application/json; charset=UTF-8");
  UTF8
      .decodeStream(request.input)
      .then((String requestString) => jsonRpc(requestString, instance))
      .then((String result) => request.response.send(result));
}

class TestServer {
  Server server;
  num port = 8394;
  String host = 'localhost';
  String jsonRpcVersion = '2.0';
  bool allowCrossOrigin = true;

  TestServer(this.host, [this.port]);

  void startServer() {
    start(port: port, host: host).then((Server app) {
      server = app;
      app.static('.');

      app.post('/sum').listen((Request request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request, new ExampleMethodsClass());
      });

      app.options('/sum').listen((Request request) {
        Response response = request.response;
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        response.status(204);
        response.send('');
      });

      app.post('/friend/:name').listen((Request request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request, new Friend(request.param('name')));
      });

      app.options('/friend/:name').listen((Request request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        Response response = request.response;
        response.status(204);
        response.send('');
      });
    });
  }

  void setCrossOriginHeaders(Request request) {
    Response response = request.response;
    response.set('Access-Control-Allow-Origin', '*');
    response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.set("Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept");
  }

  //  stopServer() => server.stop();

}
