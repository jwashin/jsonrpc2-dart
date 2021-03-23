/// [dispatcher] is used as a kind of sneaky way of telling an instantiated
/// object to do something. Instead of invoking a method directly in code, you
/// give the dispatcher the instance and directions (method name and parameters)
/// about invoking the method, and the Dispatcher gets the instance to perform
/// the method and gives you the returned value. With a dispatcher, you might
/// put together a fancy client-server API using a database. The API would be
/// the public methods of a class that interrogates and updates the database.

import 'dart:async';
import 'dart:mirrors';
import 'dispatcher.dart';
import 'rpc_exceptions.dart';

/// MirrorDispatcher implements Dispatcher by introspecting a class instance 
/// using dart:mirrors. dart:mirrors allows you to invoke an instance's methods
/// by their string names.
///
/// Construct a [MirrorDispatcher] with a class instance.
/// Dispatcher.dispatch("someMethod") will return a Future of whatever value it
/// returns.
/// It's mainly a wrapper around reflect.
/// For any method dispatched, Dispatcher returns either the return value of
/// the method or instances of one of three "Exception" classes. Most errors
/// will be corralled into these objects, so that runtime exceptions don't get
/// thrown, instead are returned in an orderly manner.
class MirrorDispatcher implements Dispatcher{
  /// the initialized class instance we will be performing methods on.
  dynamic instance;

  /// constructor
  MirrorDispatcher(this.instance);

  @override
  Future<dynamic> dispatch(String methodName,
      [List<dynamic>? positionalParams,
      Map<String, dynamic>? namedParams]) async {
    namedParams = namedParams ?? <String, dynamic>{};
    var posParams = positionalParams ?? [];

    if (posParams is! List) {
      posParams = [posParams];
    }

    var symbolMap = <Symbol, dynamic>{};
    if (namedParams.isNotEmpty) {
      symbolMap = symbolizeKeys(namedParams);
    }

    var instanceMirror = reflect(instance);

    Symbol methodMirror;
    try {
      methodMirror = getMethodMirror(instanceMirror, methodName);
    } on MethodNotFound catch (_) {
      return MethodNotFound('Method not found: $methodName');
    }

    InstanceMirror t;
    try {
      t = instanceMirror.invoke(methodMirror, posParams, symbolMap);
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
    var resp = await t.reflectee;
    return resp;
  }
}

/// Find and return the method in the class of the mirror of the instance.
/// Caution! Turning this mirror sideways may implode the universe.
/// Throw MethowNorFound if the methodName is private or an attribute 
/// or not found,
Symbol getMethodMirror(dynamic instanceMirror, String methodName) {
  ClassMirror classMirror = instanceMirror.type;
  for (var classMember in classMirror.declarations.keys) {
    var instanceMethod = MirrorSystem.getName(classMember);
    if (instanceMethod == methodName) {
      var methodMirror = classMirror.declarations[classMember];
      if (methodMirror is! MethodMirror || methodMirror.isPrivate) {
        throw MethodNotFound();
      }
      return classMember;
    }
  }
  throw MethodNotFound();
}
