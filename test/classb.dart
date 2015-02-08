library classb;

import 'dart:convert';


class ClassB {
  var s1;
  var s2;
  ClassB(this.s1, this.s2);
  toJson(){
    return {'s1':s1,'s2':s2};
  }
}

classBFromMap(Map aMap){
  return new ClassB(aMap['s1'], aMap['s2']);
}

main(){
  ClassB s = new ClassB('abc', '123');

  print (JSON.encode(s));
}