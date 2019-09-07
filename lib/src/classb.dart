library classb;

import 'dart:convert';

/// Stupid example class. Does stupid things simply
class ClassB {
  /// arbitrary member s1
  var s1;
  /// arbitrary member s2
  var s2;
  /// constructor. Surprise!
  ClassB(this.s1, this.s2);
  /// create a ClassB instance from a map
  static fromMap(Map aMap) => ClassB(aMap['s1'], aMap['s2']);
  /// ClassB instances are expressible in JSON
  toJson() => {'s1': s1, 's2': s2};
}

main() {
  ClassB s = ClassB('abc', '123');
  print(json.encode(s));
}
