typealias MyAlias = String

protocol MyProtocol {}

protocol MyGenericProtocol {
  associatedtype MyAssociatedType
}

enum MyEnum {
  case myCase
}

enum MyGenericEnum<MyProtocol> {}

enum MyStringEnum: String {
  case myStringCase = "myStringCaseValue"
}

struct MyStruct {}

struct MyGenericStruct<MyProtocol> {}

struct MyVeryGenericStruct<MyGenericProtocol> {
  typealias MyAssociatedType = MyProtocol
}

class MyClass {}

class MyClass: NSObject {}
