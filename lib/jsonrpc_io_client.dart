library jsonrpc_io_client;

import "dart:convert";
import "dart:async";
import "dart:io";
import "client_base.dart";

/// basic usage:
///    import "package:jsonrpc2/jsonrpc_io_client.dart"
///
///    String url = "http://somelocation";
///    ServerProxy proxy = ServerProxy(url);
///    response = await proxy.call("someServerMethod", [arg1, arg2]);
///    try{
///         proxy.checkError(response);
///     }catch(e){
///         // do error handling with error e...
///         }
///     // do something with response...
///
///  Each arg must be representable in json.
///
///  Exceptions on the remote end will throw RpcException.
class ServerProxy extends ServerProxyBase {
  /// Do we want this connection to be persistent?
  bool persistentConnection;

  /// constructor. superize properly
  ServerProxy(String url, [this.persistentConnection = true]) : super(url);

  /// [executeRequest], overriding the abstract method
  ///
  /// return a future with the JSON-RPC response
  Future<Map<String, dynamic>> executeRequest(JsonRpcMethod package) async {
    /// init a client connection
    HttpClient conn = HttpClient();

    /// make a String payload from the request package
    String payload;
    try {
      payload = json.encode(package);
    } catch (e) {
      throw UnsupportedError('Item ($package) could not be serialized to JSON');
    }

    /// make a Http request, POSTing the payload and setting an appropriate
    /// content-type
    HttpClientRequest request = await conn.postUrl(Uri.parse(url));
    request.headers.add('Content-Type', 'application/json; charset=UTF-8');

    /// Implementation detail: persistentConnection (default) leads to 15-second delay returning at end of script
    /// Set it to false if you are impatient. Makes little difference
    request.persistentConnection = persistentConnection;

    request.write(payload);
    HttpClientResponse response = await request.close();

    String jsonContent = '';
    Completer c = Completer();

    utf8.decoder.bind(response).listen((dynamic contents) {
      jsonContent += contents.toString();
    }, onDone: () {
      if (response.statusCode == 204 || jsonContent.isEmpty) {
        c.complete(null);
      } else if (response.statusCode == 200) {
        c.complete(json.decode(jsonContent));
      } else {
        c.completeError(
            TransportStatusError(response.statusCode, response, package));
      }
    });

    return c.future;
  }
}

/// Please see [BatchServerProxyBase] for documentation and usage
class BatchServerProxy extends BatchServerProxyBase {
  dynamic proxy;

  /// constructor
  BatchServerProxy(String url, [bool persistentConnection = true]) {
    proxy = ServerProxy(url, persistentConnection);
  }
}
