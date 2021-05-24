jsonrpc2
========

This package is a kit of pure Dart utility classes and methods for JSON-RPC clients and servers in Dart. These need to be extended, to provide the actual transport for the JSON-RPC messages. Instructions, examples, and tests are provided.

JSON-RPC is a JSON unicode protocol for calling methods on a remote server and getting responses back. The specification is at [http://jsonrpc.org](http://jsonrpc.org).

# Usage:

JSON-RPC is divided into client and server responsibilities. This package does the fussy part of the [JSON-RPC 2.0 specification](http://www.jsonrpc.org/specification), with failover to 1.0 for the server. 

## Client
Like the specification, the client implementation does not specify transport details for the client. One needs to create a class extended from ServerProxyBase to actually send method requests and receive responses. Examples are provided for common use cases.

Once instantiated, a client proxy may call methods on the server using the **call** method of the proxy. It is a client responsibility to match the server's API.

```dart
Future<dynamic> call(String method, [dynamic params])
```
- proxy.call('method_a') // no args
   
- proxy.call('method_b', [arg1]) // one arg 

- proxy.call('method_c', arg1) // one arg, arg is neither [] nor {}

- proxy.call('method_d', [arg1, arg2, arg3]) // more than one arg

- proxy.call('method_e', [[item1, item2, item3, item4]]) // one arg, arg is [] 

- proxy.call('method_f', [{'a': 'hello', 'b': 'world'}]) // one arg, arg is {} 

- proxy.call('method_g', {'name_a':value_a,'name_b':value_b}) // named args
   

### Creating a Client (ServerProxy) Class

1. Import the client library.

```dart
import 'package:jsonrpc2/jsonrpc2.dart';
import 'package:rpc_exceptions/rpc_exceptions.dart';
```

2. Create a server proxy class, extended from ServerProxyBase, initialized with a server resource. resource may be used in the **transmit** method.
```dart 
class MyServerProxy extends ServerProxyBase {
  /// constructor. extend this, if you want, then superize properly
  MyServerProxy(resource) // resource can be anything
      : super(resource);
}
```

3.  In your server proxy class override the **transmit** method, which sends a String to the remote JSON-RPC server and returns the returned string. You may use the server resource identified earlier.
```dart
/// Return a Future with the JSON-RPC response
  @override
  Future<String> transmit(String package) async {

    // for example, create a transport using a string resource name. 
    var transport = ExampleTransport(resource);

    // send the package using the transport, and await response
    var response = await transport.send(package);

    // return the String response for further processing
    return response;
  }
```
4.  Use an instance of your server proxy to **call** a method on that endpoint, and do something with the result. 

```dart
  /// Update login token 
  login (String username, String password) async {
    var remoteLogin = MyServerProxy('https://example.org/do_login');
    // Get the login token. This may throw an exception.
    var token = await remoteLogin.call('login',['fische','gefilte']);
    // If you have mirrored the server API in your proxy, 
    // token = await remoteLogin.login('fische','gefilte);  // nice!
    if (token.isNotEmpty){
    // use the token
    };
  }
```

### Example JSON-RPC Client using [http.dart](https://pub.dev/packages/http) from pub.dev.

[http_client](example/jsonrpc_http_client.dart)

```dart
import 'package:http/http.dart' as http;
import 'package:jsonrpc2/jsonrpc2.dart';
import 'package:rpc_exceptions/rpc_exceptions.dart';

// HttpServerProxy is a JSON-RPC client using http.dart.
//
// Extend ServerProxyBase by providing the transmit method.
class HttpServerProxy extends ServerProxyBase {
  /// customHeaders, for jwts and other niceties
  Map<String, String> customHeaders;

  /// constructor. superize properly
  ServerProxy(String url, [this.customHeaders = const <String, String>{}])
      : super(url);

  /// Return a Future with the JSON-RPC response
  @override
  Future<String> transmit(String package) async {

    var headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (customHeaders.isNotEmpty) {
      headers.addAll(customHeaders);
    }

    // useful for debugging!
    // print(package);
    var resp =
        await http.post(Uri.parse(resource), body: package, headers: headers);

    var body = resp.body;
    if (resp.statusCode == 204 || body.isEmpty) {
      return ''; // we'll return an empty string for null response
    } else {
      return body;
    }
  }
  // optionally, but recommended: mirror remote API
  // Future echo(aThing) async {
  //   var resp = await call('echo', [aThing]);
  //   return resp;
  // }
}

main() async {
  proxy = HttpServerProxy('http://example.com/some_endpoint');
  var result='';
  try{
  result = await proxy.call('some_method',[arg1, arg2]);
  on RpcException catch(e){
        doSomethingWithException(e);
  }
  doSomethingWith(result);
}
```

## Server Basics
The server library decodes JSON-RPC request packages and allows association of the JSON-RPC request with an object that calls the remote methods, and returns a result. Network and transport issues are outside the scope of this implementation. That said, this is designed to be fairly easy with the transport or framework you are using. It's just a method that uses a dispatcher. In a server implementation, make an endpoint for a particular Dispatcher, and use these utilities to decode the request and package the result.

This server implementation uses a Dispatcher concept. Essentially, a dispatcher is an instantiated class that contains the remote methods to be called at an endpoint. The server accepts a call request, deconstructs the JSON, then creates a dispatcher to call the method on that instance, with the requested parameters. The returned value (or exception) is reconstructed into JSON as a response and sent back to the client.

- Import the server library
```dart
import 'package:jsonrpc2/jsonrpc2.dart';
```

- Create a class implementing the service methods at an endpoint. Just about any class with methods will do. [example api class](example/rpc_methods.dart), and import it, if it is in a different file.
```dart
import 'rpc_methods.dart';
```
- make a method for your listener that accepts JSON-RPC strings from the client. This string may be, for example, the body of a HTTP POST. Within this method, use this library's **jsonRpc** method to associate the string with a **Dispatcher**. The **jsonRpc** method will ultimately produce a string, which should be sent back to the client as a response.

The **jsonRpc** method has the following signature.

```dart
Future<String> jsonRpc(String request, Dispatcher dispatcher)
```
-- **request** is a JSON string, the JSON-RPC request from the client.

-- a **dispatcher** meets the [Dispatcher interface](https://pub.dev/packages/rpc_dispatcher). See, for example:
- [mirror_dispatcher](https://pub.dev/packages/mirror_dispatcher)

- [reflector_dispatcher](https://pub.dev/packages/reflector_dispatcher)

These two implementations work about the same. Mirror_dispatcher is easier to use, but it uses dart:mirrors, which cannot work inside flutter. There may be other trade-offs.









  1. Decode the request payload to String (from UTF-8).
  2. Using the *jsonRpc* method, dispatch the request to an instance of the service class.
  3. Encode the response (to UTF-8) and usually, return it.
    

Client Implementation Details
--------------

There are two client implementations provided here, one for dart in web pages, and one using dart:io library.  
These client implementations work mostly the same, and are for web (HTTP) client only, but
it shouldn't take much effort to repurpose this code for other transports. 

For a web page client (using dart:http),  


        import 'package:jsonrpc2/jsonrpc_client.dart';


or, for a web client in a "console" script (using dart:io), 


        import 'package:jsonrpc2/jsonrpc_io_client.dart';


On a web server somewhere out there, there is a url that has the methods you need.

To use JSON-RPC with that server, create a proxy to that server at that url.
   
        proxy = ServerProxy('http://example.com/some_endpoint');

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
a List in the background if only a single argument is provided. Note that if the server's method has 
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

        proxy = BatchServerProxy(url); 
        proxy.call('some_method').then(something_with_this_value...
        proxy.call('some_other_method', 'some text').then(something else...
        [...]
        proxy.send();

`proxy.send();` will batch the calls into a single http request. This may be handy
if the server supports, and you are doing a lot of little calls, and bandwidth 
is at a premium. Yes, you can include notifications in a batch, too. You probably cannot
use async/await with this formulation. There's nothing forbidding it. It just doesn't
make sense.

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

**Application Exceptions**

For the JSON-RPC methods in server-side application code, all Exceptions have been explicitly caught by this implementation so that 
the error may be sent on to the client. Any exception that is not TypeError or NoSuchMethodError will be returned, by default, as 
RuntimeError, code -32000.  As a side-effect of the way that the Dispatcher detects InvalidParameters, TypeErrors in application code will
return, by default, an InvalidParameters exception. It may be necessary to catch TypeErrors that may arise in your application code and 
re-throw them as RuntimeExceptions, and this probably will work only if the server is running in "checked mode". 

To send meaningful exceptions and error codes to the client,

        import 'package:jsonrpc2/rpc_exceptions.dart' show RuntimeException;

The RuntimeException constructor wants a message, a code and, optionally, JSON-serializable data . The message can be any String. 
The code is an integer that is not in the range -32768 to -32000. For your application, you are free to create an API of error codes
and messages that make sense for client error handling. RuntimeExceptions, when thrown in server-side JSON-RPC methods, behave just like 
any other Exception, but they are transmitted, when thrown, to inform the client of application exceptions.


Tests
---------

Tests are in the "test" folder. Particularly, the client and server tests provide usage examples. They are standard test.dart tests. The client tests need a server, so one is provided. To run all the tests, 

        $ dart servers_for_testing/server2_for_client_test.dart &
        $ pub run test
        00:01 +15: All tests passed! 

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

- tests console script (dart:io) functionality

**server2\_for\_client_test.dart**

- provides a server for the client tests. uses package:http_server as framework.

