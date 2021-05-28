jsonrpc2
========

This package is a kit of pure Dart utility classes and methods for JSON-RPC clients and servers in Dart. You just provide the actual communications protocols. Instructions, examples, and tests are provided.

JSON-RPC is a JSON unicode grammar for calling methods on a remote server and getting responses back. The specification is at [https://jsonrpc.org](https://jsonrpc.org).

# Usage:

JSON-RPC is divided into client and server responsibilities. This package does the fussy part of the [JSON-RPC 2.0 specification](https://www.jsonrpc.org/specification), with failover to 1.0 for the server. 

## Client
Like the specification, the client implementation does not specify transport details for the client. One needs to create a class extended from ServerProxyBase to actually send method requests and receive responses. Look in [Examples](example) for common use cases, or see below for step-by-step instructions.

Once instantiated, a client proxy may call methods on the server using the **call** method of the proxy, and receive a response. It is a client responsibility to match the server's API.

```dart
Future<dynamic> call(String method, [dynamic params])
```
- proxy.call('method_a') // no args
   
- proxy.call('method_b', [arg1]) // one arg, general case 

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
/// Return a Future with the JSON-RPC response. Use a real transport,
/// like package:http instead of imaginary ExampleTransport.
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
  /// get the item in the server's list that follows this item
  MyViewItem nextItem (String lastItemId) async {
    var remoteSite = MyServerProxy('https://example.org/');
    
    var item = await remoteSite.call('nextItem', lastItemId);
    // Or, if you have mirrored the server API in your proxy, 
    // var nextItem = await remoteSite.nextItem(lastItemId);  // nice!
    return MyViewItem.fromJson(item);

  }
```
### Example JSON-RPC Client using [http.dart](https://pub.dev/packages/http) from pub.dev: [http_client](example/jsonrpc_http_client.dart)

[more examples](example)

### Client Notifications
JSON-RPC supports the concept of notifications. A **notification** is for calling a method on the remote server without requiring a response. 
Do this by calling a remote method using **notify** instead of **call** with your client (or server proxy). 

```dart
void notify(String method, [dynamic params])
```
The JSON-RPC specification requires that no there will be no response to notifications. Some transports, like HTTP, always return a response. You may handle this appropriately in the overridden **transmit** method of your
server proxy. For HTTP, my examples return an empty string or 204 status from the server, and the server proxy returns an empty string. Regardless, the **notify** method of a ServerProxyBase does not return anything. 

### Batch Requests
JSON-RPC V2 supports batching several method requests into a single transport request.

To support this on a client, after you have created your client (server proxy) class, do the following

1. Create a client BatchServerProxy class, using your client ServerProxy class as instance proxy. 
```dart
/// see the documentation in [BatchServerProxyBase]
class MyBatchServerProxy extends BatchServerProxyBase {
  @override
  dynamic proxy;

  /// constructor
  MyBatchServerProxy(String url, [customHeaders = const <String, String>{}]) {
    proxy = MyServerProxy(url, customHeaders);
  }
}
```
2.  Using your BatchServerProxy class, **call** an arbitrary number methods, like you are using the normal proxy. Then **send** the methods as a batch.

```dart
/// call a bunch of methods to return three items
  List threeItems () async {
    var remoteSite = MyBatchServerProxy('https://example.org/');
    
    var item1 = remoteSite.call('firstItem');
    var item2 = remoteSite.call('secondItem');
    remoteSite.notify('happyLog', 'I hope the last item comes through!');
    var item3 = remoteSite.call('lastItem');
    // Or, if you have mirrored the server API in your proxy, 
    // var item1 = remoteSite.item1();  // ...etc.

    // now, send the request to the server.
    await remoteSite.send();

    // now do something with the Futures from the calls.
    return [fromJson(await item1), fromJson(await item2), fromJson(await item3)]
  }

```
## Server Basics
The server library decodes JSON-RPC request packages and allows association of the JSON-RPC request with an object that calls the remote methods, and returns a result. Network and transport issues are outside the scope of this implementation. That said, this is designed to be fairly easy with the transport or framework you are using. It's just a method that uses a dispatcher. In a server implementation, make an endpoint for a particular Dispatcher, and use these utilities to decode the request and package the result.

This server implementation uses a Dispatcher concept. Essentially, a dispatcher is an instantiated class that contains the remote methods to be called at an endpoint. The server accepts a call request, deconstructs the JSON, then creates or associates a dispatcher to call the method on that instance, with the requested parameters. The returned value (or exception) is assembled in JSON as a response and sent back to the client.

- Import the server library
```dart
import 'package:jsonrpc2/jsonrpc2.dart';
```

- Create a class implementing the service methods at an endpoint. Just about any class with methods will do. [example api class](example/rpc_methods.dart), and import it, if it is in a different file.
```dart
import 'rpc_methods.dart';
```
- make a method for your listener that accepts JSON-RPC strings from the client. This string may be, for example, the body of a HTTP POST. Within this method, use this library's **jsonRpc** method to associate the string with the **Dispatcher**, which performs the method. The **jsonRpc** method will ultimately produce a string, which should be sent back to the client as a response.

The **jsonRpc** method has the following signature.

```dart
Future<String> jsonRpc(String request, Dispatcher dispatcher)
```
-- **request** is a JSON-RPC request string, the request from the client.

-- a **dispatcher** meets the [Dispatcher interface](https://pub.dev/packages/rpc_dispatcher). You will want to use one of the following:
- [mirror_dispatcher](https://pub.dev/packages/mirror_dispatcher)

- [reflector_dispatcher](https://pub.dev/packages/reflector_dispatcher)

These two implementations work equivalently. Mirror_dispatcher is easier to use, but it uses dart:mirrors, which cannot be used inside a flutter app. There may be other trade-offs.

### Example server using [shelf_io and mirror_dispatcher](example/server2_shelf_mirrored_for_client_test.dart)
### Example server using [shelf_io and reflector_dispatcher](example/server2_shelf_reflected_for_client_test.dart)

[more examples (server example names start with 'server2')](example)

