import 'package:start/start.dart';
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
  TestServer server = new TestServer('127.0.0.1', 8394);
  server.startServer();
  print ("Test Server running at http://${server.host}:${server.port}");
}


class TestServer{
  var server;
  var port = 8394;
  var host = 'localhost';
  var JsonRpcVersion = '2.0';
  var allowCrossOrigin=true;

  TestServer(this.host, [this.port]);

  startServer(){

    
    start(port:port, host:host).then((app){
      server = app;
      app.static('web');
      
      app.post('/sum').listen((request){
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        //request.input gets us the HttpRequest object in start...
        doJsonRpc(request.input, new Sum_fun());
      });

      app.options('/sum').listen((request){
        Response response = request.response;
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        response.status(204);
        response.send('');
      });

      app.post('/friend/:name').listen((request){
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        doJsonRpc(request.input, new Friend(request));
      });
      
      app.options('/friend/:name').listen((request){
        if (allowCrossOrigin) setCrossOriginHeaders(request);
        Response response = request.response;
        response.status(204);
        response.send('');
      });

    });
  }
  setCrossOriginHeaders(request){
    Response response = request.response;
    response.set('Access-Control-Allow-Origin', '*');
    response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
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

