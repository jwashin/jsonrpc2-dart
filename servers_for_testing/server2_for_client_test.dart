import 'dart:io';
import 'dart:convert';
import 'package:jsonrpc2/jsonrpc_service.dart';
import 'package:jsonrpc2/src/rpc_methods.dart';

final int port = 8394;

/*
 * Test server for test_client.dart. Uses HttpServer from dart:io package.
 */

//final _logger = new Logger('test_server');

Future main() async {
//  Logger.root.level = Level.ALL;
//  Logger.root.onRecord.listen(new LogPrintHandler());

  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Test Server running at '
      'http://${InternetAddress.loopbackIPv4.address}:${port}\n');
  await for (var request in server) {
    var content = await utf8.decoder.bind(request).join();

    switch (request.method) {
      case 'OPTIONS':
        setCrossOriginHeaders(request);
        request.response.statusCode = 204;
        await request.response.close();
        break;
      case 'POST':
        //_logger.fine(body.body);
        var pathCheck = request.uri.pathSegments[0];
        dynamic instance;
        if (pathCheck == 'friend') {
          var friendName = request.uri.pathSegments[1];
          instance = Friend(friendName);
        } else {
          instance = ExampleMethodsClass();
        }

        /// import this function from [jsonrpc2/jsonrpc_service.dart]
        jsonRpcExec(content, instance).then((result) {
          //_logger.fine(result);
          setCrossOriginHeaders(request);
          var response = request.response;
          response.headers
              .set('Content-Type', 'application/json; charset=UTF-8');
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
  }
  ;
}

void setCrossOriginHeaders(request) {
  HttpResponse response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept');
}
