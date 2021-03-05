/// [dispatcher] is used as a kind of sneaky way of telling an instantiated
/// object to do something. Instead of invoking a method directly in code, you
/// give the dispatcher the instance and directions (method name and parameters)
/// about invoking the method, and the Dispatcher gets the instance to perform
/// the method and gives you the returned value. With a dispatcher, you might
/// put together a fancy client-server API using a database. The API would be
/// the public methods of a class that interrogates and updates the database.
library dispatcher;

import 'dart:async';
import 'dart:mirrors';
import 'rpc_exceptions.dart';

/// Dispatcher introspects a class instance so you can invoke its methods by
/// their string names,
///
/// Construct a Dispatcher with a class instance.
/// Dispatcher.dispatch("someMethod") will return a Future of whatever value it
/// returns.
/// It's mainly a wrapper around reflect.
/// For any method dispatched, Dispatcher returns either the return value of
/// the method or instances of one of three "Exception" classes. Most errors
/// will be corralled into these objects, so that runtime exceptions don't get
/// thrown, instead are returned in an orderly manner.
class Dispatcher {
  /// the initialized class instance we will be performing methods on.
  dynamic instance;

  /// constructor
  Dispatcher(this.instance);

  ///  Invoke named method with parameters on the instance and
  /// return a Future of the result, if possible.
  ///
  ///  Catch, repackage and return (not throw or rethrow) *All Errors*.
  ///  positionalParams should be a List or null.
  ///  namedParams should be a Map of String:value or null.
  Future<dynamic> dispatch(String methodName,
      [List<dynamic>? positionalParams, Map<String, dynamic>? namedParams]) {
    namedParams = namedParams ?? {};
    positionalParams = positionalParams ?? [];

    if (positionalParams is! List) {
      positionalParams = [positionalParams];
    }

    var symbolMap = <Symbol, dynamic>{};
    if (namedParams.isNotEmpty) {
      symbolMap = symbolizeKeys(namedParams);
    }

    var instanceMirror = reflect(instance);
    var methodMirror = getMethodMirror(instanceMirror, methodName);
    if (methodMirror == null) {
      return Future.sync(() {
        return MethodNotFound('Method not found: $methodName');
      });
    }
    return Future.sync(() {
      InstanceMirror t;
      try {
        t = instanceMirror.invoke(methodMirror, positionalParams!, symbolMap);
      } on TypeError catch (e) {
        return InvalidParameters('$e');
      } on NoSuchMethodError catch (e) {
        return InvalidParameters('$e');
      } catch (e) {
        if (e is RuntimeException) {
          return e;
        }
        return RuntimeException(e);
      }
      return t.reflectee;
    });
  }
}

/// Convenience method for making a Map of Symbol:value out of
/// a Map of String:value. We want to do this to the Map of namedParams
/// for use in the 'invoke' method of InstanceMirror.
Map<Symbol, dynamic> symbolizeKeys(Map<String, dynamic> namedParams) {
  var symbolMap = <Symbol, dynamic>{};
  for (var key in namedParams.keys) {
    symbolMap[Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}

/// Find and return the method in the class of the mirror of the instance.
/// Caution! Turning the mirror sideways may implode the universe.
/// Return null if the methodName is private or an attribute or not found,
Symbol? getMethodMirror(dynamic instanceMirror, String methodName) {
  ClassMirror classMirror = instanceMirror.type;
  for (var classMember in classMirror.declarations.keys) {
    var instanceMethod = MirrorSystem.getName(classMember);
    if (instanceMethod == methodName) {
      var methodMirror = classMirror.declarations[classMember];
      if (methodMirror is! MethodMirror || methodMirror.isPrivate) return null;
      return classMember;
    }
  }
  return null;
}
