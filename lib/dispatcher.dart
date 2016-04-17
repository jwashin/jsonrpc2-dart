library dispatcher;

import 'dart:async';
import 'dart:mirrors';
import 'rpc_exceptions.dart';

/**
 * A Dispatcher is initialized with a class instance and will invoke methods of that class.
 *
 * Dispatcher.dispatch("someMethod") will return a Future of whatever value  it returns.
 *
 * It's mainly a wrapper around reflect.
 *
 * For any method dispatched, It returns either the return value of the method or instances of one
 * of three "Exception" classes. Most errors will be corralled into these objects, so that
 * runtime exceptions don't get thrown, instead returned in an orderly manner.
 */

class Dispatcher {
  var instance;
  Dispatcher(this.instance);
/*
 * Invoke named method with parameters on the instance and return a Future of the result, if possible.
 * Catch, repackage and return (not throw or rethrow) all Errors.
 *
 * positionalParams should be a List or null.
 * namedParams should be a Map of String:value or null.
 */
  dispatch(String methodName, [positionalParams = null, namedParams = null]) {
    namedParams = namedParams == null ? {} : namedParams;
    positionalParams = positionalParams == null ? [] : positionalParams;

    if (positionalParams is! List) {
      positionalParams = [positionalParams];
    }

    if (!namedParams.isEmpty) namedParams = symbolizeKeys(namedParams);

    InstanceMirror instanceMirror = reflect(instance);
    var methodMirror = getMethodMirror(instanceMirror, methodName);
    if (methodMirror == null) {
      return new Future.sync(() {
        return new MethodNotFound("Method not found: $methodName");
      });
    }
    return new Future.sync(() {
      InstanceMirror t;
      try {
        t = instanceMirror.invoke(methodMirror, positionalParams, namedParams);
      } on TypeError catch (e) {
        return new InvalidParameters('$e');
      } on NoSuchMethodError catch (e) {
        return new InvalidParameters('$e');
      } catch (e) {
        if (e is RuntimeException) {
          return e;
        }
        return new RuntimeException(e);
      }
      return t.reflectee;
    });
  }
}

/*
 * Convenience method for making a Map of Symbol:value out of a Map of String:value.
 * We have to do this to the Map of namedParams for use in the invoke method of InstanceMirror.
*/
symbolizeKeys(namedParams) {
  Map symbolMap = {};
  for (var key in namedParams.keys) {
    symbolMap[new Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}

/*
 * Find the method in the class of the mirror of the instance.
 * Turning the mirror sideways will implode the universe.
 * Return null if the methodName is private or an attribute or not found,
*/
getMethodMirror(instanceMirror, methodName) {
  ClassMirror classMirror = instanceMirror.type;
  for (var classMember in classMirror.declarations.keys) {
    String instanceMethod = MirrorSystem.getName(classMember);
    if (instanceMethod == methodName) {
      var methodMirror = classMirror.declarations[classMember];
      if (methodMirror is! MethodMirror || methodMirror.isPrivate) return null;
      return classMember;
    }
  }
  return null;
}
