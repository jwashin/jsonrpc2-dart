library jsonrpc_service;

import 'dart:convert';
import 'dart:async';

import 'package:logging/logging.dart';
import 'dart:io';

import 'dispatcher.dart';

final _logger = new Logger('json-rpc');

var JsonRpcVersion = '2.0';

/**
 * Take a Map, decoded from a JSON-RPC request, and send the 
 * method and parameters to a service object.
 * 
 * 
 * 
 */


class StandardJsonRpcMethodRequest{
  Map dict;
  
  StandardJsonRpcMethodRequest(this.dict);
  
  get version{
    String version = dict['jsonrpc'];
    if (version == null) return '1.0';
    return version;
  }
  
  get method{
    String method = dict['method'];
    if (method == null) throw new FormatException('Invalid request; missing "method"');
    return dict['method'];
  }
  
  get namedParams{
    var params = dict['params'];
    if (params is Map) return params;
    return null;
  }
  
  get positionalParams{
    var params = dict['params'];
    if (params is List) return params;
    return null;
  }
  
  get id{
    return dict['id'];
  }
  
}


class JsonRpcHandler {
  Map request;
  Object instanceWithMethods;
  JsonRpcHandler(this.request, this.instanceWithMethods);
  
  createResponse(requestData) {
    var rq = new StandardJsonRpcMethodRequest(requestData);
    var version = rq.version;
    var id = rq.id;
    var method = rq.method;
    
    if (method == null) throw new FormatException('Missing required element');
    return new Future.sync(() => new Dispatcher(instanceWithMethods).dispatch(method,
        rq.positionalParams, rq.namedParams)).then((value) {
      if (id == null) {
        return new Notification();
      }
      //print ("value is $value");
      var resp = {
        'result': value,
        'id': id
      };
      if (version == '2.0') {
        resp['jsonrpc'] = version;
      }
      if (version == '1.0') {
        resp['error'] = null;
      }
      return resp;
    }).catchError((e) {
      return {
        'jsonrpc': version,
        'error': {
          'code': e.code,
          'message': e.message
        },
        'id': id
      };
    }, test: (e) => e is JsonRpcError).catchError((e) {
      return {
        'jsonrpc': version,
        'error': {
          'code': -32601,
          'message': e.message
        },
        'id': id
      };
    }, test: (e) => e is MethodNotFoundError).catchError((e) {
      return {
        'jsonrpc': version,
        'error': {
          'code': -32600,
          'message': e.toString()
        },
        'id': id
      };
    }, test: (e) => e is PrivateError).catchError((e) {
      return {
        'jsonrpc': version,
        'error': {
          'code': 32000,
          'message': e.toString()
        },
        'id': id
      };
    }, test: (e) => e is Exception).catchError((e) {
      return {
        'jsonrpc': version,
        'error': {
          'code': 32001,
          'message': e.toString()
        },
        'id': id
      };
    });
  }
}

_shouldBatch(obj) {
  _logger.fine('checking batch');
  return obj is List && obj.length > 0 && obj[0]['jsonrpc'] == '2.0';
}

doJsonRpc(HttpRequest request, Object instance) {
  //var resp;
  //var response = request.response;
  getJsonBody(request).then((parsed) {
    //print (parsed);
     
    
    if (parsed is Map && parsed['jsonrpc'] == '2.0') {
      var handler = new JsonRpcHandler(parsed, instance);
      return handler.createResponse(parsed);
    } else {
      
      if (_shouldBatch(parsed)) {
        var responses = [];
        for (var rpc in parsed) {
          _logger.fine('batch: $rpc');
          var handler = new JsonRpcHandler(rpc, instance);
          var value = handler.createResponse(rpc);
          responses.add(new Future(() => value));

        }
        return Future.wait(responses).then((theList) {
          List output = [];
          for (var item in theList) {
            if (item is! Notification) {
              output.add(item);
            }
          }
          return output;
        });
      }
    }
  }).then((resp) {
    sendResponse(request, resp);
  });

}

sendResponse(HttpRequest request, body) {
  var response = request.response;
  setJsonHeaders(response);
  if (body is Notification) {
    response.statusCode = 204;
  } else {
    response.statusCode = 200;
    _logger.fine("return is $body");
    response.write(JSON.encode(body));
  }
  response.close();
}

getJsonBody(HttpRequest request) {

  Future<String> c = UTF8.decodeStream(request).then((s) => JSON.decode(s)
      ).catchError((e) => throw new JsonRpcError(
      "Invalid JSON was received by the server", -32700, ""));
  return c;
}

setJsonHeaders(HttpResponse response) {
  response.headers.contentType = new ContentType('application', 'json', charset:
      "utf-8");
}


class Notification {
}


class JsonRpcError implements Exception {
  int code;
  var message;
  var data;
  var id;
  JsonRpcError([this.message, this.code, this.id, this.data]);

  toMap() {
    Map map = {
      'code': code,
      'message': message
    };
    if (data != null) map['data'] = data;
    return map;
  }

}

class ParseError implements Exception {
  var message;
  ParseError([this.message]);
}
