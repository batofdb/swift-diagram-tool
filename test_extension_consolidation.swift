import Foundation

class TestClass {
    var baseProperty: String = "base"
    
    func baseMethod() -> String {
        return "base"
    }
}

extension TestClass {
    var extensionProperty1: Int {
        return 1
    }
    
    func extensionMethod1() -> Int {
        return 1
    }
}

extension TestClass {
    var extensionProperty2: Bool {
        return true
    }
    
    func extensionMethod2() -> Bool {
        return false
    }
}

extension TestClass {
    convenience init(value: String) {
        self.init()
        self.baseProperty = value
    }
    
    static func staticExtensionMethod() -> String {
        return "static"
    }
}