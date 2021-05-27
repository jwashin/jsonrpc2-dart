library jsonrpc_client_base;

import 'dart:async';
import 'dart:convert';
// import 'package:jsonrpc2/jsonrpc_service.dart';
import 'package:logging/logging.dart';

import 'rpc_exceptions.dart';

final log = Logger('MyClassName');

/// [ServerProxyBase] is a base class for a JSON-RPC v2 client.
///
/// ServerProxyBase is intended to be subclassed. It does most of the
/// client-side functionality needed for JSON-RPC v2, but the transport details
/// are missing and must be provided by overriding the [executeRequest] method.
/// [ServerProxy] in [jsonrpc_client.dart] and [jsonrpc_io_client.dart] are
/// implementations as http client for a web page and http client for a command
/// line utility, respectively.
///
/// basic usage (ServerProxy here is a descendant class of ServerProxyBase):
/// ```
/// import 'package:jsonrpc2/jsonrpc_client.dart'
/// var url = 'http://some/location';
/// var proxy = new ServerProxy(url);
/// Future request = proxy.call('someServerMethod', [arg1, arg2 ]);
///     request.then((returned)=>proxy.checkError(returned))
///     .then((value){doSomethingWithValue(value);});
/// ```
/// Each arg must be representable in json.
///
/// Exceptions on the remote end may throw [RemoteException].
abstract class ServerProxyBase {
  /// Server will be identified with a url, so here's the place for it.
  String url;

  /// serverVersion is variable for possible fallback to JSON-RPC v1.
  String serverVersion = '2.0';

  /// Initialize with the identifier for the server resource
  ServerProxyBase(this.url);

  /// Call the method on the server. Returns Future<dynamic>
  Future<String> notify(String method, [dynamic params]) async {
    var meth = JsonRpcMethod(method, params,
        notify: true, serverVersion: serverVersion);
    var package = json.encode(meth);
    await executeRequest(package);
    return '';
  }

  /// Package and send the method request to the server.
  /// Return the response when it returns.
  Future<dynamic> call(String method, [dynamic params]) async {
    var meth = JsonRpcMethod(method, params, serverVersion: serverVersion);
    var package;
    try {
      package = json.encode(meth);
    } on JsonUnsupportedObjectError catch (e) {
      throw UnsupportedError('$e');
    }
    var resp = await executeRequest(package);
    return handleResponse(resp);
  }

  /// This is the transport interface. Abstract method [executeRequest] must
  /// be implemented in a subclass. [package] is a String JSON-RPC Request
  /// created through the [call] method of this class. Override the
  /// [executeRequest] method to send the package to a server recipient, and
  /// return the String body that comes back. You probably want to do error
  /// handling on the transport.
  ///
  Future<String> executeRequest(String package);

  /// Return the result of calling the method, but first, check for error.
  dynamic handleResponse(String returned) {
    // print('returned is $returned, ${returned.runtimeType}');
    var resp = Map<String, dynamic>.from(json.decode(returned));
    // print('response is $resp, ${resp.runtimeType}');
    return handleDecoded(resp);
  }

  dynamic handleDecoded(Map resp) {
    if (resp.containsKey('error')) {
      return RemoteException(resp['error']['message'], resp['error']['code'],
          resp['error']['data']);
    }
    return resp['result'];
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
/// In dart, this is not particularly useful with async/await
class BatchServerProxyBase {
  /// [proxy] is a descendant of [ServerProxyBase] that actually does
  /// the hard work of sending requests and receiving responses.
  dynamic proxy;

  /// constructor. There is a reason we don't initialize with proxy here,
  /// but I forget
  BatchServerProxyBase();

  /// since this is batch mode, there is a list of method requests
  final _requests = <JsonRpcMethod>[];

  /// since this is batch mode, we have a map of responses
  /// {individual method request id: Completer for the request Future, ...}
  final _responses = <dynamic, Completer>{};

  /// Package, but do not send an individual request.
  /// Hold a Future to fill when the request is actually sent.
  Future<dynamic> call(String method, [dynamic params]) async {
    /// We create a JsonRpcMethod for each method request
    var package =
        JsonRpcMethod(method, params, serverVersion: proxy.serverVersion);

    /// and we add it to our list
    _requests.add(package);

    /// We care about this response, so we register a Completer and
    /// put that in a Map to await response. When it comes back,
    /// we match it by id.
    var c = Completer();
    _responses[package.id] = c;
    return c.future;
  }

  /// add to _requests list, but we don't care about anything returned
  void notify(String method, [dynamic params]) {
    var package = JsonRpcMethod(method, params,
        notify: true, serverVersion: proxy.serverVersion);
      // add this for requesting, but not for the completion queue
    _requests.add(package);
  }

  /// send a batch of requests
  Future<dynamic> send() async {
    if (_requests.isEmpty) {
      throw ArgumentError('Nothing to send');
    } else {
      var batchRequests = '';
      try {
        batchRequests = json.encode(_requests);
      } on JsonUnsupportedObjectError catch (e) {
        throw UnsupportedError('$e');
      }
      var responses = await proxy.executeRequest(batchRequests);
      // reset the requests holder
      _requests.clear();
      return handleResponses(responses);
      // return future.then((resp) => Future.sync(() => handleResponses(resp)));
    }
  }

  /// In Batch mode, responses also return in a batch. The individual responses
  /// have ids, so plug them into the Map of responses
  /// to complete those Futures.
  void handleResponses(String responseString) {
    var responses = json.decode(responseString);
    // print('responseString is $responseString');
    for (var response in responses) {
      var value = proxy.handleDecoded(response);
      var id = response['id'];
      if (_responses.containsKey(id)) {
        {
          _responses[id]!.complete(value);
          _responses.remove(id);
        }
      }
    }
  }
}

/// JsonRpcMethod class holds name and args of a method request for JSON-RPC v2
///
/// Initialize with a string methodname and list or map of params
/// if [notify] is true, output format will be as 'notification'
/// [id] is an int automatically generated from hashCode
class JsonRpcMethod {
  /// [method] is the name of the method at the server
  String method;

  /// [args] is arguments to the method at the server. May be Map or List or nil
  Object? args;

  /// Do we care about the response value?
  bool notify = false;

  /// private. It's auto-generated, but we hold on to it in case we need it
  /// more than once. id is null for notifications.
  int? _id;

  /// It's '2.0' until further notice, or if a client is in the dark ages.
  String serverVersion;

  /// constructor
  JsonRpcMethod(this.method, this.args,
      {this.notify = false, this.serverVersion = '2.0'});

  /// create id from hashcode when first requested
  dynamic get id {
    _id ??= hashCode;
    return notify ? null : _id;
  }

  /// output the map representation of this instance for processing into JSON
  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    switch (serverVersion) {
      case '2.0':
        map = {
          'jsonrpc': serverVersion,
          'method': method,
          'params': (args == null)
              ? []
              : (args is List || args is Map)
                  ? args
                  : [args]
        };
        if (!notify) map['id'] = id;
        break;
      case '1.0':
        if (args is Map) {
          throw FormatException('Cannot use named params in JSON-RPC 1.0');
        }
        map = {
          'method': method,
          'params': (args is List) ? args : [args],
          'id': id
        };
        break;
    }
    return map;
  }

  /// A useful string representation for debugging, etc.
  @override
  String toString() => 'JsonRpcMethod: ${toJson()}';
}

/// [RemoteException] may be used in user client-server code for exceptions
/// not related to the actual transport.
///
/// It's for telling the user, 'this is not quite right', not 'this is broken'.
class RemoteException implements Exception {
  /// code for the exception. This is not for the JSON-RPC error codes.
  int? code;

  /// maybe a helpful message
  String? message;

  /// maybe some helpful data
  dynamic? data;

  /// constructor
  RemoteException([this.message, this.code, this.data]);

  @override
  String toString() => data != null
      ? 'RemoteException $code: \'$message\' Data:($data))'
      : 'RemoteException $code: \'$message\'';
}

/// [TransportStatusError] is an error related to the chosen transport.
///
/// If you want to identifiy errors in your HTTP or WebSockets transport,
/// for example, this provides a hook for that purpose.
class TransportStatusError implements Exception {
  /// maybe a helpful message
  String message;

  /// maybe some helpful data
  dynamic data;

  /// maybe the request itself
  dynamic request;

  /// constructor
  TransportStatusError([this.message = '', this.request, this.data]);

  @override
  String toString() => '$message';
}
