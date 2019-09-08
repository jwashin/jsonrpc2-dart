library classb;

import 'dart:convert';

/// Stupid example class. Does almost nothing. But simply :)
class ClassB {
  /// arbitrary member s1
  var s1;

  /// arbitrary member s2
  var s2;

  /// constructor. No surprise!
  ClassB(this.s1, this.s2);

  /// create a ClassB instance from a map
  static fromMap(Map aMap) => ClassB(aMap['s1'], aMap['s2']);

  /// ClassB instances will be expressible in JSON
  toJson() => {'s1': s1, 's2': s2};
}

/// a quick test, just to be sure...
main() {
  ClassB s = ClassB('abc', '123');
  print(json.encode(s));
}
