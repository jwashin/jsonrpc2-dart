library jsonrpc_io_client;

import "dart:convert";
import "dart:async";
import "dart:io";
//import "package:logging/logging.dart";
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
 * Exceptions on the remote end will throw RpcException.
 *
 */

//final _logger = new Logger('JSON-RPC');

class ServerProxy extends ServerProxyBase {
  bool persistentConnection;
  ServerProxy(String url, [this.persistentConnection = true]) : super(url);
  Future<dynamic> executeRequest(dynamic package) {
    //return a future with the JSON-RPC response
    HttpClient conn = new HttpClient();
    String jsonContent = '';
    Completer<dynamic> c = new Completer<dynamic>();
    String payload;
    try {
      payload = JSON.encode(package);
    } catch (e) {
      throw new UnsupportedError(
          'Item ($package) could not be serialized to JSON');
    }
    return conn.postUrl(Uri.parse(url)).then((HttpClientRequest request) {
      request.headers.add('Content-Type', 'application/json; charset=UTF-8');
      // persistentConnection leads to 15-second delay returning on end of script
      request.persistentConnection = persistentConnection;
      request.write(payload);
      return request.close();
    }).then((HttpClientResponse response) {
      response.transform(UTF8.decoder).listen((dynamic contents) {
        jsonContent += contents.toString();
      }, onDone: () {
        if (response.statusCode == 204 || jsonContent.isEmpty) {
          c.complete(null);
        } else if (response.statusCode == 200) {
          c.complete(JSON.decode(jsonContent));
        } else {
          c.completeError(
              new TransportStatusError(response.statusCode, response, package));
        }
      });
    }).then((_) {
      return c.future;
    });
  }
}

class BatchServerProxy extends BatchServerProxyBase {
  dynamic proxy;
  BatchServerProxy(String url, [bool persistentConnection = true]) {
    proxy = new ServerProxy(url, persistentConnection);
  }
}
