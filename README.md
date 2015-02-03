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
- Call a method on that endpoint, error check, and do something with the result.

 
        import 'package:jsonrpc2/jsonrpc_client.dart';
        proxy = new ServerProxy('http://example.com/some_endpoint');
        proxy.call('some_method',[arg1, arg2])
             .then((returned)=>proxy.checkError(returned))
             .then((result){do_something_with(result);})
             .catchError((error){handle(error);});


- dart:io (command line) is the same, except you import the io client module.


        import 'package:jsonrpc2/jsonrpc_io_client.dart';


Server Basics
-------------

This server library does not know anything about transport; it only associates the JSON-RPC request with an instance
that implements the remote methods, and returns a result. Network and transport issues are outside the scope of this
implementation. That said, using the library should be fairly easy with the transport or framework you are using.


- Import the server library


        import 'package:jsonrpc2/jsonrpc_service.dart';


- Create a class implementing the service methods at an endpoint.
- Either (jsonRpcExec)

  
  1. Decode the request payload to String from (UTF-8) character set.
  2. Parse the JSON from the String.
  3. Using the *jsonRpcExec* method, dispatch the request to an instance of the service class.
  4. Stringify the (usually, a JSONable object) response.
  5. Usually, return the response (in UTF-8).


- or (jsonRpc)


  1. Decode the request payload to String (from UTF-8).
  2. Using the *jsonRpc* method, dispatch the request to an instance of the service class.
  3. Encode the response (to UTF-8) and usually, return it.
    

Client Implementation Details
--------------

This client implementation is for web (HTTP) client only. It shouldn't take much effort 
to revisit this code for other transports. 


        import 'package:jsonrpc2/jsonrpc_client.dart';

On a web server somewhere out there, there is a url that has the methods you need.

To use JSON-RPC with that server, create a proxy to that server at that url.
   
        proxy = new ServerProxy('http://example.com/some_endpoint');

Everyone prefers a proxy setup that is syntactically in tune with the language being used,
for example, in Dart

        proxy.some_method(arg1); //not implemented!

but (trust me on this) in Dart, this requires dart:mirrors and currently increases
javascript code size by a large factor (not actually recently checked). So, instead, we will spell
the above a little bit differently.

        proxy.call('some_method', arg1); //less javascript bloat!

The way to use a given method depends on what the server accepts. It is a client responsibility to
match the server's API.

        1. proxy.call('method_a')
        2. proxy.call('method_b', 'some text')
        3. proxy.call('method_c', [arg1,arg2])
        4. proxy.call('method_d', [[single,list,of,items]])
        5. proxy.call('method_e', {'named_arg_a':23,'named_arg_b':'skiddoo'})
        6. proxy.call('method_b', ['some text'])
        
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
        proxy.send();

`proxy.send();` will batch the calls into a single http request. This may be handy
if the server supports, and you are doing a lot of little calls, and bandwidth 
is at a premium. Yes, you can include notifications in a batch, too.

**NOTE:** Unicode text in methods and data can get wonky if you allow the net to make assumptions about
character sets. A `<meta charset="UTF-8">` tag in the `<head>` of the page can prevent headaches.   


Server Implementation Details
---------------
        
        import 'package:jsonrpc2/jsonrpc_service.dart';

For server side application, the API has two alternative functions, `jsonRpc` and `jsonRpcExec`. 

jsonRpc takes a String JSON-RPC request and an instance object, and ultimately returns a String or null.   

        Future jsonRpc(String request, Object service) 

jsonRpcExec takes a decoded JSON-RPC request (List or Map) and an instance object, and ultimately returns a List or Map or Notification Object.

        Future jsonRpcExec(Object request, Object service)
        
The choice of whether to use jsonRpc or jsonRpcExec depends on the server framework being used. Sometimes, it is easier to obtain the String
representation of the JSON-RPC request, and sometimes, it may be easier to obtain the JSON-RPC request as a parsed JSON object. This JSON-RPC
server implementation is not opinionated about frameworks, or even transports. This implementation should work the same for transports other than
HTTP. 

**NOTE:** If the jsonRpc method returns null, or if the jsonRpcExec method returns a `Notification` object, this indicates that the request was a notification, 
and, according to the JSON-RPC specification, no response should be sent. The transport implementation must choose how to handle this. 

Tests
---------

Tests are in the "test" folder. Particularly, the client and server tests provide usage examples. 

**test_dispatcher.dart** 

- tests the Dispatcher functionality. The dispatcher is the thing that actually associates the method and parameters with the instance object, 
calling the method and returning the result or an error.

**test\_jsonrpc2\_service.dart** 

- tests the jsonRpc and jsonRpcExec functions. Both JSON-RPC 1.0 and JSON-RPC 2.0 specifications are exercised. Tests of the examples in the JSON-RPC 2.0
specification are specifically included.

**rpc_methods.dart**

- provides the server-side API for the client-server tests

**client\_test.dart** with **client_test.html**

- tests web client functionality using unittest/html\_enhanced\_config

**io_client\_test.dart**

- tests command line (dart:io) functionality

**server1\_for\_client_test.dart**

- provides a server for the client test. uses package:start.dart as framework.

**server2\_for\_client_test.dart**

- provides an alternative server for the client test. uses package:http_server as framework.

