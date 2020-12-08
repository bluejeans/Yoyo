// Copyright © 2020 Blue Jeans Network, Inc.

import Foundation

/**
 A read-only property that interoperates
 with Objective-C, allowing it to be used in key-value observing
 and Cocoa bindings.
 
 In order to comply with Objective-C, this class has
 certain restrictions. As such, you should use this class
 only for KVO. Those restrictions are:
 
 1. Only `NSObject`s (and subclasses) can be used with
 this property. Modern Swift objects that do not meet
 this criteria will not work.
 2. Generics do not work with Objective-C, so the `value`
 property is not type-safe (it is always `NSObject`)
 3. The `value` property is `dynamic`, which
 can have performance implications.
 
 To use this class, pass an existing `Property` to the
 global function `makeKVOCompatible()`. The `value` property of
 the `KVOCompatibleProperty` will then remain in sync with the existing value.

 ````
 @objc dynamic private(set) var messageKVO: KVOCompatibleProperty!

 init() {
     let message: Property<String>
     messageKVO = makeKVOCompatible(message)
 }
 ````
 
 - Warning: **Do not use this class for two-way data binding**. If you
 do, the `value` property may change but the parent
 property will not be updated. Use `TwoWayKVOCompatibleProperty`
 instead.
 */
public final class KVOCompatibleProperty: NSObject {

    @objc public dynamic var value: AnyObject? {
        get {
            return _value
        }
        set { // swiftlint:disable:this unused_setter_value
            // do nothing
        }

    }
    @objc fileprivate(set) public dynamic var _value: NSObject?
    private let parentProperty: NSObject // need to retain reference to parent

    fileprivate init(parentProperty: NSObject) {
        self.parentProperty = parentProperty
    }

    fileprivate func subscribeToParentOnChangeCallback<T>(forParent parent: Property<T>) {
        parent.onChange { [weak self] in
            guard let stelf = self, let parentProperty = stelf.parentProperty as? Property<T> else {
                return
            }
            stelf._value = (parentProperty.value as! NSObject) // swiftlint:disable:this force_cast
        }
    }

    fileprivate func subscribeToParentOnChangeCallback<T>(forParent parent: Property<T?>) {
        /* WTF why is this duplicated? Because this function allows for optionals and the above does not.
         And we can't just constrain T: NSObject because this will rule out Int and the like.
         */
        parent.onChange { [weak self] in
            guard let stelf = self, let parentProperty = stelf.parentProperty as? Property<T?> else {
                return
            }
            stelf._value = (parentProperty.value as! NSObject?) // swiftlint:disable:this force_cast
        }
    }

    @objc class func keyPathsForValuesAffectingValue() -> Set<String> {
        return Set(["_value"])
    }
}

/**
 Creates a `KVOCompatibleProperty` from an existing `Property`.
 See `KVOCompatibleProperty` for details
 */
public func makeKVOCompatible<T>(_ parentProperty: Property<T>) -> KVOCompatibleProperty {
    /* WTF why a global function? Because generic initializers
     seem to be horribly bugged, and if the whole class is
     generic, Objective-C interop won't work. Joy!
     */
    guard let value = parentProperty.value as? NSObject else {
        Crasher.crash(message: "Cannot make property KVO-compliant. Type \(T.self) cannot be converted to NSObject")
    }
    let property = KVOCompatibleProperty(parentProperty: parentProperty)
    property._value = value
    property.subscribeToParentOnChangeCallback(forParent: parentProperty)
    return property
}

/**
 Creates a `KVOCompatibleProperty` from an existing `Property`.
 See `KVOCompatibleProperty` for details
 */
public func makeKVOCompatible<T>(_ parentProperty: Property<T?>) -> KVOCompatibleProperty {
    /* WTF why is this duplicated? Because this function allows for optionals and the above does not.
     And we can't just constrain T: NSObject because this will rule out Int and the like.
     */
    guard let value = parentProperty.value as? NSObject? else {
        Crasher.crash(message: "Cannot make property KVO-compliant. Type \(T.self) cannot be converted to NSObject?")
    }
    let property = KVOCompatibleProperty(parentProperty: parentProperty)
    property._value = value
    property.subscribeToParentOnChangeCallback(forParent: parentProperty)
    return property
}

// MARK: - Two-way data binding

/**
 A writable version of `KVOCompatibleProperty` that can
 be used with two-way data binding.
 
 If the parent property's value changes, this
 class's `value` property will be updated, thus
 updating any KVO observers (e.g. Cocoa bindings).
 
 Symmetrically, if binding changes this class's `value`
 property, then the parent property's value will be
 updated in response.
 
 To use this class, pass an existing `Property` to
 global function `makeTwoWayKVOCompatible`.
 
 See `KVOCompatibleProperty` for the limitations of
 KVO interoprability.
 */
public final class TwoWayKVOCompatibleProperty: NSObject {
    private var updateFunction: ((TwoWayKVOCompatibleProperty) -> Void)
    private let parentProperty: NSObject // need to retain reference to parent
    private var updatingParent = false

    @objc public dynamic var value: Any? {
        didSet {
            updatingParent = true
            updateFunction(self)
            updatingParent = false
        }
    }

    fileprivate init(parentProperty: NSObject, updateFunction: @escaping ((TwoWayKVOCompatibleProperty) -> Void)) {
        self.updateFunction = updateFunction
        self.parentProperty = parentProperty
        super.init()
    }

    fileprivate func subscribeToParentOnChangeCallback<T>(forParent parent: Property<T>) {
        parent.onChange { [weak self] in
            guard let stelf = self, !stelf.updatingParent, let parentProperty = stelf.parentProperty as? Property<T> else {
                return
            }

            let value = parentProperty.value
            stelf.value = value
        }
    }

    fileprivate func subscribeToParentOnChangeCallback<T>(forParent parent: Property<T?>) {
        /* WTF why is this duplicated? Because this function allows for optionals and the above does not.
         And we can't just constrain T: NSObject because this will rule out Int and the like.
         */
        parent.onChange { [weak self] in
            guard let stelf = self, !stelf.updatingParent, let parentProperty = stelf.parentProperty as? Property<T?> else {
                return
            }
            let value = parentProperty.value
            stelf.value = value
        }
    }
}

/**
 Creates a `TwoWayKVOCompatibleProperty` from an existing `Property`.
 See `TwoWayKVOCompatibleProperty` for details
*/
public func makeTwoWayKVOCompatible<T>(_ parentProperty: StoredProperty<T>) -> TwoWayKVOCompatibleProperty {
    /* WTF why a global function? Because generic initializers
     seem to be horribly bugged, and if the whole class is
     generic, Objective-C interop won't work. Joy!
     */
    let updateFunction: ((TwoWayKVOCompatibleProperty) -> Void) = { selfParameter in
        if let value = selfParameter.value as? T {
            parentProperty.value = value
        } else {
            NSLog("Invalid value of type \(type(of: selfParameter.value)) passed to KVO compatible property")
        }
    }
    guard let value = parentProperty.value as? NSObject else {
        Crasher.crash(message: "Cannot make property KVO-compliant. Type \(T.self) cannot be converted to NSObject")
    }
    let property = TwoWayKVOCompatibleProperty(parentProperty: parentProperty, updateFunction: updateFunction)
    property.value = value
    property.subscribeToParentOnChangeCallback(forParent: parentProperty)
    return property
}

/**
 Creates a `TwoWayKVOCompatibleProperty` from an existing `Property`.
 See `TwoWayKVOCompatibleProperty` for details
 */
public func makeTwoWayKVOCompatible<T>(_ parentProperty: StoredProperty<T?>) -> TwoWayKVOCompatibleProperty {
    /* WTF why is this duplicated? Because this function allows for optionals and the above does not.
     And we can't just constrain T: NSObject because this will rule out Int and the like.
     */
    let updateFunction: ((TwoWayKVOCompatibleProperty) -> Void) = { selfParameter in
        if let value = selfParameter.value as? T? {
            parentProperty.value = value
        } else {
            NSLog("Invalid value of type \(type(of: selfParameter.value)) passed to KVO compatible property")
        }
    }
    guard let value = parentProperty.value as? NSObject? else {
        Crasher.crash(message: "Cannot make property KVO-compliant. Type \(T?.self) cannot be converted to NSObject?")
    }
    let property = TwoWayKVOCompatibleProperty(parentProperty: parentProperty, updateFunction: updateFunction)
    property.value = value
    property.subscribeToParentOnChangeCallback(forParent: parentProperty)
    return property
}
