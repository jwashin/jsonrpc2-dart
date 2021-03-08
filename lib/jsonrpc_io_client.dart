library jsonrpc_io_client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'client_base.dart';
// import 'package:logging/logging.dart';

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
  bool persistentConnection=true;

  /// constructor. superize properly
  ServerProxy(String url, {this.persistentConnection = true}) : super(url);

  /// [executeRequest], overriding the abstract method
  ///
  /// return a future with the JSON-RPC response
  @override
  Future<String> executeRequest(String package) async {
    /// init a client connection
    var conn = HttpClient();

    /// make a String payload from the request package

    /// make a Http request, POSTing the payload and setting an appropriate
    /// content-type
    var request = await conn.postUrl(Uri.parse(url));
    request.headers.add('Content-Type', 'application/json; charset=UTF-8');

    /// Implementation detail: persistentConnection (default)
    /// leads to 15-second delay returning at end of script
    /// Set it to false if you are impatient. Makes little
    /// difference unless you are waiting for a testing script.
    request.persistentConnection = persistentConnection;

    request.write(package);
    var response = await request.close();

    var jsonContent = '';
    var c = Completer<String>();

    utf8.decoder.bind(response).listen((dynamic contents) {
      jsonContent += contents.toString();
    }, onDone: () {
      if (response.statusCode == 204 || jsonContent.isEmpty) {
        c.complete('');
      } else if (response.statusCode == 200) {
        c.complete(jsonContent);
      } else {
        c.completeError(TransportStatusError(
            'Transport Error ${response.statusCode}', response, package));
      }
    });
    return c.future;
  }
}

/// Please see [BatchServerProxyBase] for documentation and usage
class BatchServerProxy extends BatchServerProxyBase {
  // ServerProxy proxy;
  bool persistentConnection = false;
  String url = '';

  /// constructor
  BatchServerProxy(this.url, {bool persistentConnection = true});

  @override
  ServerProxy get proxy =>
      ServerProxy(url, persistentConnection: persistentConnection);
}
