/// [dispatcher] is used as a kind of sneaky way of telling an instantiated
/// object to do something. Instead of invoking a method directly in code, you
/// give the dispatcher the instance and directions (method name and parameters)
/// about invoking the method, and the Dispatcher gets the instance to perform
/// the method and gives you the returned value.

import 'package:jsonrpc2/src/dispatcher.dart';
import 'rpc_exceptions.dart';

/// Dispatcher introspects a class instance so you can invoke its methods by
/// their string names,
///
/// Dispatcher.dispatch("someMethod") will return a Future of whatever value it
/// returns.
///
/// It's mainly a wrapper around reflectable. When you process a Reflectable
/// class, a mirror of the class's schematics is created.
/// A ReflectorDiapatcher is inititalized with that and an actual instance.
///
class ReflectorDispatcher implements Dispatcher{
  /// the initialized class instance we will be invoking methods on.
  dynamic instance;

  /// an introspected reflection of the instance's class's guts,
  /// predigested by reflectable
  dynamic mirror;

  /// constructor
  ReflectorDispatcher(this.instance, this.mirror);

  ///  Invoke named method with parameters on the instance and
  /// return a Future of the result, if possible.
  ///
  ///  Catch, repackage and return (not throw or rethrow) *All Errors*.
  ///  positionalParams should be a List or null.
  ///  namedParams should be a Map of String:value or null.
  @override
  Future dispatch(String methodName,
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

    var instanceMirror = mirror.reflect(instance);

    // error checking the method and parameter counts
    var methodSchemas = instanceMirror.type.declarations;
    if (methodSchemas.containsKey(methodName)) {
      var params = methodSchemas[methodName].parameters;
      var namedCount = 0;
      var optionals = 0;
      for (var p in params) {
        if (p.isNamed) {
          namedCount += 1;
        }
        if (p.isOptional) {
          optionals += 1;
        }
      }
      var actualCount = posParams.length;
      var requiredCount = params.length - namedCount - optionals;
      if (actualCount < requiredCount) {
        return InvalidParameters('too few params');
      }
      if (actualCount > requiredCount + optionals) {
        return InvalidParameters('too many params');
      }
    } else {
      return MethodNotFound('Not found: $methodName');
    }

    var resp;
    try {
      resp = await instanceMirror.invoke(methodName, posParams, symbolMap);
    } on TypeError catch (e) {
      return InvalidParameters('$e');
    } catch (e) {
      // passthrough for custom user-correctable errors
      if (e is RuntimeException) {
        return e;
      }
      return RuntimeException('$e');
    }
    return resp;
  }
}

