/// [jsonrpc_service] is a server-side implementation of JSPN-RPC v2.
///
///
library jsonrpc_service;

import 'dart:convert';
import 'dart:async';
import 'dart:developer';

import 'rpc_exceptions.dart';
import 'dispatcher.dart';

// using log from dart:developer, so using logging constants from
// https://github.com/dart-lang/logging/blob/master/lib/src/level.dart

const info = 800;
const fine = 500;
const finer = 400;

/// Version string for JSON-RPC v2
const JsonRpcV2 = '2.0';

/// version string for v1
const JsonRpcV1 = '1.0';

/// Empty class. We just need to say a response "is" a Notification
class Notification {
  @override
  String toString() {
    return '';
  }
}

enum paramsTypes { list, map, single, empty }

/// [MethodRequest] holds a specially formed JSON object
/// requesting to perform a method on the server.
///
/// It has "method", "params", and usually "id" and 'jsonrpc" members
/// * method is the method to invoke
/// * params is the args. if Map? named args. if List? positional args.
/// * id identifies the response for when it is returned to the sender.
/// * jsonrpc is version for the JSON-RPC specification currently 2.0
class MethodRequest {
  /// [request] is the Map decoded from the incoming chunk of JSON
  late Map<String, dynamic> request;

  /// [ptype] informs us how to handle the object.
  late paramsTypes ptype;

  /// constructor
  MethodRequest(Map<String, dynamic> req) {
    request = req;
    getParamsType();
  }

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
      if (version == null) return JsonRpcV1;
      if (version != JsonRpcV2) {
        throwException(RpcException('Invalid request', -32600));
      }
      return version;
    } on Exception catch (_) {
      // we always get version first, so if request is not proper, fail here
      throw makeExceptionMap(
          RpcException('Invalid request', -32600), JsonRpcV2, null);
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
  Map<String, dynamic>? get namedParams {
    if (ptype == paramsTypes.map) {
      return request['params'];
    }
    return null;
  }

  /// If we have a List of arguments, return the list. Else return null.
  List<dynamic>? get positionalParams {
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
    return null;
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
  void throwException(exception) {
    throw makeExceptionMap(exception, version, request['id']);
  }
}

/// Given a parsed JSON-RPC request and an instance with methods,
/// return a Future with a Map of the result of the instance's method or a
/// Notification object
dynamic jsonRpcDispatch(dynamic request, Dispatcher dispatcher) async {
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
    return makeExceptionMap(e, JsonRpcV2);
  }
  try {
    var value =
        await dispatcher.dispatch(method, rq.positionalParams, rq.namedParams);
    if (id == null) {
      return Notification();
    }
    if (value is RpcException) {
      log('$value', level: fine);
      return makeExceptionMap(value, version, id);
    }
    var resp = <String, dynamic>{'result': value, 'id': id};
    if (version == JsonRpcV2) {
      resp['jsonrpc'] = version;
    }
    if (version == JsonRpcV1) {
      resp['error'] = null;
    }
    return resp;
  } on Exception catch (e) {
    log('$e', level: info);

    return makeExceptionMap(e, version, id);
  }
}

/// Instead of crashing the server, we send the exception back to the client.
Map makeExceptionMap(Object anException, String version, [dynamic id]) {
  var resp = <String, dynamic>{'id': id};
  if (version == JsonRpcV1) {
    resp['result'] = null;
  } else {
    resp['jsonrpc'] = version;
  }
  if (anException is RpcException) {
    resp['error'] = {'code': anException.code, 'message': anException.message};
    if (anException.data != null) {
      resp['error']['data'] = anException.data;
    }
  } else {
    log('$anException', level: info);
    resp['error'] = {'code': -32000, 'message': '$anException'};
  }
  return resp;
}

/// is this a batch request?
bool _shouldBatch(Object obj) {
  log('checking batch', level: finer);
  if (obj is! List) return false;
  if (obj.isEmpty) return false;
  return true;
}

/// Given a JSON-RPC-formatted request string and an instance,
/// return a Future containing a JSON-RPC-formatted response string.
/// Returning null means that nothing should be returned, though some transports
/// (e.g., HTTP) must return something.
Future<String> jsonRpc(String request, Dispatcher dispatcher) async {
  log('$request', level: info);
  try {
    var parsed = parseJson(request);
    var resp = await jsonRpcExec(parsed, dispatcher);
    return encodeResponse(resp);
  } on Exception catch (e) {
    return encodeResponse(makeExceptionMap(e, JsonRpcV2));
  }
}

/// Given a proper parsed JSON-RPC Map or a List, return the proper JSON-RPC Map or List of responses,
/// or a Notification object. The transport will decide how to encode into JSON and UTF-8 for delivery.
/// Depending on transport, Notification objects may not need
/// to be delivered.
Future jsonRpcExec(Object request, Dispatcher dispatcher) async {
  if (request is Map &&
      (request['jsonrpc'] == JsonRpcV2 || request['jsonrpc'] == null)) {
    log('$request', level: info);
    return jsonRpcDispatch(request, dispatcher);
  } else {
    if (request is List && _shouldBatch(request)) {
      var responses = <Future>[];

      for (var rpc in request) {
        if (rpc is Map) {
          rpc['jsonrpc'] = JsonRpcV2;
          dynamic value = jsonRpcDispatch(rpc, dispatcher);
          responses.add(Future(() => value));
        } else {
          responses.add(Future(() => makeExceptionMap(
              RpcException('Invalid request', -32600), '2.0', null)));
        }
        log('in batch: $rpc', level: finer);
      }
      var theList = await Future.wait(responses);

      var output = [];
      for (dynamic item in theList) {
        if (item is! Notification) {
          output.add(item);
        }
      }
      if (output.isNotEmpty) {
        return output;
      }
      return Notification();
      // return output;
    }
    return makeExceptionMap(
        RpcException('Invalid request', -32600), '2.0', null);
  }
}

/// Parse the JSON in a separate method so we might have a distinguishable error
/// It's sometimes (batch) a List of Maps, or sometimes a Map.
dynamic parseJson(aString) {
  try {
    var data = json.decode(aString);
    return data;
  } on JsonUnsupportedObjectError catch (_) {
    throw RpcException('Parse error', -32700);
  } on FormatException catch (_) {
    throw RpcException('Parse error', -32700);
  }
}

/// Encode the result into JSON before sending.
String encodeResponse(response) {
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
