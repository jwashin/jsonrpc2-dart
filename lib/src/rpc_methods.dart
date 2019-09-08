library rpc_methods;

import "package:jsonrpc2/rpc_exceptions.dart";
import "package:jsonrpc2/src/classb.dart";

/// cheap persistence. It's just a thing.
dynamic cheapPersistence;

/// One of the stupidest APIs ever. Do not model this
/// 
/// But it does demo some of the kinds of things an API might do
class ExampleMethodsClass {
  /// subtraction. 
  subtract(minuend, subtrahend) => minuend - subtrahend;

  /// subtraction using named parameters for minuend and subtrahend
  nsubtract({minuend: 0, subtrahend: 0}) => minuend - subtrahend;

/// addition
  add(x, y) => x + y;

/// update the thing to be whatever gets sent
  update(args) {
    cheapPersistence = args;
  }

/// just send it back
  echo(b) => b;

/// just send it back, after appending some unicode
  echo2(b) => b + ' Τη γλώσσα μου έδωσαν ελληνική';

/// return whatever the stored thing is
  fetchGlobal() => cheapPersistence;

/// add them together
  summation(args) {
    var sum = 0;
    for (var value in args) {
      sum += value;
    }
    return sum;
  }

/// throw an exception
  raiseMe(var something) {
    throw something;
  }

/// you can balloo anything but a 'frotz'
  baloo(var arg) {
    if (arg == 'frotz') {
      throw RuntimeException('Cannot baloo with ${arg}!', 34);
    }
    return 'Balooing ${arg}, as requested.';
  }

/// tempt fate by doing the undefined
  divzero(p) {
    return p / 0;
  }


/// make a silly thing and return its JSON representation
  s1(amap) => ClassB.fromMap(amap).s1;

 /// shh. private... 
  _private() => "hello";

/// I think we might call this but not care about the return value
  notify_hello(args) {
    return args;
  }

/// a method that employs the private method.
  get_data() {
    // just to remove a nagging Analysis
    String hello = _private();
    return [hello, 5];
  }

/// Wow. don't do this. I warn you.
  oopsie() {
    throw RandomException('Whoops!');
  }

/// pong!!!
  ping() => true;
}

/// It's a class, initialized with a name and it has a hello() method.
class Friend {
  /// guess who???
  String name;

  /// constructor. 
  Friend(this.name);

  /// Greets! Maybe someday, we will also wave.
  hello() => "Hello from $name!";
}

/// This is a kind of exception outside of what is specifically handled
/// in this jsonrpc2 library
class RandomException implements Exception {
  /// a useful outburst
  var message = 'Random Exception. Boo!';

  /// constructor. initialize with an optional message
  RandomException([this.message]);

  toString() => "RandomException: $message";
}
