///Dispatcher has a dispatch method for invoking methods on an instance.

abstract class Dispatcher {
  ///  Invoke named method with parameters on the instance and
  /// return a Future of the result, if possible.
  ///  Catch, repackage and return (not throw or rethrow) *All Errors*.
  ///  positionalParams should be a List or null.
  ///  namedParams should be a Map of String:value or null.
  Future<dynamic> dispatch(String methodName,
      [List<dynamic>? positionalParams, Map<String, dynamic>? namedParams]);
}

/// Convenience method for making a Map of Symbol:value out of
/// a Map of String:value. We want to do this to the Map of namedParams
/// for use in an 'invoke' method.
Map<Symbol, dynamic> symbolizeKeys(Map<String, dynamic> namedParams) {
  var symbolMap = <Symbol, dynamic>{};
  for (var key in namedParams.keys) {
    symbolMap[Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}
