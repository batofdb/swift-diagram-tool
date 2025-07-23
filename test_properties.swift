import UIKit

class TestPropertiesClass {
    // Simple property (should work)
    var simpleProp: String
    
    // Property with default value + type annotation (FAILING)
    let volumeSidePadding: CGFloat = 10.0
    
    // Optional external type (FAILING)
    var thumbnail: UIImage?
    
    // Property with default value (FAILING)
    var isFullscreenModal: Bool = false
    
    // Type inference property (FAILING)
    var shouldDisableAppearDisappearStateChanges = false
    
    // Property with documentation (FAILING)
    /// Property that holds the volume level (1.0 - 0.0)
    var volume: CGFloat?
    
    init() {
        self.simpleProp = "test"
    }
}