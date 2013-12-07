import 'package:start/start.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import '../lib/jsonrpc_service.dart';

//import 'package:jsonrpc2/jsonrpcservice.dart';

main(){
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new LogPrintHandler());
  var server = new TestServer('web', '127.0.0.1', 8394);
  server.startServer();
  print ("Test Server running at http://${server.host}:${server.port}");
}

class TestServer{
  var server;
  var port = 8080;
  var host = 'localhost';
  var public = 'web';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin=true;

  TestServer(this.public, this.host, this.port);

  startServer(){

    start(public:public, port:port, host:host).then((app){
      server = app;
      app.post('/echo').listen((request){doJsonRpc(request, new EchoService(),
          allowCrossOrigin);
      });
      app.options('/echo').listen((request){sendOptionHeaders(request,
          allowCrossOrigin);
      });

      app.post('/sum').listen((request){doJsonRpc(request, new Sum_fun(),
          allowCrossOrigin);
      });
      app.options('/sum').listen((request){sendOptionHeaders(request,
          allowCrossOrigin);
      });

      app.post('/friend/:name').listen((request){doJsonRpc(request, new Friend(request),
          allowCrossOrigin);
      });
      app.options('/friend/:name').listen((request){sendOptionHeaders(request,
          allowCrossOrigin);
      });

    });
  }

  stopServer() => server.stop();

}


class Sum_fun{

  subtract(minuend, subtrahend) => minuend - subtrahend;

  nsubtract({minuend:0,subtrahend:0}) => minuend - subtrahend;

  add(x,y) => x + y;

  update(args) => args;

  summation(args){
    var sum = 0;
    for (var value in args){
      sum += value;
    }
    return sum;
  }

  _private() => "Not public; you can't see this!";

  notify_hello(args){
    return args;
  }
  get_data(){
    return ['hello', 5];
  }

  oopsie(){
    throw new RandomException('Whoops!');
  }

  ping(){
    return true;
  }
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
     return new Future.delayed(new Duration(seconds:2),
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


class Friend{
  Request request;
  String name;
  Friend(request){
   name = request.param('name');
  }

  hello() => "Hello from $name!";

}


class RandomException implements Exception{
  var message='Random Exception. Boo!';
  RandomException([this.message]);

  toString() => "RandomException: $message";
}

