/// [jsonrpc_service] is a server-side implementation of JSPN-RPC v2.
///
///
library jsonrpc_service;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:rpc_dispatcher/rpc_dispatcher.dart';
import 'package:rpc_exceptions/rpc_exceptions.dart';



// using log from dart:developer, so using logging constants from
// https://github.com/dart-lang/logging/blob/master/lib/src/level.dart

const _info = 800;
const _fine = 500;
const _finer = 400;

/// Version string for JSON-RPC v2
const jsonRpcV2 = '2.0';

/// Version string for JSON-RPC v1
const jsonRpcV1 = '1.0';

/// Empty class. We just need to say a response "is" a Notification
class Notification {
  @override
  String toString() {
    return '';
  }
}

/// Identifiers for the types of params, that determine how they need
/// to be handled
enum paramsTypes {
  /// list type
  list,

  /// map type. named parameters
  map,

  /// single. one thing, which could be a list or map or null
  single,

  /// a list or map that is empty
  empty
}

/// [MethodRequest] holds a specially formed JSON object
/// requesting to perform a method on the server.
///
/// It has "method", "params", and usually "id" and 'jsonrpc" members
/// * method is the method to invoke
/// * params is the args. if Map, named args. if List, positional args.
/// * id identifies the response for when it is returned to the sender.
/// * jsonrpc is version for the JSON-RPC specification currently 2.0
class MethodRequest {
  /// [request] is the Map decoded from the incoming chunk of JSON
  Map<String, dynamic> request;

  /// [ptype] informs us how to handle the object.
  paramsTypes ptype = paramsTypes.single;

  /// constructor
  MethodRequest(this.request) {
    getParamsType();
  }

  /// Is params a List, Map, single, or empty?
  ///
  /// It's easier to decide how to make the method request if we know
  /// what kind of thing the "params" object is. These things must be handled
  /// "very delicately."
  void getParamsType() {
    var parms = request['params'];
    // literal null as a parameter. Does this happen?
    if (request.containsKey('params') && parms == null) {
      ptype = paramsTypes.single;
      return;
    }
    ptype = paramsTypes.empty;
    if (parms == null) {
      return;
    } else if (parms is Map) {
      if (parms.isEmpty) {
        ptype = paramsTypes.empty;
        return;
      }
      ptype = paramsTypes.map;
      return;
    } else if (parms is List) {
      if (parms.isEmpty) {
        ptype = paramsTypes.empty;
        return;
      }
      ptype = paramsTypes.list;
      return;
    } else {
      ptype = paramsTypes.single;
    }
  }

  /// [version] is new in JSON-RPC v2, so handle appropriately
  dynamic get version {
    try {
      var version = request['jsonrpc'];
      if (version == null) return jsonRpcV1;
      if (version != jsonRpcV2) {
        throwException(RpcException('Invalid request', -32600));
      }
      return version;
    } on Exception catch (_) {
      // we always get version first, so if request is not proper, fail here
      throw makeExceptionMap(
          RpcException('Invalid request', -32600), jsonRpcV2, null);
    }
  }

  /// what method does the client want the server to do?
  dynamic get method {
    dynamic method = request['method'];
    if (method is! String) {
      // print("method is not a string")
      throw RpcException('Invalid request', -32600);
    }
    return method;
  }

  /// If we have a Map of named arguments, return the map. Else return null.
  Map<String, dynamic> get namedParams {
    if (ptype == paramsTypes.map) {
      return request['params'];
    }
    return <String,dynamic>{};
  }

  /// If we have a List of arguments, return the list. Else return null.
  List<dynamic> get positionalParams {
    if (ptype == paramsTypes.list) {
      return request['params'];
    } else if (ptype != paramsTypes.map) {
      if (ptype == paramsTypes.empty) {
        return [];
      } else {
        // params is plural, so put single things in a list
        return [request['params']];
      }
    }
    return [];
  }

  /// id has to be a number or a string, or missing.
  dynamic get id {
    dynamic id = request['id'];
    if (id is String || id is num || id == null) {
      return id;
    }
    throwException(RpcException('Invalid Request', -32600));
  }

  /// This is shorthand to make a map of the exception, not actually throwing.
  void throwException(Exception exception) {
    throw makeExceptionMap(exception, version, request['id']);
  }
}

/// Invoke a method

/// Given a parsed JSON-RPC request and an initialized Dispatcher,
/// return a Future with a Map of the result of the instance's method or a
/// Notification object
dynamic jsonRpcDispatch(
    Map<String, dynamic> request, Dispatcher dispatcher) async {
  var rq;
  var id;
  var version;
  var method;
  try {
    rq = MethodRequest(request);
    version = rq.version;
    id = rq.id;
    method = rq.method;
  } on Exception catch (e) {
    return makeExceptionMap(e, jsonRpcV2);
  }
  try {
    var value =
        await dispatcher.dispatch(method, rq.positionalParams, rq.namedParams);
    if (id == null) {
      return Notification();
    }
    if (value is RpcException) {
      log('$value', level: _fine);
      return makeExceptionMap(value, version, id);
    }
    var resp = <String, dynamic>{'result': value, 'id': id};
    if (version == jsonRpcV2) {
      resp['jsonrpc'] = version;
    } else if (version == jsonRpcV1) {
      resp['error'] = null;
    }
    return resp;
  } on Exception catch (e) {
    log('$e', level: _info);

    return makeExceptionMap(e, version, id);
  }
}

/// Instead of crashing the server, we send the exception back to the client.
Map makeExceptionMap(Object anException, String version, [dynamic id]) {
  var resp = <String, dynamic>{'id': id};
  if (version == jsonRpcV1) {
    resp['result'] = null;
  } else {
    resp['jsonrpc'] = version;
  }
  if (anException is RpcException) {
    resp['error'] = anException.toJson();
  } else {
    log('$anException', level: _info);
    resp['error'] = {'code': -32000, 'message': '$anException'};
  }
  return resp;
}

/// is this a batch request?
bool _shouldBatch(Object obj) {
  log('checking batch', level: _finer);
  if (obj is! List) return false;
  if (obj.isEmpty) return false;
  return true;
}

/// Accept a JSON-RPC String request and return a String
///
/// Given a JSON-RPC-formatted request string and an instance,
/// return the string .
/// the encodeResponse method
/// (e.g., HTTP) must return something. To do something di
Future<String> jsonRpc(String request, Dispatcher dispatcher) async {
  log('$request', level: _info);
  try {
    var resp = await jsonRpcExec(parseJson(request), dispatcher);
    return encodeResponse(resp);
  } on Exception catch (e) {
    return encodeResponse(makeExceptionMap(e, jsonRpcV2));
  }
}

/// Execute the request.
///
/// Given a parsed JSON-RPC Map or a List of them, and a Dispatcher,
/// return a proper JSON-RPC Map or List of responses
Future jsonRpcExec(Object request, Dispatcher dispatcher) async {
  // Single method
  if (request is Map &&
      (request['jsonrpc'] == jsonRpcV2 || request['jsonrpc'] == null)) {
    log('$request', level: _info);
    return jsonRpcDispatch(Map<String, dynamic>.from(request), dispatcher);
  } else {
    // batch of methods
    if (request is List && _shouldBatch(request)) {
      var responses = <Future>[];

      for (var rpc in request) {
        if (rpc is Map) {
          rpc['jsonrpc'] = jsonRpcV2;
          var value =
              jsonRpcDispatch(Map<String, dynamic>.from(rpc), dispatcher);
          responses.add(value);
        } else {
          responses.add(Future(() => makeExceptionMap(
              RpcException('Invalid request', -32600), '2.0', null)));
        }
        log('in batch: $rpc', level: _finer);
      }
      var theList = await Future.wait(responses);

      var output = [];
      for (var item in theList) {
        if (item is! Notification) {
          output.add(item);
        }
      }
      if (output.isNotEmpty) {
        return output;
      }
      return Notification();
    }
    return makeExceptionMap(
        RpcException('Invalid request', -32600), '2.0', null);
  }
}

/// Parse the JSON string
///
/// We do this in a separate method for a distinguishable parse error
/// Rethrow errors back to the client as ParseError, per specification.
dynamic parseJson(String aString) {
  try {
    return json.decode(aString);
  } on JsonUnsupportedObjectError catch (_) {
    throw RpcException('Parse error', -32700);
  } on FormatException catch (_) {
    throw RpcException('Parse error', -32700);
  }
}

/// Encode the result into JSON.
///
/// Here, we encode Notification objects as an empty string.
String encodeResponse(dynamic response) {
  if (response is Notification) {
    return '';
  }
  try {
    return json.encode(response);
  } on JsonUnsupportedObjectError {
    return json.encode(makeExceptionMap(
        RpcException(
            'Result was not JSON-serializable (${response['result']}).',
            -32601),
        '2.0',
        null));
  }
}
