import Foundation
import UIKit

class OptionalTestClass {
    // Optional properties - these should NOT create phantom nodes
    var optionalString: String?
    var optionalImage: UIImage?
    var optionalInt: Int?
    var optionalArray: [String]?
    
    // Array properties - should extract element type
    var stringArray: [String]
    var imageArray: [UIImage]
    
    // Generic properties
    var dictionary: Dictionary<String, Int>
    var optionalDictionary: Dictionary<String, UIImage>?
    
    init() {
        self.stringArray = []
        self.imageArray = []
        self.dictionary = [:]
    }
    
    // Methods with optional parameters and return types
    func processOptional(_ text: String?) -> String? {
        return text?.uppercased()
    }
    
    func loadImage(named name: String?) -> UIImage? {
        guard let name = name else { return nil }
        return UIImage(named: name)
    }
    
    func processArray(_ items: [String]?) -> [String]? {
        return items?.map { $0.uppercased() }
    }
}

extension OptionalTestClass {
    // Extension with optional types
    var extensionOptional: String? {
        return optionalString?.uppercased()
    }
    
    func extensionMethod(with value: UIImage?) -> UIImage? {
        return value
    }
}