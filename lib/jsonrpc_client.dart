library jsonrpc_client;

import "dart:convert";
import "dart:async";
import "dart:html";
import "client_base.dart";

/// basic usage:
///     import "package:jsonrpc2/jsonrpc_client.dart"
///     String url = "http://somelocation";
///     ServerProxy proxy = ServerProxy(url);
///     Future response = await proxy.call("someServerMethod", [arg1, arg2 ]);
///     try{
///         proxy.checkError(response);
///     }catch(e){
///         //do error handling with error e...
///         }
///     print("$response");
///
///  Each arg must be representable in json.
///
///  Exceptions on the remote end will throw RpcException.
class ServerProxy extends ServerProxyBase {
  /// constructor. Superize properly
  ServerProxy(String url) : super(url);

  /// As a descendant class of ServerProxyBase, we override executeRequest.
  ///
  ///
  Future<Map<String, dynamic>> executeRequest(JsonRpcMethod package) async {
    //return a future with the JSON-RPC response
    HttpRequest request = HttpRequest();
    String p;
    try {
      p = json.encode(package);
    } catch (e) {
      throw UnsupportedError(
          'Item (${package}) could not be serialized to JSON');
    }
    request
      ..open('POST', url)
      ..setRequestHeader('Content-Type', 'application/json; charset=UTF-8')
      ..send(p);

    await request.onLoadEnd.first;

    String body = request.responseText;
    return Future(() {
      if (request.status == 204 || body.isEmpty) {
        return null;
      } else {
        return json.decode(body);
      }
    });
  }

  /// I really don't know what to do here. I'll accept suggestions
  handleError(e) {
    print('$e');
  }
}

/// see the documentation in [BatchServerProxyBase]
class BatchServerProxy extends BatchServerProxyBase {
  dynamic proxy;

  /// constructor
  BatchServerProxy(String url) {
    proxy = ServerProxy(url);
  }
}
