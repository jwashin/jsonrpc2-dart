import 'package:jsonrpc2/src/server_base.dart';
import 'package:reflectable/reflectable.dart';
import 'package:reflector_dispatcher/reflector_dispatcher.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'reflected_rpc_methods.dart';

// 'server2_shelf_reflected_for_client_test.reflectable.dart' is generated
// > flutter pub run build_runner build test
// Sometimes, you need to do the above with --delete-conflicting-outputs
import 'server2_shelf_reflected_for_client_test.reflectable.dart';

final port = 8394;

/// reflectable boilerplate
class Reflector extends Reflectable {
  const Reflector()
      : super(
            invokingCapability, // Request the capability to invoke methods.
            declarationsCapability); // needed for introspecting methods.
}

const reflectable = Reflector();

///
/// Test server for test_client.dart. Uses shelf_router and reflectable.
///

class Service {
  /// APIs are in reflected_rpc_methods.dart
  Router get handler {
    final jRpcHeader = {'Content-Type': 'application/json; charset=utf-8'};
    final router = Router();

    router.post('/friend/<friendName>',
        (Request request, String friendName) async {
      var dispatcher =
          ReflectorDispatcher(Friend(friendName), friendReflectable);
      var body = await request.readAsString();
      return Response.ok(await jsonRpc(body, dispatcher), headers: jRpcHeader);
    });

    router.post('/sum', (Request request) async {
      return Response.ok(
          await jsonRpc(await request.readAsString(),
              ReflectorDispatcher(ExampleMethodsClass(), myReflectable)),
          headers: jRpcHeader);
    });

    // router.post('/', (Request request) async {
    //   var dispatcher =
    //       ReflectorDispatcher(ExampleMethodsClass(), myReflectable);
    //   var body = await request.readAsString();
    //   return Response.ok(await jsonRpc(body, dispatcher), headers: jRpcHeader);
    // });

    return router;
  }
}

void main() async {
  initializeReflectable();
  final service = Service();
  // corsHeaders is needed for chrome client tests
  var handler =
      const Pipeline().addMiddleware(corsHeaders()).addHandler(service.handler);

  final server = await shelf_io.serve(handler, '127.0.0.1', port);
  print('Server running on localhost:${server.port}');
}
