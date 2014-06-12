import '../lib/jsonrpc_service.dart';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'dart:io';
import 'package:http_server/http_server.dart';
import 'dart:convert';

import 'rpc_methods.dart';


final int port = 8394;

/*
 * Test server for test_client.dart. Uses http_server package. 
 */

final _logger = new Logger('test_server');

main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new LogPrintHandler());

  HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port).then((server) {
    print("Test Server running at http://${InternetAddress.LOOPBACK_IP_V4.address}:${port}\n");
    server.transform(new HttpBodyHandler()).listen((HttpRequestBody body) {
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
          var instance = new ExampleMethodsClass();
          if (pathCheck == 'friend') {
            String friendname = request.uri.pathSegments[1];
            instance = new Friend(friendname);
          }

          jsonRpcExec(body.body, instance).then((result) {
            //_logger.fine(result);
            setCrossOriginHeaders(request);
            HttpResponse response = request.response;
            response.headers.set("Content-Type", "application/json; charset=UTF-8");
            response.statusCode = 200;
            if (result is Notification) {
              response.write('');
            } else {
              response.write(JSON.encode(result));
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
  response.headers.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
}

