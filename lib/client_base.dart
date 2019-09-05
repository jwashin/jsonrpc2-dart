library jsonrpc_client_base;

import "dart:async";
import "rpc_exceptions.dart";

/// [ServerProxyBase] is a base class for a JSON-RPC v2 client.
///
/// ServerPaoxy is intended to be subclassed. It does most of the client-side
/// functionality needed for JSON-RPC v2, but the transport details are
/// missing and must be provided by overriding the [executeRequest] method.
/// [ServerProxy] in [jsonrpc_client.dart] and [jsonrpc_io_client.dart] are
/// implementations as http client for a web page and http client for a command
/// line utility, respectively.
///
/// basic usage (ServerProxy is a descendant class of ServerProxyBase):
/// ```
/// import "package:jsonrpc2/jsonrpc_client.dart"
/// var url = "http://some/location";
/// var proxy = new ServerProxy(url);
/// Future request = proxy.call("someServerMethod", [arg1, arg2 ]);
///     request.then((returned)=>proxy.checkError(returned))
///     .then((value){doSomethingWithValue(value);});
/// ```
/// Each arg must be representable in json.
///
/// Exceptions on the remote end may throw [RemoteException].
class ServerProxyBase {
  /// Server will be identified with a url, so here's the place for it.
  String url;

  /// serverVersion is variable for possible fallback to JSON-RPC v1.
  String serverVersion = '2.0';

  /// Initialize with the identifier for the server resource
  ServerProxyBase(this.url);

  /// Call the method on the server. Returns Future<null>
  Future<dynamic> notify(method, [params]) {
    return call(method, params, true);
  }

  /// Package and send the method request to the server. Return the response when it returns.
  Future<dynamic> call(method, [params, notify = false]) {
    if (params == null) params = [];
    var package = JsonRpcMethod(method, params,
        notify: notify, serverVersion: serverVersion);
    if (notify) {
      executeRequest(package);
      return Future(() => null);
    } else {
      return executeRequest(package)
          .then((rpcResponse) => handleResponse(rpcResponse));
    }
  }

  /// We are transport independent. executeRequest must be implemented in a subclass
  dynamic executeRequest(JsonRpcMethod package) {}

  /// Return the result of calling the method, but first, check for error.
  dynamic handleResponse(Map<String, dynamic> response) {
    if (response.containsKey('error')) {
      return (RemoteException(response['error']['message'],
          response['error']['code'], response['error']['data']));
    } else {
      return response['result'];
    }
  }

  /// if error is a [RuntimeException], throw it, else return it.
  ///
  /// This method is used for custom exceptions, when the client and
  /// server have agreed on those.
  dynamic checkError(dynamic response) {
    if (response is RuntimeException) throw response;
    return response;
  }
}

/// [BatchServerProxyBase] is like [ServerProxyBase], but it handles the
/// special case where the batch formulation of JSON-RPC v2 is used.
/// In dart, this is n
class BatchServerProxyBase {
  /// [proxy] is a descendant of [ServerProxyBase] that actually does the hard work
  /// of sending requests and receiving responses.
  dynamic proxy;

  /// constructor. There is a reason we don't initialize with proxy here, but I forget
  BatchServerProxyBase();

  /// since this is batch mode, there is a list of method requests
  List<JsonRpcMethod> _requests = [];

  /// since this is batch mode, we have a map of responses
  /// {individual method request id: Completer for the request Future, ...}
  Map<dynamic, Completer> _responses = {};

  /// Package, but do not send an individual request.
  /// Hold a Future to fill when the request is actually sent. 
  Future<dynamic> call(method, [params, notify = false]) async {
    if (params == null) params = [];
    /// We create a JsonRpcMethod for each method request
    JsonRpcMethod package = JsonRpcMethod(method, params,
        notify: notify, serverVersion: proxy.serverVersion);
    /// and we add it to our list
    _requests.add(package);
    /// If we care about the response, register a Completer and 
    /// put that in our Map of responses. 
    if (!notify) {
      Completer c = Completer();
      _responses[package.id] = c;
      return c.future;
    }
  }

  /// shorthand for notify
  notify(method, [params]) => call(method, params, true);

  /// send a batch of requests
  send() {
    if (_requests.length > 0) {
      Future<dynamic> future = proxy.executeRequest(_requests);
      _requests = [];
      return future.then((resp) => Future.sync(() => handleResponses(resp)));
    }
  }

  /// In Batch mode, responses return in a batch. They have ids, so fill in
  /// the map of responses.
  handleResponses(responses) {
    for (var response in responses) {
      var value = proxy.handleResponse(response);
      var id = response['id'];
      if (id != null) {
        _responses[id].complete(value);
        _responses.remove(id);
      } else {
//        var error = resp['error'];
//        _logger.warning(new RemoteException(error['message'], error['code'], error['data']).toString());
      }
    }
    return null;
  }
}

/// JsonRpcMethod class holds name and args of a method request for JSON-RPC v2 formatting
///
/// Initialize with a string methodname and list or map of params
/// if [notify] is true, output format will be as "notification"
/// [id] is an int automatically generated from hashCode
class JsonRpcMethod {
  String method;
  dynamic args;
  bool notify;
  int _id;
  String serverVersion;

  /// constructor
  JsonRpcMethod(this.method, this.args,
      {this.notify: false, this.serverVersion: '2.0'});

  /// create id from hashcode when requested
  get id {
    if (_id == null) _id = this.hashCode;
    return notify ? null : _id;
  }

  /// output the map representation of this instance for processing into JSON
  toJson() {
    Map<String, dynamic> map;
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
        if (args is Map)
          throw FormatException("Cannot use named params in JSON-RPC 1.0");
        map = {
          'method': method,
          'params': (args is List) ? args : [args],
          'id': id
        };
        break;
    }
    return map;
  }

  /// useful string representation for debugging
  toString() => "JsonRpcMethod: ${toJson()}";
}

/// [RemoteException] may be used in user client-server code for exceptions
/// not related to the actual transport.
/// For example, "this is not quite right", not "this is broken"
///
class RemoteException implements Exception {
  /// code for the exception. This is not for the JSON-RPC error codes.
  int code;

  /// helpful message
  String message;
  dynamic data;

  /// constructor
  RemoteException([this.message, this.code, this.data]);

  toString() => data != null
      ? "RemoteException $code: '$message' Data:($data))"
      : "RemoteException $code: '$message'";
}

/// [TransportStatusError]
class TransportStatusError implements Exception {
  var message;
  var data;
  var request;

  TransportStatusError([this.message, this.request, this.data]);

  toString() => "$message";
}
