// basic
func foo1() {}

// with parameter
func foo2(bar: Any) {}

// with eponymous parameter
func foo3(_ bar: Any) {}

// with named parameter
func foo4(with bar: Any) {}

// with return type
func foo5() -> Any { return "Hello world" }

// with closure parameter
func foo6(closure: ((Any) -> (Bool))) {}

// with closure return type
func foo7() -> ((Any) -> (Bool)) { 
  return { arg in
    return true
  }
}

// parameters across newlines
func foo8(one: Any,
two: Any,
three: Any) {}
