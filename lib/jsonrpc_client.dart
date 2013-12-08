library jsonrpc_client;

import "dart:convert";
import "dart:async";
import "dart:html";
import "package:logging/logging.dart";

/* basic usage:
 *    import "package:jsonrpc_client/jsonrpc_client.dart"
 *
 *    var url = "http://somelocation";
 *    var proxy = new ServerProxy(url);
 *    Future request = proxy.call("someServerMethod", [arg1, arg2 ]);
 *    request.then((value){doSomethingWithValue(value);});
 *
 * Each arg must be representable in JSON.
 *
 *
 * This is a first stab at JSON-RPC client for Dart.
 * It may contribute to js code size as-is, because
 * of the use of dart:mirrors.
 *
 * Exceptions on the remote end will throw RemoteException.
 *
 * Optionally you may set timeout.
 *
 *   var proxy = new ServerProxy(url);
 *   proxy.timeout=300;
 *
 * If timeout happens, TimeoutException is thrown, with the JSON-RPC request
 * message as payload.
 *
 */


final _logger = new Logger('JSON-RPC');

class ServerProxy {
  String url;
  int timeout = 0;
  String serverVersion = '2.0';
  ServerProxy(this.url);

/*

  Future noSuchMethod(Invocation msg){
    /* This is the trick. The proxy won't have code for the server-side
     * methods, so we redirect to the thing that makes a JSON-RPC
     * request out of the Invocation.
     *
     * Beware of calling methods that do not exist...
     */

    Future request = jsonRpcInvoke(msg);
    return request.then((req) => req.responseText)
                  .then((_) => new Future(() => parseJsonRpcResponse(_)));
  }

  Future jsonRpcInvoke(Invocation msg){

    /* Get the pieces of the method call out of the Invocation.
     * We need method and params(positional or named; not allowed to
     * use both). Don't use named arguments for the time being; works fine
     * in Dartium, but not in javascript. See below.
     *
     * There's some sneaky stuff here to get 'id' out of named parameters,
     * but 'id' doesn't matter as long as it is unique. It's probably
     * YAGNI, but left in for the first cut.
     *
     */
    //var params;
    var id;
    List positionalargs = msg.positionalArguments;
    Map namedargs = msg.namedArguments;
    var tid;

/*    if (positionalargs.length == 0){

 namedarguments
 * MirrorSystem.getSymbol is notImplemented for this in Dart's
 * javascript translation, so named arguments are here for future use.
 * Of course, named arguments are the only way to pass 'id' into the
 * protocol, so (fingers crossed) maybe this will happen soon.

      try{
      tid = MirrorSystem.getSymbol('id');
      if (namedargs.containsKey(tid)){
        id = namedargs[tid];
        namedargs.remove(tid);
        }
      }
      on ArgumentError catch (e){
        tid = null;
      }
        params = {};
      for (var item in namedargs.keys){
        String key = MirrorSystem.getName(item);
        params[key] = namedargs[item];
        }
      }
      else{

        params = positionalargs;
        }
*/
    List args = positionalargs;
    String method = MirrorSystem.getName(msg.memberName);

    return callMethod(method, args, id);
       }

*/

  notify(method, [params=null]){
    return call(method, params, true);
  }

  retry(package){
    return call(package.method, package.args, package.notify);
  }

  call(method, [params=null, notify=false]){
    /* Package and send the request.
     * Return the response
     */

    if (params == null) params = [];
    var package = new JsonRpcMethod(method,
        params,
        notify:notify,
        serverVersion:serverVersion);
    if (notify){
      _doRequest(package);
      return new Future(()=>null);
      }
    else
    return _doRequest(package).then((rpcResponse)=>handleResponse(rpcResponse));
  }

  _doRequest(package){
    //return a future with the JSON-RPC response
    var request = new HttpRequest();
    request.open("POST", url, async:true);
    request.timeout = timeout;
    request.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    var c = new Completer();
    request.onReadyStateChange.listen((_){
      if (request.readyState == 4){
        switch(request.status){
          case 200:
            c.complete(request);
            break;
          case 204:
            c.complete(request);
            break;

          default:
            c.completeError(new HttpStatusError(request.statusText,
                request, package));
        }
      }
    });
    //Timeout
    request.onTimeout.listen((_){
      //request.abort();
      c.completeError(new TimeoutException('JsonRpcRequest timed out',
          request, package));
      });

    // It's sent out utf-8 encoded. Without having to be told. Nice!
    request.send(JSON.encode(package));
    return c.future.then((request)=>new Future(()
        { String body = request.responseText;
          if (request.status == 204 || body.isEmpty){
            return null;
          }
          else{
            return JSON.decode(body);
          }
        }));
    }

  handleResponse(response){
    if (response.containsKey('error')){
      return (new RemoteException(response['error']['message'],
          response['error']['code'],
          response['error']['data']));
    }
    else{
      return response['result'];
    }
  }

  checkError(response){
    if (response is RemoteException)
      throw response;
    return response;
  }

}


class BatchServerProxy extends ServerProxy{

  BatchServerProxy(url) : super(url);
  var requests = [];
  var responses = {};
  var used_ids = {};


  call(method, [params=null, notify=false]){
    /* Package and send the request.
     * Return a Future with the HttpRequest object
     */

    if (params == null) params = [];
    var package = new JsonRpcMethod(method,
        params,
        notify:notify,
        serverVersion:serverVersion);
    requests.add(package);
    if (!notify){
      var c = new Completer();
      responses[package.id] = c;
      return c.future;
    }
  }

  send(){
    var future = _doRequest(requests);
    requests = [];
    return future.then((resp)=>new Future.sync(()=>handleResponses(resp)));
  }

  handleResponses(resps){
    for (var resp in resps){
      var value = handleResponse(resp);
      //if (value is Exception) throw value;
      var id = resp['id'];
      if (id != null){
        responses[id].complete(value);
        responses.remove(id);
      }
      else{
        var error = resp['error'];
        _logger.warning(new RemoteException(error['message'], error['code'], error['data']).toString());
      }
    }
    return null;
  }

}

class JsonRpcMethod{
  String method;
  var args;
  bool notify;
  var _id;
  String serverVersion;
  JsonRpcMethod(this.method,this.args,
      {this.notify:false,this.serverVersion:'2.0'});

  get id {
    if (notify){
      return null;
    }
    else{
      if (_id == null) _id = this.hashCode;
      return _id;
    }
  }

  set id(var value) => _id = value;

  toJson(){
    Map map;
    switch (serverVersion){
      case '2.0':
        map = {
               'jsonrpc': serverVersion,
               'method': method,
               'params': (args is List || args is Map) ? args : [args]
        };
        if (!notify) map['id'] = id;
        break;
      case '1.0':
        if (args is Map)
          throw new FormatException("Cannot use named params in JSON-RPC 1.0");
        map = {
                 'method': method,
                 'params': (args is List) ? args : [args],
                 'id':id
               };
        break;
    }
    return map;
    }


  toString() => "JsonRpcMethod: ${toJson()}";

}



class RemoteException implements Exception{

  int code;
  String message;
  var data;

  RemoteException([this.message, this.code, this.data]);

  toString() => data != null ? "RemoteException $code '$message' Data:($data))":
    "RemoteException $code: $message";


}

class HttpStatusError implements Exception{
  var message;
  var data;
  var request;
  HttpStatusError([this.message, this.request, this.data]);
  toString() => "$message";

}


class TimeoutException implements Exception{
  String message;
  var data;
  var request;

  TimeoutException([this.message, this.request, this.data]);

  toString() => "$message";
}

