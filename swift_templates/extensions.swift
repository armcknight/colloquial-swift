protocol A {}
protocol B {}

class MyClass{}

extension MyClass {
  func foo() {}
}

extension MyClass: 
A, B {}

extension String {
    enum InnerEnum {
        case a
        case b
    }
}
