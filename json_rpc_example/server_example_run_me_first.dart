import 'package:start/start.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';

main(){
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new LogPrintHandler());
  var server = new TestServer('127.0.0.1', 8395);
  server.startServer();
  print ("Test Server running at http://${server.host}:${server.port}");
  print("Example application is at http://${server.host}:${server.port}/rpc_example.html");
  print("(It should also run from Dart Editor.)");
}

class TestServer{
  var port = 8395;
  var host = 'localhost';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin = true;

  TestServer(this.host, [this.port]);

  startServer(){

    start(port:port, host:host).then((Server app){
      
      app.static('web');
      
      app.post('/echo').listen((Request request){
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request.input, new EchoService());
      });
      
      app.options('/echo').listen((request){
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        var response = request.response;
        response.status(204);
        response.send('');
      });
      
    });
  }

  setCrossOriginHeaders(request){
    var response = request.response;
    response.set('Access-Control-Allow-Origin', '*');
    response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  }
}


class EchoService{

   _privateMethod(msg)=>"This should be private";

   echo(msg)=>msg;

   reverse([msg="hello"]) => new String.fromCharCodes(
       new List.from(msg.codeUnits).reversed);

   uppercase(msg) => msg.toUpperCase();

   lowercase(msg) =>msg.toLowerCase();

   asyncwait(msg) {
     return new Future.delayed(new Duration(seconds:3),
         (){return "<b>Worth waiting for?</b> $msg!";});
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


class RandomException implements Exception{
  var message='Random Exception. Boo!';
  RandomException([this.message]);

  toString() => "RandomException: $message";
}

