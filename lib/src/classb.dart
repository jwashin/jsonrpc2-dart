library classb;

import 'dart:convert';

class ClassB {
  var s1;
  var s2;
  ClassB(this.s1, this.s2);
  static fromMap(Map aMap) => new ClassB(aMap['s1'], aMap['s2']);
  toJson() => {'s1': s1, 's2': s2};
}

main() {
  ClassB s = new ClassB('abc', '123');
  print(json.encode(s));
}
