library jsonrpc_client_base;

import 'dart:async';
import 'dart:convert';

import 'package:rpc_exceptions/rpc_exceptions.dart';

/// [ServerProxyBase] is a base class for a JSON-RPC v2 client.
///
/// ServerProxyBase is intended to be subclassed. It does most of the
/// client-side functionality needed for JSON-RPC v2, but the transport details
/// are missing and must be provided by overriding the [transmit] method.
/// [ServerProxy] in [jsonrpc_client.dart] is an implementation.
///
/// basic usage (ServerProxy here is a descendant class of ServerProxyBase):
/// ```
/// import 'package:jsonrpc2/jsonrpc_client.dart'
/// var url = 'http://some/location';
/// var proxy = new ServerProxy(url);
/// try{
///    var response = await proxy.call('someServerMethod', [arg1, arg2 ]);
/// }on RemoteException (e){\\do something with exception e}
///
///     doSomethingWithValue(response);
/// ```
/// Each arg must be representable in json.
///
/// Exceptions on the remote end may throw [RemoteException].
abstract class ServerProxyBase {
  /// Proxy will be initialized with some sort of remote resource, so make
  /// a place for it.
  dynamic resource;

  /// serverVersion is variable for possible fallback to JSON-RPC v1.
  final String _serverVersion = '2.0';

  /// Initialize with the identifier for the server resource
  ServerProxyBase(this.resource);

  /// Call the method on the server. Returns Future<dynamic>
  Future<String> notify(String method, [dynamic params]) async {
    var package = json.encode(JsonRpcMethod(method, params,
        notify: true, serverVersion: _serverVersion));
    await transmit(package, true);
    return '';
  }

  /// Call a method on the remote server, and get a response
  ///
  /// no params:              proxy.call('method_a');
  /// single immutable param: proxy.call('method_b', 'some text');
  /// single immutable param: proxy.call('method_b', ['some text']);
  /// positional params:      proxy.call('method_c', [arg1, arg2, arg3]);
  /// single List param:      proxy.call('method_d', [[a,b,c,d]]);
  /// single Map param:       proxy.call('method_d', [{'p':5,'d':true}]);
  /// named params:           proxy.call('method_e', {'ID':23,'nm':'Jo'});
  ///
  Future<dynamic> call(String method, [dynamic params]) async {
    /// This will throw error if not encodable into JSON
    var package = json
        .encode(JsonRpcMethod(method, params, serverVersion: _serverVersion));

    var resp = await transmit(package);
    return _handleResponse(resp);
  }

  /// Transmit a JSON-RPC String. Receive a response, and return it.
  ///
  /// This is the transport interface. Abstract method [transmit] must
  /// be implemented in a subclass. package is a String JSON-RPC Request
  /// created through the [call] method of this class. Override this
  /// method by sending the package to a remote recipient,
  /// and returning the String body (also JSON) that comes back. You may want to
  /// do error handling on the transport. The [resource] member from
  /// initialization is available for your use in your subclass.
  /// [isNotification] indicates whether the package is a notification. The
  /// transport determines whether notifications should be waited for. Http
  /// always returns something. Other transports may not.
  ///
  Future<String> transmit(String package, [bool isNotification = false]);

  /// Return the result of calling the method.
  dynamic _handleResponse(String returned) {
    // print('returned is $returned, ${returned.runtimeType}');
    var resp = Map<String, dynamic>.from(json.decode(returned));
    // print('response is $resp, ${resp.runtimeType}');
    return _handleDecoded(resp);
  }

  dynamic _handleDecoded(Map resp) {
    if (resp.containsKey('error')) {
      throw RuntimeException.fromJson(resp['error']);
    }
    return resp['result'];
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
        JsonRpcMethod(method, params, serverVersion: proxy._serverVersion);

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
        notify: true, serverVersion: proxy._serverVersion);
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
      var responses = await proxy.transmit(batchRequests);
      // reset the requests holder
      _requests.clear();
      return _handleResponses(responses);
    }
  }

  /// In Batch mode, responses also return in a batch. The individual responses
  /// have ids, so plug them into the Map of responses
  /// to complete those Futures.
  void _handleResponses(String responseString) {
    var responses = json.decode(responseString);
    // print('responseString is $responseString');
    for (var response in responses) {
      var value = proxy._handleDecoded(response);
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
