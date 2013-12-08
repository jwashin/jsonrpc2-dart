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
- Associate the url, the request, jsonrpc, and the class. (we use start.dart for 
this example.)


        import 'package:start/start.dart';
        import 'package:jsonrpc2/jsonrpc_service.dart';
        
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
a single List argument, you need to use something like 3. 1 is usable if the 
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
value will be the JSON-RPC "error" member defined in the JSON-RPC specification.  

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

On the server side, the main interface is a function called `doJsonRpc`. It 
takes a Request object, an instance object, and optionally a boolean of whether
you want to include Cross-Origin headers in the response. This is the function signature.

        doJsonRpc(request, service, [crossOrigin=false]) 
        
The request has a POST body that is parsed from JSON into a method and args. The
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
