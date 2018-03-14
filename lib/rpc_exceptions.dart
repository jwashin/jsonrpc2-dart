library rpc_exceptions;

class RpcException implements Exception {
  int code = 0;
  String message;
  dynamic data;
  RpcException([this.message, this.code]);
  String toString() {
    return message;
  }
}

class MethodNotFound extends RpcException {
  MethodNotFound([String msg = '', int newCode = -32601]) : super(msg, newCode);
}

class InvalidParameters extends RpcException {
  InvalidParameters([String msg = '', int newCode = -32602])
      : super(msg, newCode);
}

class RuntimeException extends RpcException {
  dynamic error;
  RuntimeException(
      [dynamic newMessage = '', int newCode = -32000, dynamic newData = null]) {
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
