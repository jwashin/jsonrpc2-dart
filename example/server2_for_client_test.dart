import 'dart:convert';
import 'dart:io';

import 'package:jsonrpc2/src/dispatcher.dart';
import 'package:jsonrpc2/src/jsonrpc_service.dart';
import 'package:jsonrpc2/src/mirror_dispatcher.dart';

import 'rpc_methods.dart';

final port = 8394;
///
/// Test server for test_client.dart. Uses HttpServer from dart:io package.
///
void main() async {
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Test Server running at '
      'http://${InternetAddress.loopbackIPv4.address}:$port\n');
  await for (var request in server) {
    var content = await utf8.decoder.bind(request).join();
    // useful for debugging!
    // print(content);
    switch (request.method) {
      case 'OPTIONS':
        setCrossOriginHeaders(request);
        request.response.statusCode = 204;
        await request.response.close();
        break;
      case 'POST':

        //_logger.fine(body.body);
        var pathCheck = request.uri.pathSegments[0];
        Dispatcher dispatcher;
        if (pathCheck == 'friend') {
          var friendName = request.uri.pathSegments[1];
          dispatcher = MirrorDispatcher(Friend(friendName));
        } else {
          dispatcher = MirrorDispatcher(ExampleMethodsClass());
        }

        /// import this function from [jsonrpc2/jsonrpc_service.dart]
        var result = await jsonRpc(content, dispatcher);
        //_logger.fine(result);
        setCrossOriginHeaders(request);
        var response = request.response;
        response.headers.set('Content-Type', 'application/json; charset=UTF-8');
        response.statusCode = 200;
        var out = result;
        // useful debugger!
        // print('${request.method}: $out');
        response.write(out);
        await response.close();
        break;
      default:
      // print(request.method);
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
