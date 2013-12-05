import 'package:start/start.dart';
import 'dart:async';
import '../lib/jsonrpc_service.dart';

//import 'package:jsonrpc2/jsonrpcservice.dart';


main(){
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


    });
  }

  stopServer() => server.stop();

}


class SumService{
  subtract(minuend,subtrahend){
    return minuend - subtrahend;
  }
  add(x,y){
    return x + y;
  }
  update(args){
    return args;
  }
  summation(args){
    var sum = 0;
    for (var value in args){
      sum += value;
    }
    return sum;
  }
  notify_hello(args){
    return args;
  }
  get_data(){
    return ['hello', 5];
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


class RandomException implements Exception{
  var message='Random Exception. Boo!';
  RandomException([this.message]);

  toString() => "RandomException: $message";
}

