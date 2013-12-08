import 'package:start/start.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';

main(){
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new LogPrintHandler());
  var server = new TestServer('web', '127.0.0.1', 8395);
  server.startServer();
  print ("Test Server running at http://${server.host}:${server.port}");
  print("Example application is at http://${server.host}:${server.port}/rpc_example.html");
  print("(It should also run from Dart Editor.)");
}

class TestServer{
  var server;
  var port = 8395;
  var host = 'localhost';
  var public = 'web';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin=true;

  TestServer(this.public, this.host, [this.port]);

  startServer(){

    start(public:public, port:port, host:host).then((app){
      server = app;
      app.post('/echo').listen((request){doJsonRpc(request, new EchoService(),
          allowCrossOrigin);
      });
      app.options('/echo').listen((request){sendOptionHeaders(request,
          allowCrossOrigin);
      });
    });
  }

  stopServer() => server.stop();

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
     return new Future.delayed(new Duration(seconds:3),
         (){return "<strong>Worth waiting for?</strong> $msg!";});
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

