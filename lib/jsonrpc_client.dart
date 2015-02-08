library jsonrpc_client;

import "dart:convert";
import "dart:async";
import "dart:html";
import "package:logging/logging.dart";
import "client_base.dart";

/* basic usage:
 *    import "package:jsonrpc2/jsonrpc_client.dart"
 *
 *    var url = "http://somelocation";
 *    var proxy = new ServerProxy(url);
 *    Future request = proxy.call("someServerMethod", [arg1, arg2 ]);
 *    request.then((value){doSomethingWithValue(value);});
 *
 * Each arg must be representable in JSON.
 *
 * Exceptions on the remote end will throw RpcException.
 *
 */


final _logger = new Logger('JSON-RPC');

class ServerProxy extends ServerProxyBase {
  ServerProxy(String url) : super(url);


  executeRequest(package) {
    //return a future with the JSON-RPC response
    HttpRequest request = new HttpRequest();
    request.open("POST", url, async: true);
    //request.timeout = timeout;
    request.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    var c = new Completer();
    request.onReadyStateChange.listen((_) {
      if (request.readyState == 4) {
        switch (request.status) {

          case 200:
            c.complete(request);
            break;

          case 204:
            c.complete(request);
            break;

          default:
            c.completeError(new TransportStatusError(request.statusText, request, package));
        }
      }
    });
    //Timeout
//    request.onTimeout.listen((_) {
//      //request.abort();
//      c.completeError(new TimeoutException('JsonRpcRequest timed out'));
//    });

    // It's sent out utf-8 encoded. Without having to be told. Nice!
    try{

      request.send(JSON.encode(package));
    } catch (e){
      throw new UnsupportedError('Item (${package}) could not be serialized to JSON');
      //throw e;
    }



    return c.future.then((request) => new Future(() {
      String body = request.responseText;
      if (request.status == 204 || body.isEmpty) {
        return null;
      } else {
        return JSON.decode(body);
      }
    }));
  }
}


class BatchServerProxy extends BatchServerProxyBase{
  ServerProxy proxy;
  BatchServerProxy(url){
    proxy = new ServerProxy(url);
    }
}
