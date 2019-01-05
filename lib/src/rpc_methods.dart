library rpc_methods;

import "package:jsonrpc2/rpc_exceptions.dart";
import "package:jsonrpc2/src/classb.dart";

dynamic cheapPersistence;

class ExampleMethodsClass {
  subtract(minuend, subtrahend) => minuend - subtrahend;

  nsubtract({minuend: 0, subtrahend: 0}) => minuend - subtrahend;

  add(x, y) => x + y;

  update(args) {
    cheapPersistence = args;
  }

  echo(b) => b;

  echo2(b) => b + ' Τη γλώσσα μου έδωσαν ελληνική';

  fetchGlobal() => cheapPersistence;

  summation(args) {
    var sum = 0;
    for (var value in args) {
      sum += value;
    }
    return sum;
  }

  raiseMe(var something) {
    throw something;
  }

  baloo(var arg) {
    if (arg == 'frotz') {
      throw RuntimeException('Cannot baloo with ${arg}!', 34);
    }
    return 'Balooing ${arg}, as requested.';
  }

  divzero(p) {
    return p / 0;
  }

  s1(amap) => ClassB.fromMap(amap).s1;

  _private() => "hello";

  notify_hello(args) {
    return args;
  }

  get_data() {
    // just to remove a nagging Analysis
    String hello = _private();
    return [hello, 5];
  }

  oopsie() {
    throw RandomException('Whoops!');
  }

  ping() => true;
}

class Friend {
  String name;

  Friend(this.name);

  hello() => "Hello from $name!";
}

class RandomException implements Exception {
  var message = 'Random Exception. Boo!';

  RandomException([this.message]);

  toString() => "RandomException: $message";
}
