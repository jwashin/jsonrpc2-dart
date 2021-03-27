import 'dart:async';
import 'dart:mirrors';

import 'package:rpc_dispatcher/rpc_dispatcher.dart';
import 'package:rpc_exceptions/rpc_exceptions.dart';

/// MirrorDispatcher implements [Dispatcher] by introspecting a class instance
/// using [dart:mirrors]. dart:mirrors allows you to invoke an instance's methods
/// by their string names.
///
/// Construct a [MirrorDispatcher] with a class instance.
/// MirrorDispatcher.dispatch("someMethod") will return a Future of whatever
/// value it returns.
/// It's mainly a wrapper around reflect.
/// For any method dispatched, Dispatcher returns either the return value of
/// the method or instances of one of three "Exception" classes. Most errors
/// will be corralled into these objects, so that runtime exceptions don't get
/// thrown, instead are returned in an orderly manner.
class MirrorDispatcher implements Dispatcher {
  /// the initialized class instance we will be performing methods on.
  dynamic instance;

  /// constructor
  MirrorDispatcher(this.instance);

  @override
  Future<dynamic> dispatch(String methodName,
      [dynamic positionalParams, Map<String, dynamic>? namedParams]) async {
    var posParams = positionalParams ?? [];
    if (posParams is Map<String, dynamic>) {
      namedParams = positionalParams;
      posParams = [];
    }
    if (posParams is! List) {
      posParams = [posParams];
    }
    namedParams = namedParams ?? <String, dynamic>{};
    var symbolMap = <Symbol, dynamic>{};
    if (namedParams.isNotEmpty) {
      symbolMap = symbolizeKeys(namedParams);
    }

    var instanceMirror = reflect(instance);

    Symbol methodMirror;
    try {
      methodMirror = getMethodMirror(instanceMirror, methodName);
    } on MethodNotFoundException catch (_) {
      return MethodNotFoundException('Method not found: $methodName');
    }

    InstanceMirror t;
    try {
      t = instanceMirror.invoke(methodMirror, posParams, symbolMap);
    } on TypeError catch (e) {
      return InvalidParametersException('$e');
    } on NoSuchMethodError catch (e) {
      return InvalidParametersException('$e');
    } on RuntimeException catch (e) {
      return e;
    } catch (e) // Errors might crash the server
    {
      return RuntimeException('$e');
    }
    var resp = await t.reflectee;
    return resp;
  }
}

/// Find and return the method in the class of the mirror of the instance.
/// Throw MethowNorFound if the methodName is private or an attribute
/// or not found,
Symbol getMethodMirror(dynamic instanceMirror, String methodName) {
  ClassMirror classMirror = instanceMirror.type;
  for (var classMember in classMirror.declarations.keys) {
    var instanceMethod = MirrorSystem.getName(classMember);
    if (instanceMethod == methodName) {
      var methodMirror = classMirror.declarations[classMember];
      if (methodMirror is! MethodMirror || methodMirror.isPrivate) {
        throw MethodNotFoundException();
      }
      return classMember;
    }
  }
  throw MethodNotFoundException();
}
