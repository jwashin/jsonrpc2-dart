library classb;

import 'dart:convert';

/// Stupid example class. Does almost nothing. But it's easy to understand :)
class ClassB {
  /// arbitrary member s1
  String s1;

  /// arbitrary member s2
  String s2;

  /// constructor. No surprises!
  ClassB(this.s1, this.s2);

  /// create a ClassB instance from a map
  ClassB.fromMap(Map<String, dynamic> aMap)
      : s1 = aMap['s1'],
        s2 = aMap['s2'];

  /// toJson means that ClassB instances are expressible in JSON
  Map<String, dynamic> toJson() => {'s1': s1, 's2': s2};
}

/// a quick test, just to be sure...
void main() {
  var s = ClassB('abc', '123');
  print(json.encode(s));
}
