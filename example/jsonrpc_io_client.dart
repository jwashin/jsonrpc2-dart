library jsonrpc_io_client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jsonrpc2/src/client_base.dart';

/// This is an example JSON-RPC2 client for dart:io.
/// 
/// basic usage:
///
///    String url = "http://somelocation";
///    ServerProxy proxy = ServerProxy(url);
///    response = await proxy.call("someServerMethod", [arg1, arg2]);
///    try{
///         proxy.checkError(response);
///     }on RpcException catch(e){
///         // do error handling with error e...
///         }
///     // do something with response...
///
///  Each arg must be representable in json.
///
///  Exceptions on the remote end will throw RpcException.

/// A ServerProxy stands in for the server end of the conversation.
/// ServerProxyBase takes care of the JSON-RPC specific stuff. Referring to the
/// above instructions, when you call a server method with args, that 
/// invocation is converted into a JSON-RPC package, a specially-formatted
/// chunk of JSON. The overridden [executeRequest] method here sends that string
/// to the server and receives a string in response. The response is parsed, and
/// the result, or an error, is returned as the result of the call.
class ServerProxy extends ServerProxyBase {
  /// Do we want this connection to be persistent? true is default.
  bool persistentConnection = true;

  /// constructor. superize properly
  ServerProxy(String url) : super(url);

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
  bool persistentConnection = true;
  String url = '';

  /// constructor
  BatchServerProxy(this.url);

  @override
  ServerProxy get proxy => ServerProxy(url);
}
