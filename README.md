jsonrpc2
========

JSON-RPC is a simple protocol for calling methods on a server and (usually)
getting a response back. The specification is at [http://jsonrpc.org](http://jsonrpc.org).

This package implements the [JSON-RPC 2.0 specification](http://www.jsonrpc.org/specification),
with failover to 1.0 in the server implementation.
 
Client Basics
-------------

- Import the client library.
- Create a ServerProxy with the url for the desired endpoint.
- Call a method on that endpoint, check for error, and do something with the result.

 
        import 'package:jsonrpc2/jsonrpc_client.dart';
        proxy = new ServerProxy('http://example.com/some_endpoint');
        proxy.call('some_method',[arg1, arg2])
             .then((returned)=>proxy.checkError(returned))
             .then((result){do_something_with(result);})
             .catchError((error){handle(error);});

Server Basics
-------------

- Import the server library
- Create a class implementing the service methods for a particular endpoint.
- Either 
  1. Decode the request to String from (UTF-8) character set.
  2. Parse the JSON from the String.
  3. Using the *jsonRpcExec* method, dispatch the request to an instance of the service class.
  4. Stringify the (usually, a JSONable object) response.
  5. Usually, return the response (in UTF-8).
- or
  1. Decode the request to String (from UTF-8).
  2. Using the *jsonRpc* method, dispatch the request to an instance of the service class.
  3. Encode the response (to UTF-8) and usually, return it.
    
- Associate the server end-point, the string, jsonrpc, and the class. (we use start.dart for 
this example.)


        import 'package:start/start.dart';
        import 'package:jsonrpc2/jsonrpc_service.dart';
        import 'dart:async';
        import 'dart:convert';
        
        doJsonRpc(request, instance){
          var rq = request.input;
          Future<String> resp = UTF8.decodeStream(rq).then((stream) => jsonRpc(stream,instance));
          return resp;
        }
        
        class MyService{
           some_method(arg1,arg2)=>return_something_with(arg1,arg2);
        }
        
        class MyServer{
          [...]
          startServer(){
            start(public:public, port:port, host:host).then((app){
              server = app;
              app.post('/endpoint1')
                  .listen((request){doJsonRpc(request, new MyService());
              });
            });
          }
        }

Client Details
--------------

        import 'package:jsonrpc2/jsonrpc_client.dart';

On a web server somewhere out there, there is a url that has the methods you need.

To use JSON-RPC with that server, create a proxy to that server at that url.
   
        proxy = new ServerProxy('http://example.com/some_endpoint');

Everyone prefers a proxy setup that is syntactically in tune with the language being used,
for example, in Dart

        proxy.some_method(arg1); //not implemented!

but (trust me on this) in Dart, this requires dart:mirrors and currently increases
javascript code size by a large factor (six, recently). So, instead, we will spell
the above a little bit differently.

        proxy.call('some_method', arg1); //less javascript bloat!

The way to use a given method depends on what the server accepts.

        1. proxy.call('some_method')
        2. proxy.call('some_method', 'some text')
        3. proxy.call('some_method', [arg1,arg2])
        4. proxy.call('some_method', [[single,list,of,items]])
        5. proxy.call('some_method', {'namedarg_a':23,'namedarg_b':'skiddoo'})
        6. proxy.call('some_method', ['some text'])
        
are all valid possible formulations. Note that 2 and 6 are equivalent. The second argument 
to the call is required by protocol to be a List or Map, and will be enclosed in 
a List in the background if not provided. Note that if the server's method has 
a single List argument, you need to use something like 4. 1 is usable if the 
method requires no arguments, or if all arguments are optional. Variables need to 
be JSON serializable; in general, booleans, strings, numbers, Lists, Maps, 
combinations of these, or objects with a toJson() method. A call will generally
return a single thing decoded from JSON like a null, string, number, List, or Map.
The JSON-RPC 2.0 specification does not support a combination of positional and
named arguments, though it may be possible by extension to the specification (and 
deliberately not implemented here yet). 

Usually, you will want to do something with the returned value. So, the usual
call uses asynchronous methodology and will look like

        proxy.call('some_method',[arg1, arg2])
             .then((returned)=>proxy.checkError(returned))
             .then((result){do_something_with(result);})
             .catchError((error){handle(error);});

`proxy.checkError(value)` just throws the returned exception in a place where you
can handle it with .catchError. If you want to do something else, the returned
error will be the JSON-RPC "error" member defined in the JSON-RPC specification.  

After a ServerProxy is created, you may set a timeout in milliseconds on any
succeeding HTTP request.

        proxy = new ServerProxy('http://example.com/some_endpoint');
        proxy.timeout = 3000;
        proxy.call('some_method',[arg1, arg2])
             .then((returned)=>proxy.checkError(returned))
             .then((result){do_something_with(result);})
             .catchError((error){handleTimeout(error);},
                  test:(error)=>error is TimeoutException);
             .catchError((error){handle(error);});

If you do not want or need the return value (The default return is null in most 
languages), you may send a notification.

        proxy.notify('some_method', args...)
        
Error-handling on notifications is, well, fraught. Use notifications if you really
really don't care. It'll usually get there, but don't expect to get much feedback
when something fails.
        
JSON-RPC 2.0 supports a "batch" technique. For this, use BatchServerProxy

        proxy = new BatchServerProxy(url); 
        proxy.call('some_method').then(something_with_this_value...
        proxy.call('some_other_method', 'some text').then(something else...
        [...]
        proxy.send()

`proxy.send()` will batch the calls into a single http request. This may be handy
if the server supports, and you are doing a lot of little calls, and bandwidth 
is at a premium. Yes, you can include notifications in a batch, too.


Server Overview
---------------
        
        import 'package:jsonrpc2/jsonrpc_service.dart';

On the server side, the main interface is a function called `jsonRpc`. It 
takes a String, and an instance object.   

        jsonRpc(String request, Object service) 

As of 0.90, this interface has become less opinionated, so it should work with pretty much any backend. 
It takes an unencoded String and an instance of a class. It usually returns a Future<String> with the properly UTF-8 and
JSON encoded response, though it may return null if nothing needs to be returned, in the case of a notification.

This requires a bit more work to make the function work with your backend. For HTTP, the desired string for the 
function will usually be the UTF-8 decoded body of the HTTP POST. Since HTTP requires a response, a null or empty body will suffice; for
other protocols, returning nothing may be desired. 
 




 request has a POST body that is parsed from JSON into a method and args. The
service is an instance of a class with methods that are available at this url. 
There is a Dispatcher involved that interrogates the code for the service and 
invokes the methods with the params. The method gets called, some error handling
occurs, and a response is returned.  This code probably only works with 
start.dart, but probably could work with other Dart servers with little effort. 
You may make the service instance reflect the url or persistence scheme by 
creating the instance using those parameters.   

Example
--------------

There is a polymer-based client and start.dart-based server pair in the "example"
folder. For best results, run the server first. Cross-origin headers are in-place
so `rpc_example.html` should work directly in Dart Editor/Dartium.

Tests
---------

Tests are in the "test" folder. Run the server first for best results.
Cross-origin headers are in-place so `test_client.html` should run directly in Dart 
Editor/Dartium.
