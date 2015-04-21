import '../lib/jsonrpc_service.dart';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'dart:convert';
import 'package:start/start.dart';

import 'rpc_methods.dart';

/*
 * Test server. Uses start.dart and works with test_client.dart
 * Run this first.
 */

final _logger = new Logger('test_server');

main() => startServer();


startServer() {
  //Logger.root.level = Level.ALL;
  //Logger.root.onRecord.listen(new LogPrintHandler());

  var server = new TestServer('127.0.0.1', 8394);
  server.startServer();
  print("Test Server running at http://${server.host}:${server.port}");

}


doJsonRpc(Request request, instance) {
  var rq = request.input;
  request.response.type("application/json; charset=UTF-8");
  UTF8.decodeStream(rq).then((requestString) => jsonRpc(requestString, instance)).then((result) => request.response.send(result));
}


class TestServer {
  var server;
  var port = 8394;
  var host = 'localhost';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin = true;

  TestServer(this.host, [this.port]);

  startServer() {


    start(port: port, host: host).then((app) {
      server = app;
      app.static('.');

      app.post('/sum').listen((request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request, new ExampleMethodsClass());
      });

      app.options('/sum').listen((request) {
        Response response = request.response;
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        response.status(204);
        response.send('');
      });

      app.post('/friend/:name').listen((request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request, new Friend(request.param('name')));
      });

      app.options('/friend/:name').listen((request) {
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        Response response = request.response;
        response.status(204);
        response.send('');
      });

    });
  }
  setCrossOriginHeaders(request) {
    Response response = request.response;
    response.set('Access-Control-Allow-Origin', '*');
    response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  }

  //  stopServer() => server.stop();

}
