library jsonrpc_client_base;
import "dart:async";
import "package:logging/logging.dart";

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
 * Exceptions on the remote end will throw RemoteException.
 *
 *
 */


final _logger = new Logger('JSON-RPC');
//Logger.root.level = Level.ALL;
//Logger.root.onRecord.listen(new LogPrintHandler());

class ServerProxyBase {
  String url;
  //int timeout = 0;
  String serverVersion = '2.0';
  ServerProxyBase(this.url);

  notify(method, [params = null]) {
    return call(method, params, true);
  }

  retry(package) {
    return call(package.method, package.args, package.notify);
  }

  call(method, [params = null, notify = false]) {
    /* Package and send the request.
     * Return the response
     */

    if (params == null) params = [];
    var package = new JsonRpcMethod(method, params, notify: notify, serverVersion: serverVersion);
    if (notify) {
      executeRequest(package);
      return new Future(() => null);
    } else return executeRequest(package).then((rpcResponse) => handleResponse(rpcResponse));
  }

  executeRequest(package) {
    //this requires implementation in subclasses
  }

  handleResponse(response) {
    if (response.containsKey('error')) {
      return (new RemoteException(response['error']['message'], response['error']['code'], response['error']['data']));
    } else {
      return response['result'];
    }
  }

  checkError(response) {
    if (response is RemoteException) throw response;
    return response;
  }

}


class BatchServerProxyBase {

  var proxy;

  BatchServerProxyBase();

  //get timeout => proxy.timeout;
  //set timeout(int t){proxy.timeout = timeout;}

  List requests = [];
  Map responses = {};
  Map used_ids = {};


  call(method, [params = null, notify = false]) {
    /* Package and send the request.
     * Return a Future with the HttpRequest object
     */

    if (params == null) params = [];
    var package = new JsonRpcMethod(method, params, notify: notify, serverVersion: proxy.serverVersion);
    requests.add(package);
    if (!notify) {
      var c = new Completer();
      responses[package.id] = c;
      return c.future;
    }
  }

  notify(method, [params = null]) => call(method, params, true);

  send() {
    if (requests.length > 0) {
      Future future = proxy.executeRequest(requests);
      requests = [];
      return future.then((resp) => new Future.sync(() => handleResponses(resp)));
    }
  }

  handleResponses(resps) {
    for (var resp in resps) {
      var value = proxy.handleResponse(resp);
      //if (value is Exception) throw value;
      var id = resp['id'];
      if (id != null) {
        responses[id].complete(value);
        responses.remove(id);
      } else {
        var error = resp['error'];
        _logger.warning(new RemoteException(error['message'], error['code'], error['data']).toString());
      }
    }
    return null;
  }
}


class JsonRpcMethod {
  String method;
  var args;
  bool notify;
  var _id;
  String serverVersion;
  JsonRpcMethod(this.method, this.args, {this.notify: false, this.serverVersion: '2.0'});

  get id {
    if (notify) {
      return null;
    } else {
      if (_id == null) _id = this.hashCode;
      return _id;
    }
  }

  set id(var value) => _id = value;

  toJson() {
    Map map;
    switch (serverVersion) {
      case '2.0':
        map = {
          'jsonrpc': serverVersion,
          'method': method,
          'params': (args is List || args is Map) ? args : [args]
        };
        if (!notify) map['id'] = id;
        break;
      case '1.0':
        if (args is Map) throw new FormatException("Cannot use named params in JSON-RPC 1.0");
        map = {
          'method': method,
          'params': (args is List) ? args : [args],
          'id': id
        };
        break;
    }
    return map;
  }

  toString() => "JsonRpcMethod: ${toJson()}";
}


class RemoteException implements Exception {
  int code;
  String message;
  var data;
  RemoteException([this.message, this.code, this.data]);
  toString() => data != null ? "RemoteException $code '$message' Data:($data))" : "RemoteException $code: $message";
}


class TransportStatusError implements Exception {
  var message;
  var data;
  var request;
  TransportStatusError([this.message, this.request, this.data]);
  toString() => "$message";
}
