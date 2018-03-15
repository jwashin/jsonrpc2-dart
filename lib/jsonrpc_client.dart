library jsonrpc_client;

import "dart:convert";
import "dart:async";
import "dart:html";
//import "package:logging/logging.dart";
import "client_base.dart";

/* basic usage:
 *    import "package:jsonrpc2/jsonrpc_client.dart"
 *
 *    var url = "http://somelocation";
 *    var proxy = new ServerProxy(url);
 *    response = await proxy.call("someServerMethod", [arg1, arg2 ]);
 *    try{
 *        proxy.checkError(response);
 *    }catch(e){
 *        //do error handling with error e...
 *        }
 *    print("$response");
 *
 * Each arg must be representable in JSON.
 *
 * Exceptions on the remote end will throw RpcException.
 *
 */

//final _logger = new Logger('JSON-RPC');

class ServerProxy extends ServerProxyBase {
  ServerProxy(String url) : super(url);

  executeRequest(package) async {
    //return a future with the JSON-RPC response
    HttpRequest request = new HttpRequest();
    String p;
    try {
      p = JSON.encode(package);
    } catch (e) {
      throw new UnsupportedError(
          'Item (${package}) could not be serialized to JSON');
    }
    request
      ..open('POST', url)
      ..setRequestHeader('Content-Type', 'application/json; charset=UTF-8')
      ..send(p);

    await request.onLoadEnd.first;

    String body = request.responseText;
    return new Future(() {
      if (request.status == 204 || body.isEmpty) {
        return null;
      } else {
        return JSON.decode(body);
      }
    });
  }

  handleError(e) {
    print('$e');
  }
}

class BatchServerProxy extends BatchServerProxyBase {
  dynamic proxy;
  BatchServerProxy(String url) {
    proxy = new ServerProxy(url);
  }
}
