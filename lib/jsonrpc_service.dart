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
const String JSONRPC2 = '2.0';

/// version string for v1
const String JSONRPC1 = '1.0';

/// Empty class. We just need to say a response "is" a Notification
class Notification {}

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
  Map<String, dynamic> request;

  /// constructor
  MethodRequest(this.request);

  /// [version] is new in JSON-RPC v2, so handle appropriately
  get version {
    try {
      String version = request['jsonrpc'];
      if (version == null) return JSONRPC1;
      if (version != JSONRPC2) {
        throwError(RpcException('Invalid request', -32600));
      }
      return version;
    } catch (e) {
      // we always get version first, so if request is not proper, fail here
      throw makeExceptionMap(
          RpcException('Invalid request', -32600), JSONRPC2, null);
    }
  }

  /// what method does the client want the server to do?
  get method {
    dynamic method = request['method'];
    if (method is! String) {
      throwError(RpcException('Invalid request', -32600));
    }
    return method;
  }

  /// If we have a Map of named arguments, return the map. Else return null.
  get namedParams {
    var params = request['params'];
    if (params is Map) return params;
    return null;
  }

  /// If we have a List of arguments, return the list. Else return null.
  get positionalParams {
    var params = request['params'];
    if (params is List) return params;
    return null;
  }

  /// id has to be a number or a string, or missing.
  get id {
    dynamic id = request['id'];
    if (id is String || id is num || id == null) {
      return id;
    }
    throwError(RpcException('Invalid Request', -32600));
  }

  /// This is shorthand to make a map of the exception, not actually throwing.
  throwError(exception) {
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

      Map resp = {'result': value, 'id': id};
      if (version == JSONRPC2) {
        resp['jsonrpc'] = version;
      }
      if (version == JSONRPC1) {
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
makeExceptionMap(anException, version, [id]) {
  Map resp = {'id': id};
  if (version == JSONRPC1) {
    resp['result'] = null;
  } else {
    resp['jsonrpc'] = version;
  }
  resp['error'] = {'code': anException.code, 'message': anException.message};

  var data = anException.data;
  if (data != null) {
    resp['error']['data'] = anException.data;
  }
  return resp;
}

/// is this a batch request?
_shouldBatch(obj) {
//  _logger.fine('checking batch');

  if (obj is! List) return false;
  if (obj.length < 1) return false;
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
jsonRpc(String request, Object instance) {
  //_logger.fine(request);
  try {
    var parsed = parseJson(request);
    return jsonRpcExec(parsed, instance).then((resp) => encodeResponse(resp));
  } on RpcException catch (e) {
    return Future.sync(() => encodeResponse(makeExceptionMap(e, JSONRPC2)));
  }
}

///  Given a proper parsed JSON-RPC Map or a List, return the proper JSON-RPC Map or List of responses,
/// or a Notification object. The transport will decide how to encode into JSON and UTF-8 for delivery.
/// Depending on transport, Notification objects may not need
///  to be delivered.
jsonRpcExec(request, Object instance) {
  if (request is Map &&
      (request['jsonrpc'] == JSONRPC2 || request['jsonrpc'] == null)) {
//    _logger.fine('$request');
    return jsonRpcDispatch(request, instance);
  } else {
    if (request is List && _shouldBatch(request)) {
      List<Future> responses = [];

      for (var rpc in request) {
        if (rpc is Map) {
          rpc['jsonrpc'] = JSONRPC2;
          dynamic value = jsonRpcDispatch(rpc, instance);
          responses.add(Future(() => value));
        } else {
          responses.add(Future(() => makeExceptionMap(
              RpcException("Invalid request", -32600), "2.0", null)));
        }
//        _logger.fine('in batch: $rpc');

      }
      return Future.wait(responses).then((theList) {
        List output = [];
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
        makeExceptionMap(RpcException("Invalid request", -32600), "2.0", null));
  }
}

/// Parse the JSON in a separate method so we might have a distinguishable error
/// It's sometimes (batch) a List of Maps, or sometimes a Map.
dynamic parseJson(aString) {
  try {
    var data = json.decode(aString);
    return data;
  } catch (e) {
    throw RpcException("Parse error", -32700);
  }
}

/// Encode the result into JSON before sending.
String encodeResponse(response) {
  if (response is Notification) {
    return null;
  }
  try {
    return json.encode(response);
  } catch (e) {
    return json.encode(makeExceptionMap(
        RpcException(
            "Result was not JSON-serializable (${response['result']}).",
            -32601),
        "2.0",
        null));
  }
}
