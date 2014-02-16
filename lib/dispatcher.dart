import 'dart:async';
import 'dart:mirrors';

class Dispatcher{
  var instance;
  Dispatcher(this.instance);

  dispatch(method, params){

    var nparams;
    var pparams;
    InstanceMirror im = reflect(instance);
    ClassMirror mirror = im.type;
    for (var m in mirror.declarations.keys){
      var meth = MirrorSystem.getName(m);
      if (meth == method){
        if (mirror.declarations[m].isPrivate)
          throw new PrivateError("Method '$method' is private.");
        if (params is Map){
          var newmap = {};
          for (var key in params.keys){
            newmap[new Symbol(key)] = params[key];
          }
          nparams = newmap;
          pparams = [];
        }
        else{
          pparams = params;
        }
        return new Future.sync((){
          InstanceMirror t = im.invoke(m, pparams, nparams);
          return t.reflectee;
        });
      }
    }
    throw new MethodNotFoundError("Method not found: $method.");
  }
}


class MethodNotFoundError implements Exception{
  var message;
  MethodNotFoundError([this.message]);
}


class PrivateError implements Exception{
  var message;
  PrivateError([this.message]);
}