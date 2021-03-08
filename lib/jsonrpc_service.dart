/// [jsonrpc_service] is a server-side implementation of JSPN-RPC v2.
///
///
library jsonrpc_service;

import 'dart:convert';
import 'dart:async';

import 'package:logging/logging.dart';

import 'rpc_exceptions.dart';
import 'dispatcher.dart';

final _logger = Logger('json-rpc');

/// Version string for JSON-RPC v2
const JsonRpcV2 = '2.0';

/// version string for v1
const JsonRpcV1 = '1.0';

/// Empty class. We just need to say a response "is" a Notification
class Notification {}

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
  late paramsTypes ptype;

  /// constructor
  MethodRequest(Map<String, dynamic> req) {
    request = req;
    getParamsType();
  }

  /// It's easier to decide how to make the method request if we decide
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
        throwError(RpcException('Invalid request', -32600));
      }
      return version;
    } catch (e) {
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
      throwError(RpcException('Invalid request', -32600));
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
    throwError(RpcException('Invalid Request', -32600));
  }

  /// This is shorthand to make a map of the exception, not actually throwing.
  void throwError(exception) {
    throw makeExceptionMap(exception, version, request['id']);
  }
}

/// Given a parsed JSON-RPC request and an instance with methods,
/// return a Future with a Map of the result of the instance's method or a
/// Notification object
Future<dynamic> jsonRpcDispatch(request, instance) {
  try {
    var rq = MethodRequest(request);
    var version = rq.version;
    var id = rq.id;
    var method = rq.method;

    return Future.sync(() => Dispatcher(instance)
        .dispatch(method, rq.positionalParams, rq.namedParams)).then((value) {
      if (id == null) {
        return Notification();
      }

      if (value is RpcException) {
//        _logger.fine('$value');
        return makeExceptionMap(value, version, id);
      }

      var resp = {'result': value, 'id': id};
      if (version == JsonRpcV2) {
        resp['jsonrpc'] = version;
      }
      if (version == JsonRpcV1) {
        resp['error'] = null;
      }
      return resp;
    }).catchError((e) {
//      _logger.fine('$e');
      return makeExceptionMap(e, version, id);
    });
  }

  /// it's ugly, but we really intend to catch every error here
  catch (e) {
    _logger.fine('$e');
    return Future.sync(() => e);
  }
}

/// Instead of crashing the server, we send the exception back to the client.
Map makeExceptionMap(Object anException, String version, [dynamic id]) {
  var resp = {'id': id};
  if (version == JsonRpcV1) {
    resp['result'] = null;
  } else {
    resp['jsonrpc'] = version;
  }
  if (anException is Error) {
    _logger.fine('$anException');
    resp['error'] = {'code': -32000, 'message': '$anException'};
    return resp;
  }
  var exception = anException as RpcException;

  resp['error'] = {'code': exception.code, 'message': exception.message};

  var data = exception.data;
  if (data != null) {
    resp['error']['data'] = anException.data;
  }
  return resp;
}

/// is this a batch request?
bool _shouldBatch(obj) {
//  _logger.fine('checking batch');

  if (obj is! List) return false;
  if (obj.isEmpty) return false;
//  for (dynamic item in obj) {
//    if (item is! Map) {
//      return false;
//    } else if (item is Map && !item.containsKey('method')) return false;
//  }
  return true;
}

/// Given a JSON-RPC-formatted request string and an instance,
/// return a Future containing a JSON-RPC-formatted response string or null.
///  Null means that nothing should be returned, though some transports must return something.
Future<String> jsonRpc(Object request, Object instance) {
  if (request is String) {
    //_logger.fine(request);
    try {
      var parsed = parseJson(request);
      return jsonRpcExec(parsed, instance).then((resp) => encodeResponse(resp));
    } on RpcException catch (e) {
      return Future.sync(() => encodeResponse(makeExceptionMap(e, JsonRpcV2)));
    }
  } else if (request is Map) {
    try {
      return jsonRpcDispatch(request, instance)
          .then((resp) => encodeResponse(resp));
    } on RpcException catch (e) {
      return Future.sync(() => encodeResponse(makeExceptionMap(e, JsonRpcV2)));
    }
  } else {
    return Future.sync(() => encodeResponse(makeExceptionMap(
        RpcException(
            'Invalid Parameters. Must be JSON-RPC string or Map. got {request.type}.'),
        JsonRpcV2)));
  }
}

///  Given a proper parsed JSON-RPC Map or a List, return the proper JSON-RPC Map or List of responses,
/// or a Notification object. The transport will decide how to encode into JSON and UTF-8 for delivery.
/// Depending on transport, Notification objects may not need
///  to be delivered.
Future jsonRpcExec(Object request, Object instance) {
  if (request is Map &&
      (request['jsonrpc'] == JsonRpcV2 || request['jsonrpc'] == null)) {
//    _logger.fine('$request');
    return jsonRpcDispatch(request, instance);
  } else {
    if (request is List && _shouldBatch(request)) {
      var responses = <Future>[];

      for (var rpc in request) {
        if (rpc is Map) {
          rpc['jsonrpc'] = JsonRpcV2;
          dynamic value = jsonRpcDispatch(rpc, instance);
          responses.add(Future(() => value));
        } else {
          responses.add(Future(() => makeExceptionMap(
              RpcException('Invalid request', -32600), '2.0', null)));
        }
//        _logger.fine('in batch: $rpc');

      }
      return Future.wait(responses).then((theList) {
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
      });
    }
    return Future.sync(() =>
        makeExceptionMap(RpcException('Invalid request', -32600), '2.0', null));
  }
}

/// Parse the JSON in a separate method so we might have a distinguishable error
/// It's sometimes (batch) a List of Maps, or sometimes a Map.
dynamic parseJson(aString) {
  try {
    var data = json.decode(aString);
    return data;
  } catch (e) {
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
  } catch (e) {
    return json.encode(makeExceptionMap(
        RpcException(
            'Result was not JSON-serializable (${response['result']}).',
            -32601),
        '2.0',
        null));
  }
}
