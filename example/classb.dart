library classb;

import 'dart:convert';

/// Stupid example class. Does almost nothing. But simply :)
class ClassB {
  /// arbitrary member s1
  String s1;

  /// arbitrary member s2
  String s2;

  /// constructor. No surprise!
  ClassB(this.s1, this.s2);

  /// create a ClassB instance from a map
  ClassB.fromMap(aMap)
      : s1 = aMap['s1'],
        s2 = aMap['s2'];

  /// ClassB instances will be expressible in JSON
  Map<String, dynamic> toJson() => {'s1': s1, 's2': s2};
}

/// a quick test, just to be sure...
void main() {
  var s = ClassB('abc', '123');
  print(json.encode(s));
}
