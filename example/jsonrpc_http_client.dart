import 'package:http/http.dart' as http;
import 'package:jsonrpc2/src/client_base.dart';

/// basic usage:
///
///    String url = "http://somelocation";
///    ServerProxy proxy = ServerProxy(url);
///    response = await proxy.call("someServerMethod", [arg1, arg2]);
///    try{
///         proxy.checkError(response);
///     }on RpcException catch(e){
///         // do error handling with exception e...
///         }
///
///     // do something with response...
///
///  Each arg in the call must be representable in json
///  or have a toJson() method.
///
///  Exceptions on the remote end will throw RpcException.

class ServerProxy extends ServerProxyBase {
  /// customHeaders, for jwts and other niceties
  Map<String, String> customHeaders;

  /// constructor. superize properly
  ServerProxy(String url, [this.customHeaders = const <String, String>{}])
      : super(url);

  /// Return a Future with the JSON-RPC response
  @override
  Future<String> transmit(String package, [bool isNotification = false]) async {
    /// This is HttpRequest from dart:html

    var headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (customHeaders.isNotEmpty) {
      headers.addAll(customHeaders);
    }

    // useful for debugging!
    // print(package);
    var resp =
        await http.post(Uri.parse(resource), body: package, headers: headers);

    var body = resp.body;
    if (resp.statusCode == 204 || body.isEmpty) {
      return ''; // we'll return an empty string for null response
    } else {
      return body;
    }
  }

  // optionally, mirror remote API
  // Future echo(dynamic aThing) async {
  //   var resp = await call('echo', [aThing]);
  //   return resp;
  // }
}

/// see the documentation in [BatchServerProxyBase]
class BatchServerProxy extends BatchServerProxyBase {
  @override
  dynamic proxy;

  /// constructor
  BatchServerProxy(String url, [customHeaders = const <String, String>{}]) {
    proxy = ServerProxy(url, customHeaders);
  }
}
