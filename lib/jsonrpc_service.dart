library jsonrpc_service;

import 'dart:convert';
import 'dart:async';
import 'dart:mirrors';
import 'package:logging/logging.dart';

final _logger = new Logger('json-rpc');

var JsonRpcVersion = '2.0';

class JsonRpcHandler{
  Map request;
  Dispatcher service;
  String version = JsonRpcVersion;
  var id;

  JsonRpcHandler(request, service){
   this.request = request;
   this.service = new Dispatcher(service);
  }

  makeResponse(){
    var jsonrpc = request['jsonrpc'];
    if (jsonrpc == null) version = '1.0';
    var method = request['method'];
    var params = request['params'];
    if (params == null) params = [];
    id = request['id'];
    if (method == null) throw new FormatException('Missing required element');
    return new Future.sync(()=>
    service.dispatch(method, params))
        .then((value){
            if (id == null){
              return new Notification();
            }
            //print ("value is $value");
            var resp =  {
                    'result':value,
                    'id':id};
                if (version == '2.0'){
                  resp['jsonrpc'] = version;
                }
                if (version == '1.0'){
                  resp['error'] = null;
                }
            return resp;
          })
         .catchError((e){
            return {'jsonrpc': version,
                    'error': {'code':e.code, 'message':e.message},
                    'id':id};
            }, test: (e)=>e is JsonRpcError)

          .catchError((e){
            return {'jsonrpc': version,
                    'error': {'code':-32601, 'message':e.message},
                    'id':id};
            }, test: (e)=>e is MethodNotFoundError)

          .catchError((e){
            return {'jsonrpc': version,
              'error': {'code':32000, 'message':e.toString()},
              'id':id};
            },test:(e)=>e is Exception)

          .catchError((e){
            return {'jsonrpc': version,
              'error': {'code':32001, 'message':e.toString()},
              'id':id};
            });
  }
}

shouldBatch(obj){
  return obj is List && obj.length > 0 && obj[0]['jsonrpc'] == '2.0';
}

doJsonRpc(request, service){
  //var resp;
  //var response = request.response;
  getJsonBody(request)
  .then((parsed){
    //print (parsed);
    if (parsed is Map && parsed['jsonrpc'] == '2.0'){
      var handler = new JsonRpcHandler(parsed, service);
      handler.version = '2.0';
      return handler.makeResponse();
    }
    else{
      if (shouldBatch(parsed))
      {
         var responses = [];
         for (var rpc in parsed){
           var handler = new JsonRpcHandler(rpc, service);
           var value = handler.makeResponse();
           responses.add(new Future(()=>value));

         }
         return Future.wait(responses).then((theList){
            List output = [];
            for (var item in theList){
             if (item is! Notification){
               output.add(item);
             }
            }
            return output;
         });
      }
      }
  })
  .then((resp){sendResponse(request, resp);});

}

sendResponse(request, body){
  var response = request.response;
  setJsonHeaders(response);
  if (body is Notification){
    response.status(204);
    response.send('');}
  else{
    response.status(200);
    _logger.fine("return is $body");
    response.json(body);
  }
}

getJsonBody(request){
  var c = new Completer();
  var buffer;
  request.input.listen((data){buffer= data;},
      onDone:(){
        var s = UTF8.decode(buffer);
        _logger.fine("incoming is $s");
        new Future.sync((){return JSON.decode(s);})
         .then((resp){c.complete(resp);})
         .catchError((e)
             {throw new JsonRpcError("Invalid JSON was received by the server",
                 -32700, "$s");});
      }
    );
  return c.future;
}


class Dispatcher{
  var instance;
  Dispatcher(this.instance);

  dispatch(method, params){

    var nparams;
    var pparams;
    InstanceMirror im = reflect(instance);
    ClassMirror mirror = im.type;
    for (var m in mirror.declarations.keys){
      var meth = MirrorSystem.getName(m);
      if (meth == method){
        if (mirror.declarations[m].isPrivate)
          throw new JsonRpcError("Method '$method' is private.", -32600);
        if (params is Map){
          var newmap = {};
          for (var key in params.keys){
            newmap[new Symbol(key)] = params[key];
          }
          nparams = newmap;
          pparams = [];
        }
        else{
          pparams = params;
        }
        return new Future.sync((){
          InstanceMirror t = im.invoke(m, pparams, nparams);
          return t.reflectee;
        });
      }
    }
    throw new MethodNotFoundError("Method not found: $method.");
  }
}

setJsonHeaders(response){
  response.set('Content-Type', 'application/json; charset=UTF-8');
}


class Notification{
}


class JsonRpcError implements Exception{
  int code;
  var message;
  var data;
  var id;
  JsonRpcError([this.message,this.code,this.id,this.data]);

  toMap(){
    Map map = {
      'code':code,
      'message':message
    };
    if (data != null) map['data'] = data;
    return map;
  }

}

class MethodNotFoundError implements Exception{
  var message;
  MethodNotFoundError([this.message]);
}

class ParseError implements Exception{
  var message;
  ParseError([this.message]);
}
