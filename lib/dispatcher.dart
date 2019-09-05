/// [dispatcher] is for a kind of backwards and sneaky way of telling an object to do
/// something. Instead of invoking a method directly in code, you send the dispatcher
/// directions about invoking the method, and the Dispatcher does it and gives you the returned value.
/// As an example, if you have a "School" object with a name and a list of students, you might invoke
/// "addStudent('Jane Rogers')" as a method, which would add Jane Rogers as a student to the school.
/// That's easy, if you have direct access to the School object. 
library dispatcher;

import 'dart:async';
import 'dart:mirrors';
import 'rpc_exceptions.dart';

/// Dispatcher introspects a class instance so you can invoke its methods by their string names
///
/// Construct a Dispatcher with a class instance.
/// Dispatcher.dispatch("someMethod") will return a Future of whatever value it returns.
/// It's mainly a wrapper around reflect.
/// For any method dispatched, Dispatcher returns either the return value of the method or instances of one
/// of three "Exception" classes. Most errors will be corralled into these objects, so that
/// runtime exceptions don't get thrown, instead are returned in an orderly manner.
class Dispatcher {
  /// the initialized class instance we will be performing methods on.
  dynamic instance;

  /// constructor
  Dispatcher(this.instance);

  ///  Invoke named method with parameters on the instance and return a Future of the result, if possible.
  ///
  ///  Catch, repackage and return (not throw or rethrow) all Errors.
  ///  positionalParams should be a List or null.
  ///  namedParams should be a Map of String:value or null.
  Future<dynamic> dispatch(String methodName,
      [List<dynamic> positionalParams, Map<String, dynamic> namedParams]) {
    namedParams = namedParams == null ? {} : namedParams;
    positionalParams = positionalParams == null ? [] : positionalParams;

    if (positionalParams is! List) {
      positionalParams = [positionalParams];
    }

    Map<Symbol, dynamic> symbolMap;
    if (namedParams.isNotEmpty) {
      symbolMap = symbolizeKeys(namedParams);
    }

    InstanceMirror instanceMirror = reflect(instance);
    var methodMirror = getMethodMirror(instanceMirror, methodName);
    if (methodMirror == null) {
      return Future.sync(() {
        return MethodNotFound("Method not found: $methodName");
      });
    }
    return Future.sync(() {
      InstanceMirror t;
      try {
        t = instanceMirror.invoke(methodMirror, positionalParams, symbolMap);
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

/// Convenience method for making a Map of Symbol:value out of a Map of String:value.
/// We have to do this to the Map of namedParams for use in the 'invoke' method of InstanceMirror.
symbolizeKeys(Map<String, dynamic> namedParams) {
  Map<Symbol, dynamic> symbolMap = {};
  for (String key in namedParams.keys) {
    symbolMap[Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}

/// Find the method in the class of the mirror of the instance.
/// Caution! Turning the mirror sideways may implode the universe.
/// Return null if the methodName is private or an attribute or not found,
getMethodMirror(instanceMirror, methodName) {
  ClassMirror classMirror = instanceMirror.type;
  for (Symbol classMember in classMirror.declarations.keys) {
    String instanceMethod = MirrorSystem.getName(classMember);
    if (instanceMethod == methodName) {
      DeclarationMirror methodMirror = classMirror.declarations[classMember];
      if (methodMirror is! MethodMirror || methodMirror.isPrivate) return null;
      return classMember;
    }
  }
  return null;
}
