import UIKit

// Simple inheritance chain test
class A: NSObject {
    var propA: String = ""
}

class B: A {
    var propB: Int = 0
    var dependency: SomeOtherClass = SomeOtherClass()
}

class C: B {
    var propC: Bool = false
    var anotherDep: AnotherClass = AnotherClass()
}

class D: C {
    var propD: Double = 0.0
}

// Unrelated classes that should be filtered out in inheritance mode
class SomeOtherClass: NSObject {
    var data: String = ""
}

class AnotherClass: NSObject {
    var value: Int = 0
}

class UnrelatedClass: NSObject {
    var something: String = ""
}