
import 'package:unittest/unittest.dart';
import 'package:start/start.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:mirrors';

class JsonRpcHandler{
  Map request;
  Dispatcher service;
  String version = '2.0';
  var id;
  JsonRpcHandler(request, service){
   this.request = request;
   this.service = new Dispatcher(service);
  }

  getResponse(){
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
                    'error': {'code':-32602, 'message':e.toString()},
                    'id':id};
            }, test: (e)=>e is NoSuchMethodError)
          .catchError((e){
            return {'jsonrpc': version,
              'error': {'code':32000, 'message':e.toString()},
              'id':id};
            },test:(e)=>e is Exception)
                    .catchError((e){
            return {'jsonrpc': version,
              'error': {'code':32001, 'message':e.toString()},
              'id':id};
            })


  ;}




}


class TestServer{
  var server;
  var port = 8075;
  var host = 'localhost';
  var public = 'web';
  var JsonRpcVersion = '2.0';


  TestServer(this.public, this.host, this.port);





  startServer(){

    start(public:public, port:port, host:host).then((app){
      server = app;
      var crossOrigin=true;
      app.post('/echo').listen((request){doJsonRpc(request, new EchoService(), crossOrigin);
      });
      app.options('/echo').listen((request){sendOptionHeaders(request, crossOrigin);
      });
    });

    }

  sendOptionHeaders(request, crossOrigin){
    var response = request.response;
    if (crossOrigin) allowCrossOrigin(response);
    response.status(204);
    response.send('');
  }

  setJsonHeaders(response, [crossOrigin=false]){
    response.set('Content-Type', 'application/json; charset=UTF-8');
    if (crossOrigin) allowCrossOrigin(response);

  }
  allowCrossOrigin(response){
    response.set('Access-Control-Allow-Origin', '*');
    response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");

  }


  doJsonRpc(request, service, [crossOrigin=false]){
    var resp;
    Response response = request.response;
    parseToJson(request)
    .then((parsed){
      //print (parsed);
      var jsonrpc = parsed['jsonrpc'];

      if (jsonrpc == '2.0'){

        var handler = new JsonRpcHandler(parsed, service);
        handler.version = '2.0';
        return handler.getResponse();
      }
      else{
        if (parsed is List){
          if (parsed.length > 0){
            if (parsed[1]['jsonrpc'] == '2.0'){
              return getBatchResponses(parsed, service);
            }
          }
        }
      }
     })

    .then((resp){
      setJsonHeaders(response, crossOrigin);
      if (resp is Notification){
        response.status(204);
        response.send('');
      }
      else{
        response.status(200);
        response.json(resp);
      }

     });
  }

  parseToJson(request){
    var c = new Completer();
    var buffer;
    request.input.listen((data){buffer= data;},
        onDone:(){
          var s = UTF8.decode(buffer);
          new Future.sync((){return JSON.decode(s);})
           .then((resp){c.complete(resp);})
           .catchError((e)
               {throw new JsonRpcError(
                   "Invalid JSON was received by the server", -32700, "$s");})
           ;
            }
      );
    return c.future;
  }

  getBatchResponses(body, svc){
    var responses = {};
    var id = null;
    var method;
    var params;
    var futures = [];
    for (var item in body){
      try{
         method = item['method'];
         params = item['params'];
         id = item['id'];
         if (method == null || params == null)
           throw new FormatException('Missing required element');
      }
      catch (error){
        return {'jsonrpc':JsonRpcVersion,
          'error':{'code':-32600, 'message':'Invalid Request'},
          'id':id};

      };
      var value = svc(method, params);

      if (id !=null){
        responses[id] = value;
        futures.add(value);
      }
    }
    var z = Future.wait(futures).then((_){
      var out = [];
      for (var key in responses.keys){

        out.add({'jsonrpc':JsonRpcVersion, 'result':responses[key],'id':id});
      }
      return out;

    });


  }

  stopServer() => server.stop();

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

main(){

var server = new TestServer('web', '127.0.0.1', 8394);
server.startServer();
print ("Test Server running at http://${server.host}:${server.port}");

//var  t = new Dispatcher(new EchoService());

//t.printme();

//t.dispatch("echo", ["hello"]).then((resp)=>print(resp));


}


class Dispatcher{
  var klass;
  Dispatcher(this.klass);

  dispatch(method, params){

    var nparams;
    var pparams;
    if (method.length > 0 && method[0] == '_'){
      throw new JsonRpcError("Method '$method' is private, if it exists.", -32601);
    };
    var im = reflect(klass);
    var mirror = im.type;
    for (var m in mirror.declarations.keys){
      var meth = MirrorSystem.getName(m);
      if (meth == method){
//        print("method is $m");
        if (params is Map){
          throw new JsonRpcError("Named params not implemented", -32602);
//          var newmap = {};
//          print ("params is $params, ${params.runtimeType}");
//          for (var key in params.keys){
//            print ("key is $key, ${key.runtimeType}");
//            var ky = MirrorSystem.getName(key);
//            print ("ky is $ky, ${ky.runtimeType}");
//            newmap[ky] = params[key];
//          }
//          print(newmap);
//          nparams = newmap;
//          pparams = null;
        }
        else{
          pparams = params;
        }
        return new Future.sync((){
        InstanceMirror t = im.invoke(m, pparams);
        //return(new Future(()=>t.reflectee));
        return t.reflectee;
        });

      }

    }
    throw new JsonRpcError("Method not found: $method.", -32601);
  }
}


class Notification{
}


class RandomException implements Exception{
  String message = 'Random Exception. Boo!';
  RandomException([this.message]);

  toString() => "RandomException: $message";

}


class EchoService{

   _privateMethod(msg)=>"This should be private";

   echo(msg)=>msg;

   reverse([msg="hello"]){
        var buffer = new StringBuffer();
        for(int i=msg.length-1;i>=0;i--) {
          buffer.write(msg[i]);
        }
        return buffer.toString();}

   uppercase(msg) => msg.toUpperCase();

   lowercase(msg) =>msg.toLowerCase();

   asyncwait(msg) {
     return new Future.delayed(new Duration(seconds:5),
         (){return "Worth waiting for? $msg!";});
   }

   throwerror([msg]){
     if (msg == null){
     throw new RandomException("You knew this was going to happen!");
     }else{
       throw new RandomException("$msg");
     }
     return "An Error";
   }

}






















