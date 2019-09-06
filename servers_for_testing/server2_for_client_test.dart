import 'dart:io';
import 'dart:convert';

// import 'package:logging/logging.dart';
import 'package:http_server/http_server.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';

import 'package:jsonrpc2/src/rpc_methods.dart';

final int port = 8394;

/*
 * Test server for test_client.dart. Uses http_server package.
 */

//final _logger = new Logger('test_server');

main() {
//  Logger.root.level = Level.ALL;
//  Logger.root.onRecord.listen(new LogPrintHandler());

  HttpServer.bind(InternetAddress.loopbackIPv4, port).then((server) {
    print(
        "Test Server running at http://${InternetAddress.loopbackIPv4.address}:${port}\n");
    server.transform(HttpBodyHandler()).listen((HttpRequestBody body) {
      HttpRequest request = body.request;
      switch (request.method) {
        case 'OPTIONS':
          setCrossOriginHeaders(request);
          request.response.statusCode = 204;
          request.response.close();
          break;
        case 'POST':
          //_logger.fine(body.body);
          String pathCheck = request.uri.pathSegments[0];
          dynamic instance;
          if (pathCheck == 'friend') {
            String friendName = request.uri.pathSegments[1];
            instance = Friend(friendName);
          } else {
            instance = ExampleMethodsClass();
          }
          /// import this function from [jsonrpc2/jsonrpc_service.dart]
          jsonRpcExec(body.body, instance).then((result) {
            //_logger.fine(result);
            setCrossOriginHeaders(request);
            HttpResponse response = request.response;
            response.headers
                .set("Content-Type", "application/json; charset=UTF-8");
            response.statusCode = 200;
            if (result is Notification) {
              response.write('');
            } else {
              response.write(json.encode(result));
            }
            response.close();
          });
          break;
        default:
          print(request.method);
      }
    });
  });
}

setCrossOriginHeaders(request) {
  HttpResponse response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.headers.set("Access-Control-Allow-Headers",
      "Origin, X-Requested-With, Content-Type, Accept");
}
