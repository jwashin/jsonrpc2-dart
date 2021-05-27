library rpc_methods;

import 'package:rpc_exceptions/rpc_exceptions.dart';

import 'classb.dart';

/// cheap persistence. It's just a thing.
dynamic cheapPersistence;

/// One of the stupidest APIs ever. Do not model this
///
/// But it does demo some of the kinds of things an API might do
class ExampleMethodsClass {
  /// subtraction.
  num subtract(minuend, subtrahend) => minuend - subtrahend;

  /// subtraction using named parameters for minuend and subtrahend
  num nsubtract({minuend = 0, subtrahend = 0}) => minuend - subtrahend;

  /// addition
  num add(x, y) => x + y;

  /// update the thing to be whatever gets sent
  void update(args) {
    cheapPersistence = args;
  }

  /// just send it back
  String echo(b) => b;

  /// just send it back, after appending some unicode
  String echo2(b) => b + ' Τη γλώσσα μου έδωσαν ελληνική';

  /// return whatever the stored thing is
  dynamic fetchGlobal() => cheapPersistence;

  /// add them together
  num summation(List args) {
    var sum = 0.0;
    for (var value in args) {
      sum += value;
    }
    return sum;
  }

  /// throw an exception
  void raiseMe(var something) {
    throw something;
  }

  /// you can balloo anything but a 'frotz'
  String baloo(String arg) {
    if (arg == 'frotz') {
      throw RuntimeException('Cannot baloo with $arg!', 34);
    }
    return 'Balooing $arg, as requested.';
  }

  /// tempt fate by doing the undefined
  num divzero(p) {
    return p / 0;
  }

  /// make a silly thing and return its JSON representation
  String s1(amap) => ClassB.fromMap(amap).s1;

  /// shh. private...
  String _private() => 'hello';

  /// I think we might call this but not care about the return value
  Object notifyHello(args) {
    return args;
  }

  /// a method that employs the private method.
  List getData() {
    // just to remove a nagging Analysis
    var hello = _private();
    return [hello, 5];
  }

  /// Wow. don't do this. I warn you.
  void oopsie() {
    throw RandomException('Whoops!');
  }

  /// pong!!!
  bool ping() => true;
}

/// It's a class, initialized with a name and it has a hello() method.
class Friend {
  /// guess who???
  String name;

  /// constructor.
  Friend(this.name);

  /// Greets! Maybe someday, we will also wave.
  String hello() => 'Hello from $name!';
}

/// This is a kind of exception outside of what is specifically handled
/// in this jsonrpc2 library
class RandomException implements Exception {
  /// a useful outburst
  String message;

  /// constructor. initialize with an optional message
  RandomException([this.message = 'Random Exception. Boo!']);

  @override
  String toString() => 'RandomException: $message';
}
