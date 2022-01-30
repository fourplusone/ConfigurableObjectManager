import XCTest
@testable import ConfigurableObjectManager


struct MockConfiguration: Identifiable, Hashable {
    var id: Int
    var name = "AnyService"
}

class MockObject: Configurable {
    typealias Configuration = MockConfiguration
    
    var id: Int
    var name: String
    
    required init(configuration: MockConfiguration) {
        self.id = configuration.id
        self.name = configuration.name
    }
}

class ActivatableMockObject: MockObject, Activatable {
    var activated = false
    
    func activate() {
        activated = true
    }
    
    func deactivate() {
        activated = false
    }
}

class ReconfigurableMockObject: ActivatableMockObject, Reconfigurable {
    typealias Configuration = MockConfiguration

    func reconfigure(with configuration: MockConfiguration) {
        self.id = configuration.id
        self.name = configuration.name
    }
}

final class ConfigurableObjectManagerTests: XCTestCase {
    func testInstanciation() throws {
        let manager = ConfigurableObjectManager<MockObject>()
        let id = 10
        manager.update(configurations: [
            MockConfiguration(id: id)
        ])
        
        let object = manager.object(for: id)
        
        XCTAssertNotNil(object, "Object must exist")
        XCTAssertEqual(object?.id, id, "Object ID must exist match configuration")
        XCTAssertNil(manager.object(for: id+1), "Object for non existent ID must not exist")
        
        manager.update(configurations: [])
        XCTAssertNil(manager.object(for: id), "Object must not exist")
        
    }
    
    func testActivation() throws {
        let manager = ConfigurableObjectManager<ActivatableMockObject>()
        let id = 10
        manager.update(configurations: [
            MockConfiguration(id: id)
        ])
        
        guard let object = manager.object(for: id) else {
            return XCTFail("Object must exist")
        }
        
        XCTAssertTrue(object.activated, "Object must have been activated")
        
        manager.update(configurations: [])
        XCTAssertFalse(object.activated, "Object must have been deactivated")
    }
    
    func testReconfiguration() throws {
        let manager = ConfigurableObjectManager<ReconfigurableMockObject>()
        let id = 10
        var configuration = MockConfiguration(id: id)
        
        manager.update(configurations: [
            configuration
        ])
        
        guard let object = manager.object(for: id) else {
            return XCTFail("Object must exist")
        }
        
        configuration.name = "Another Name"
        manager.update(configurations: [configuration])
        XCTAssertTrue(object.activated, "Object must be activated")
        XCTAssert(object === manager.object(for: id))
        
        manager.update(configurations: [])
        XCTAssertFalse(object.activated, "Object must be deactivated")
    }
}
