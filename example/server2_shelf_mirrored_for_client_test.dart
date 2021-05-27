import 'package:jsonrpc2/src/server_base.dart';
import 'package:mirror_dispatcher/mirror_dispatcher.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'rpc_methods.dart';

final port = 8394;

///
/// Test server for test_client.dart. Uses dart:mirrors.
///

class Service {
  /// APIs are in reflected_rpc_methods.dart
  Router get handler {
    final jRpcHeader = {'Content-Type': 'application/json; charset=utf-8'};
    final router = Router();

    router.post('/friend/<friendName>',
        (Request request, String friendName) async {
      var dispatcher = MirrorDispatcher(Friend(friendName));
      var body = await request.readAsString();
      return Response.ok(await jsonRpc(body, dispatcher), headers: jRpcHeader);
    });
    
    router.post('/sum', (Request request) async {
      return Response.ok(
          await jsonRpc(await request.readAsString(),
              MirrorDispatcher(ExampleMethodsClass())),
          headers: jRpcHeader);
    });

    // router.post('/', (Request request) async {
    //   var dispatcher = MirrorDispatcher(ExampleMethodsClass());
    //   var body = await request.readAsString();
    //   return Response.ok(await jsonRpc(body, dispatcher), headers: jRpcHeader);
    // });

    return router;
  }
}

void main() async {
  final service = Service();
  // corsHeaders is needed for chrome client tests
  var handler =
      const Pipeline().addMiddleware(corsHeaders()).addHandler(service.handler);

  final server = await shelf_io.serve(handler, '127.0.0.1', port);
  print('Server running on localhost:${server.port}');
}
