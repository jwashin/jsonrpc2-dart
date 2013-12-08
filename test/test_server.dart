import 'package:start/start.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';

/*
 * Test server. works with the test client.
 * Run this first.
 */


main(){
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new LogPrintHandler());
  var server = new TestServer('web', '127.0.0.1', 8394);
  server.startServer();
  print ("Test Server running at http://${server.host}:${server.port}");
}

class TestServer{
  var server;
  var port = 8394;
  var host = 'localhost';
  var public = 'web';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin=true;

  TestServer(this.public, this.host, this.port);

  startServer(){

    start(public:public, port:port, host:host).then((app){
      server = app;
      app.post('/sum').listen((request){doJsonRpc(request, new Sum_fun(),
          allowCrossOrigin);
          print ("request is $request");
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

//  stopServer() => server.stop();

}

var global1;


class Sum_fun{


  subtract(minuend, subtrahend) => minuend - subtrahend;

  nsubtract({minuend:0,subtrahend:0}) => minuend - subtrahend;

  add(x,y) => x + y;

  update(args){global1=args;}

  fetchGlobal() => global1;

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


class Friend{
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

