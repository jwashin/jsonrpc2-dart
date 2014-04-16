import 'dart:async';
import 'dart:mirrors';


class MethodNotFound {
  var message;
  MethodNotFound([this.message]);
}

class InvalidParameters {
  var message;
  InvalidParameters([this.message]);
}

class InternalError {
  var message;
  InternalError([this.message]);
}

symbolizeKeys(namedParams) {
  Map symbolMap = {};
  for (var key in namedParams.keys) {
    symbolMap[new Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}

class Dispatcher {
  var instance;
  Dispatcher(this.instance);

  dispatch(requestedMethod, [positionalParams = null, namedParams = null]) {
    if (namedParams == null) namedParams = {};
    if (positionalParams == null) positionalParams = [];

    namedParams = symbolizeKeys(namedParams);
    InstanceMirror instanceMirror = reflect(instance);
    ClassMirror classMirror = instanceMirror.type;
    for (var property in classMirror.declarations.keys) {
      var instanceMethod = MirrorSystem.getName(property);
      if (instanceMethod == requestedMethod) {
        return new Future.sync(() {
          if (classMirror.declarations[property].isPrivate) return new MethodNotFound("Method not found: $requestedMethod");
          InstanceMirror t;
          try {
            t = instanceMirror.invoke(property, positionalParams, namedParams);
          } on TypeError catch (e) {
            return new InvalidParameters('$e');
          } on NoSuchMethodError catch (e) {
            return new InvalidParameters('$e');
          } catch (e) {
            return new InternalError('$e');
          }
          return t.reflectee;
        });
      }
    }
    return new Future.sync(() {
      return new MethodNotFound("Method not found: $requestedMethod");
    });
  }
}
