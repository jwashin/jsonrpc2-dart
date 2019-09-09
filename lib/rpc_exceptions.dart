library rpc_exceptions;

/// base RPC exception class, the one to rule them all
class RpcException implements Exception {
  /// maybe an identifying code
  int code = 0;

  /// maybe a helpful message
  String message;

  /// maybe some useful data
  dynamic data;

  /// Constructor. All params are optional.
  RpcException([this.message, this.code]);
  String toString() {
    return message;
  }
}

/// [MethodNotFound] is presumably self-explanatory.
///
/// This exception is identified in the JSON-RPC v2 specification.
class MethodNotFound extends RpcException {
  /// constructor
  MethodNotFound([String msg = '', int newCode = -32601]) : super(msg, newCode);
}

/// [InvalidParameters] is presumably self-explanatory.
///
/// This exception is identified in the JSON-RPC v2 specification.
class InvalidParameters extends RpcException {
  /// constructor
  InvalidParameters([String msg = '', int newCode = -32602])
      : super(msg, newCode);
}

/// [RuntimeException] is a facility for communicating application-level exceptions.
///
/// If an application-level server-side exception should be handled on the
/// client side, we can send this info back to the client with an error code,
/// a message, and/or useful data. Look for [checkResponse] in client JSON-RPC v2
/// implementation.
class RuntimeException extends RpcException {
  /// error can be any object with a "message" member
  dynamic error;

  /// constructor. all params are optional. Be terse but not too clever.
  RuntimeException(
      [dynamic newMessage = '', int newCode = -32000, dynamic newData]) {
    data = newData;
    code = newCode;
    if (newMessage is Exception) {
      error = newMessage;
      code = -32000;
      if (newMessage is RpcException) {
        code = newMessage.code;
      }
      message = error.message;
    } else if (newMessage is Error) {
      error = message;
      message = "$newMessage";
    } else {
      message = newMessage;
    }
  }
}
