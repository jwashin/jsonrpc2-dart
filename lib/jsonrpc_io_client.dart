library jsonrpc_io_client;

import "dart:convert";
import "dart:async";
import "dart:io";
import "package:logging/logging.dart";
import "client_base.dart";

/* basic usage:
 *    import "package:jsonrpc2/jsonrpc_io_client.dart"
 *
 *    var url = "http://somelocation";
 *    var proxy = new ServerProxy(url);
 *    Future request = proxy.call("someServerMethod", [arg1, arg2 ]);
 *    request.then((value){doSomethingWithValue(value);});
 *
 * Each arg must be representable in JSON.
 *
 * Exceptions on the remote end will throw RemoteException.
 *
 */


final _logger = new Logger('JSON-RPC');

class ServerProxy extends ServerProxyBase {
  ServerProxy(String url) : super(url);
  executeRequest(package) {
    //return a future with the JSON-RPC response
    HttpClient conn = new HttpClient();
    String JsonContent = '';
    Completer c = new Completer();
    return conn.postUrl(Uri.parse(url)).then((HttpClientRequest request) {
      request.headers.add('Content-Type', 'application/json; charset=UTF-8');
      request.write(JSON.encode(package));
      return request.close();
    }).then((HttpClientResponse response) {
      response.transform(UTF8.decoder).listen((contents) {
        JsonContent += contents.toString();
      }, onDone: () {
        if (response.statusCode == 204 || JsonContent.isEmpty) {
          c.complete(null);
        } else if (response.statusCode == 200){
          c.complete(JSON.decode(JsonContent));
        } else {
          c.completeError(new TransportStatusError(response.statusCode, response, package));
        }
      });
    }).then((_){
      return c.future;
    });
  }
}


class BatchServerProxy extends BatchServerProxyBase {
  ServerProxy proxy;
  BatchServerProxy(url) {
    proxy = new ServerProxy(url);
  }
}
