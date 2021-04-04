import 'package:http/http.dart' as http;
import 'package:jsonrpc2/src/client_base.dart';

/// basic usage:
///
///    String resource = "http://somelocation";
///    ServerProxy proxy = ServerProxy(resource);
///    try{
///    response = await proxy.call("someServerMethod", [arg1, arg2]);
///     }on RpcException catch(e){
///         // do error handling with exception e...
///         }
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
  ServerProxy(String resource, [this.customHeaders = const <String, String>{}])
      : super(resource);

  /// Send the package (it's a String), and await to receive a String (it's a 
  /// JSON-RPC encoded Response) from the other end, and return it.
  @override
  Future<String> transmit(String package, [isNotification=false]) async {
    var headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (customHeaders.isNotEmpty) {
      headers.addAll(customHeaders);
    }

    // useful for debugging!
    // print(package);
    var resp = await http.post(Uri.parse(resource), body: package, headers: headers);

    var body = resp.body;
    if (resp.statusCode == 204 || body.isEmpty) {
      return '';
    } else {
      return body;
    }
  }
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
