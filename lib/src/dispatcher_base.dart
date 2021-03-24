/// Dispatcher is interface with a dispatch method for invoking methods on 
/// an instance.
/// This interface hides implementation details for concrete method invokers
/// for a JsonRpc service.

abstract class Dispatcher {
  ///  Invoke named method with parameters on the instance and
  /// return a Future of the result, if possible.
  ///  Catch, repackage and return (not throw or rethrow) *All Errors*.
  ///  positionalParams shall be a List or null.
  ///  namedParams shall be a Map of String:value or null.
  Future<dynamic> dispatch(String methodName,
      [dynamic positionalParams, Map<String, dynamic>? namedParams]);
}

/// Convenience method for making a Map of Symbol:value out of
/// a Map of String:value. We want to do this to the Map of namedParams
/// for use in an 'invoke' method of mirror or reflected instance.
Map<Symbol, dynamic> symbolizeKeys(Map<String, dynamic> namedParams) {
  var symbolMap = <Symbol, dynamic>{};
  for (var key in namedParams.keys) {
    symbolMap[Symbol(key)] = namedParams[key];
  }
  return symbolMap;
}
