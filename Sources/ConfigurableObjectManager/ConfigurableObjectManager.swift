import Foundation

/// An object, that can be instantiated from a Configuration
public protocol Configurable {
    associatedtype Configuration: Identifiable, Hashable
    init(configuration: Configuration)
}

/// An object, that can be reconfigured while alive
public protocol Reconfigurable: Configurable {
    func reconfigure(with configuration: Configuration)
}

/// An object, that needs to be explicitly activated and deactivated.
public protocol Activatable {
    func activate()
    func deactivate()
}

/// `ConfigurableObjectManager` maintains a set of objects that can be instantiated from a `Configuration`.
///
/// The managed objects needs to conform to the `Configurable` Protocol.
/// Objects conforming to the `Activatable` protocol will automatically be activated / deactivated
///
/// This class is thread-safe
public class ConfigurableObjectManager<Managed> where Managed : Configurable {
    
    public typealias Configuration = Managed.Configuration
    
    private struct Item {
        private(set) var configuration: Configuration
        private(set) var object: Managed
    }
    
    private var managedItems : [Configuration.ID: Item] = [:]
    private var lock = os_unfair_lock_s()
    
    private var updateItem : (_ item: Item?, _ configuration: Configuration?) -> Item?
    
    
    public enum UpdateOrder {
        /// First add new objects, then update existing, then remove old
        case addUpdateRemove
        /// First add new objects, then remove old, then update existing
        case addRemoveUpdate
        
        /// First update existing objects, then remove old, then add new
        case updateAddRemove
        /// First update existing objects, then add new, then remove old
        case updateRemoveAdd
        
        /// First remove old objects, then update existing, then add new
        case removeUpdateAdd
        /// First remove old objects, then add new, then update existing
        case removeAddUpdate
    }
    
    /// Defines in which order a new configuration will be applied
    public var updateOrder: UpdateOrder = .removeAddUpdate
    
    public init() {
        updateItem = { item, configuration -> Item? in
            
            if let object = item?.object as? Activatable {
                object.deactivate()
            }
            
            guard let configuration = configuration else {
                return nil
            }
            
            let newItem = Item(configuration: configuration,
                               object: Managed(configuration: configuration))
            
            if let object = newItem.object as? Activatable {
                object.activate()
            }
            
            return newItem
        }
    }
    
    public init() where Managed : Reconfigurable{
        updateItem = { item, configuration -> Item? in
            
            guard let configuration = configuration else {
                if let object = item?.object as? Activatable {
                    object.deactivate()
                }
                return nil
            }
            
            let newItem: Item
            
            if let item = item {
                item.object.reconfigure(with: configuration)
                newItem = item
            } else {
                if let object = item?.object as? Activatable {
                    object.deactivate()
                }
                
                newItem = Item(configuration: configuration,
                                   object: Managed(configuration: configuration))
                
                if let object = newItem.object as? Activatable {
                    object.activate()
                }
            }
            
            return newItem
        }
    }
    
    /// Update the configuration of a single object. If the object does not exist, it will be instantiated
    /// - Parameter configuration: The configuration to apply
    public func update(configuration: Configuration) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        managedItems[configuration.id] = updateItem(managedItems[configuration.id], configuration)
    }
    
    /// Update the configuration of all objects. If an object does not exist, it will be instantiated, if its not
    /// present anymore, it will be removed.
    /// If the configuration of an existing object has changed and the object conforms to `Reconfigurable` it's
    /// `reconfigure(with:)` method will be called. Otherwise it will be removed and added afterwards
    /// - Parameter configuration: The configuration to apply
    public func update(configurations: Set<Configuration>) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let configurations = Dictionary(uniqueKeysWithValues: configurations.map { ($0.id, $0) })
        
        let newIDs = Set(configurations.keys)
        let currentIDs = Set(managedItems.keys)
        
        let toBeAdded = newIDs.subtracting(currentIDs)
        let toBeRemoved = currentIDs.subtracting(newIDs)
        let toBeUpdated = currentIDs.intersection(newIDs)
        
        
        func update() {
            for id in toBeUpdated {
                managedItems[id] = updateItem(managedItems[id], configurations[id])
            }
        }
        
        func remove() {
            for id in toBeRemoved {
                managedItems[id] = updateItem(managedItems[id], nil)
            }
        }
        
        func add() {
            for id in toBeAdded {
                managedItems[id] = updateItem(managedItems[id], configurations[id])
            }
        }
        
        switch updateOrder {
        case .addUpdateRemove:
            add()
            update()
            remove()
        case .addRemoveUpdate:
            add()
            remove()
            update()
        case .updateAddRemove:
            update()
            add()
            remove()
        case .updateRemoveAdd:
            update()
            remove()
            add()
        case .removeUpdateAdd:
            remove()
            update()
            add()
        case .removeAddUpdate:
            remove()
            add()
            update()
        }
    }
    
    public func object(for id: Configuration.ID) -> Managed? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return managedItems[id]?.object
    }
}
