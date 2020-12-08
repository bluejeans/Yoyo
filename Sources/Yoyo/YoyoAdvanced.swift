// Copyright © 2020 Blue Jeans Network, Inc.

import Foundation

/**
 An observable property whose value is backed by
 a parent property. Usually, the value of this property is
 is the same as the parent property's value. However, this
 property's value can be temporarily changed to another value.
 
 This temporary value is referred to as the "tentative value".
 When creating this property, you specify how long a tentative
 value is good for. When you set a tentative value, a timer
 starts. When the timer expires, the tentative value is
 erased and the value of this property goes back to the value
 of the parent property.
 
 Alternatively, you can omit the timer and erase the tentative
 value yourself by calling `revertTentative()` based on your
 own logic.
 
 This type of property is useful for dealing with asynchronous
 operations that may take a while to reflect in the authoritative
 data store but that you wish to appear instantaneous locally. For
 instance, when sending a chat message, you want that message
 to show up immediately, even if the server has not yet
 updated its list of messages.

 # Example
 ````
 private let serverName: Property<String>
 let name: TentativeProperty<String>

 init() {
     name = TentativeProperty(parentProperty: serverName, tenativeValueValidForMS: 3000)
 }

 func setNameAsynchronously(_ value: String) {
     name.value = value

     api.updateName(value, successCallback: {}, failureCallback: { [weak self] in
         self?.name.revertTentative()
     })
 }
 ````
 */
public final class TentativeProperty<T>: Property<T> {
    private var parentPropertySubscription: Subscription<T>!
    private let tenativeValueValidForMS: Int?
    private var tentativeResetTimer: CancellableTimer?
    private var internalSet = false

    override public var value: T {
        didSet {
            if !internalSet {
                becomeTentative()
            }
        }
    }

    public init(parentProperty: Property<T>, tenativeValueValidForMS: Int?, changePredicate: @escaping (T, T) -> Bool) {

        self.tenativeValueValidForMS = tenativeValueValidForMS

        super.init(initialValue: parentProperty.value, changePredicate: changePredicate)

        parentPropertySubscription = parentProperty.subscribe({ [unowned self] in self.updateIfAppropriate() })

        self.updateIfAppropriate()
    }

    private func becomeTentative() {
        if let existingTimer = tentativeResetTimer {
            existingTimer.cancel()
        }
        if let nnTenativeValueValidForMS = tenativeValueValidForMS {
            tentativeResetTimer = CancellableTimer.runAfter(ms: nnTenativeValueValidForMS, queue: DispatchQueue.main) { [weak self] in
                self?.revertTentative()
            }
        }
    }

    public func revertTentative() {
        if let existingTimer = tentativeResetTimer {
            existingTimer.cancel()
        }
        tentativeResetTimer = nil
        updateIfAppropriate()
    }

    private func updateIfAppropriate() {
        if tentativeResetTimer == nil {
            internalSet = true
            value = parentPropertySubscription.value
            internalSet = false
        }
    }
}

extension TentativeProperty where T: Equatable {
    public convenience init(parentProperty: Property<T>, tenativeValueValidForMS: Int?) {
        self.init(parentProperty: parentProperty, tenativeValueValidForMS: tenativeValueValidForMS, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension TentativeProperty {
    public convenience init(parentProperty: Property<T>, tenativeValueValidForMS: Int?) {
        self.init(parentProperty: parentProperty, tenativeValueValidForMS: tenativeValueValidForMS, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A variant of `PassThroughProperty` where the parent property
 can be changed.
 
 When created, this property is in an "unconnected" state
 where its value is set to a static value. Once you "connect"
 another property, this property's value will be kept up  to date
 with the property you connect. You can connect new properties
 repeatedly.
 
 You can also connect a constant value. This allows an object
 to expose an API that accepts both a constant value OR a
 property.

 The main reason to use this property is to set up
 an observable property whose value depends on another property
 that it doesn't know about. Instead, the second property (the one
 being depended on) knows about the
 first property. This is the reverse of most properties
 (e.g. `DerivedProperty`), who know about the properties they depend on.
 
 - Note: In general, declarative, immutable relationships
 are considerably easier to reason about, so use of this
 type of property should be limited!
 */
public final class ConnectableProperty<T>: Property<T> {
    private var connectedPropertySubscription: Subscription<T>?

    public init(unconnectedValue: T, changePredicate: @escaping (T, T) -> Bool) {
        super.init(initialValue: unconnectedValue, changePredicate: changePredicate)
    }

    public func connect(_ connectedProperty: Property<T>) {
        connectedPropertySubscription = connectedProperty.subscribe({ [unowned self] in self.update() })

        self.update()
    }

    public func connect(constant: T) {
        value = constant
    }

    private func update() {
        guard let subscription = connectedPropertySubscription else {
            return
        }
        value = subscription.value
    }
}

extension ConnectableProperty where T: Equatable {
    public convenience init(unconnectedValue: T) {
        self.init(unconnectedValue: unconnectedValue, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension ConnectableProperty {
    public convenience init(unconnectedValue: T) {
        self.init(unconnectedValue: unconnectedValue, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A property representing a sub-property of another property.
 
 Consider the case where you have a property whose value is
 an object, itself containing properties, and you want to
 represent the value of one of these child properties. A
 simple strategy would be to simply wrap the child property
 in a `PassThroughProperty`. However, the outer property might
 change the object it is pointing to. In this case, you may
 want to re-evaluate the entire chain. `MultilevelProperty`
 does this.

 To use, pass the outer property as the first argument to the
 initializer, and then pass a closure as the second argument. The
 closure should take the value of the outer property and return the
 inner property representing the final value.

 This implementation does not allow the closure to return nil, which
 may be needed if the outer property returns an optional value. In this
 case, you should use `MultilevelOptionalProperty.`

 With the inclusion of keypaths in Swift 4, you may now pass a
 keypath instead a closure as a second argument. This keypath should
 represent the inner propery relative to the value of the outer
 property.

 # Example

 Imagine you have a `Property<Person>` and
 `Person` has a property `name`, which is a `Property<String>`.
 `MultilevelProperty` can be used to construct a `personName` property
 that will update if the outer property changes which `Person` it points to
 or if the `Person`'s `name` changes.

 ````
 class Person {
     let name: Property<String>
 }

 let person: Property<Person>
 let personName = MultilevelProperty(parentProperty: person, childSelector: { person in
     return person.name
 })
 ````
 */
public final class MultilevelProperty<P, T>: Property<T> {
    private var parentPropertySubscription: Subscription<P>!
    private let childSelector: (P) -> Property<T>
    private var currentInnerSubscription: Subscription<T>!

    public init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>, changePredicate: @escaping (T, T) -> Bool) {
        self.childSelector = childSelector

        super.init(initialValue: childSelector(parentProperty.value).value, changePredicate: changePredicate)

        parentPropertySubscription = parentProperty.subscribe({ [unowned self] in self.updateFromParent() })

        updateFromParent()
    }

    public convenience init<Y>(parentProperty: Property<P>, childKeyPath: KeyPath<P, Y>, changePredicate: @escaping (T, T) -> Bool) where Y: Property<T> {

        let childSelector: ((P) -> Property<T>) = { parentPropertyValue in
            return parentPropertyValue[keyPath: childKeyPath]
        }

        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: changePredicate)
    }

    private func updateFromParent() {
        let currentInner = childSelector(parentPropertySubscription.value)
        currentInnerSubscription = currentInner.subscribe { [unowned self] in
            self.value = self.currentInnerSubscription.value
        }
        self.value = currentInnerSubscription.value
    }
}

extension MultilevelProperty where T: Equatable {
    public convenience init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<Y>(parentProperty: Property<P>, childKeyPath: KeyPath<P, Y>) where Y: Property<T> {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension MultilevelProperty {
    public convenience init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<Y>(parentProperty: Property<P>, childKeyPath: KeyPath<P, Y>) where Y: Property<T> {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A variant of `MultilevelProperty` that allows the inner property
 to be nil, usually because the outer property produced an optional
 value.
 
 Specifically, the closure passed to resolve the inner property may
 return nil. In this case, the value of the entire property will
 also be nil.
 
 Note that if the type of the inner property is already optional,
 the type of this property will then become a double optional. This
 is an unavoidable artifact of the current typing system.
 
 See `MultilevelProperty` for all other details.
*/
public final class MultilevelOptionalProperty<P, T>: Property<T?> {
    private var parentPropertySubscription: Subscription<P>!
    private let childSelector: (P) -> Property<T>?
    private var currentInnerSubscription: Subscription<T>?

    public convenience init<O, Y>(parentProperty: Property<O?>, childKeyPath: KeyPath<O, Y>, changePredicate: @escaping (T?, T?) -> Bool) where P == O?, Y: Property<T> {

        let childSelector: ((O?) -> Property<T>?) = { parentPropertyValue in
            return parentPropertyValue?[keyPath: childKeyPath]
        }

        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: changePredicate)

    }

    public init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>?, changePredicate: @escaping (T?, T?) -> Bool) {
        self.childSelector = childSelector

        super.init(initialValue: childSelector(parentProperty.value)?.value, changePredicate: changePredicate)

        parentPropertySubscription = parentProperty.subscribe({ [unowned self] in self.updateFromParent() })

        updateFromParent()
    }

    private func updateFromParent() {
        let currentInner = childSelector(parentPropertySubscription.value)
        currentInnerSubscription = currentInner?.subscribe { [unowned self] in
            self.value = self.currentInnerSubscription?.value
        }
        self.value = currentInnerSubscription?.value
    }
}

extension MultilevelOptionalProperty where T: Equatable {
    public convenience init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>?) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<O, Y>(parentProperty: Property<O?>, childKeyPath: KeyPath<O, Y>) where P == O?, Y: Property<T> {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension MultilevelOptionalProperty {
    public convenience init(parentProperty: Property<P>, childSelector: @escaping (P) -> Property<T>?) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<O, Y>(parentProperty: Property<O?>, childKeyPath: KeyPath<O, Y>) where P == O?, Y: Property<T> {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A property whose value is the same as its parent property but
 which is updated any time the parent property or any of the specified child
 selector properties is updated. This is useful when you want to do
 deep observation of a collection.

 # Example
 Summing over a property of each item in a list:
 ````
 class Item {
     let intValue: Property<Int>
 }

 let list: Property<[Item]>
 let listCollection = MultilevelCollectionProperty(parentProperty: list, childSelector: { item in
     return [item.intValue]
 })
 let sum = DerivedProperty(listCollection) { list in
     return list.reduce(0, +)
 }
 ````
 A `DerivedProperty` based on `list` would only be calculated when
 the entire list is updated, not when any of the items' `intValue`s
 is updated.
 */
public final class MultilevelCollectionProperty<T, E>: Property<T> where T: Sequence, T.Iterator.Element == E {
    private var parentPropertySubscription: Subscription<T>!
    private let childSelector: (E) -> [UntypedProperty]
    private var currentInnerSubscriptions: [UntypedSubscription]!

    public init(parentProperty: Property<T>, childSelector: @escaping (E) -> [UntypedProperty], changePredicate: @escaping (T, T) -> Bool) {
        self.childSelector = childSelector

        super.init(initialValue: parentProperty.value, changePredicate: changePredicate)

        parentPropertySubscription = parentProperty.subscribe({ [unowned self] in self.updateFromParent() })

        updateFromParent()
    }

    public convenience init<Y>(parentProperty: Property<T>, childKeyPath: KeyPath<E, Y>, changePredicate: @escaping (T, T) -> Bool) where Y: UntypedProperty {

        let childSelector: ((E) -> [UntypedProperty]) = { element in
            return [element[keyPath: childKeyPath]]
        }

        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: changePredicate)
    }

    private func updateFromParent() {
        let currentInners = parentPropertySubscription.value.map {
            return childSelector($0)
        }.joined()
        currentInnerSubscriptions = currentInners.map {
            ($0 as! InternalUntypedProperty).untypedSubscribe { [unowned self] in
                self.triggerOnChangeCallbacks()
            }
        }
        self.value = parentPropertySubscription.value
    }
}

extension MultilevelCollectionProperty where T: Equatable {
    public convenience init(parentProperty: Property<T>, childSelector: @escaping (E) -> [UntypedProperty]) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<Y>(parentProperty: Property<T>, childKeyPath: KeyPath<E, Y>) where Y: UntypedProperty {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}
extension MultilevelCollectionProperty {
    public convenience init(parentProperty: Property<T>, childSelector: @escaping (E) -> [UntypedProperty]) {
        self.init(parentProperty: parentProperty, childSelector: childSelector, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<Y>(parentProperty: Property<T>, childKeyPath: KeyPath<E, Y>) where Y: UntypedProperty {
        self.init(parentProperty: parentProperty, childKeyPath: childKeyPath, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

private class CancellableTimer {
    static func runAfter(ms timeMS: Int, queue: DispatchQueue, callback: @escaping () -> Void ) -> CancellableTimer {
        let runAfterTime = DispatchTime.now() + Double(Int64(timeMS) * Int64(NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)
        let timer = CancellableTimer()
        queue.asyncAfter(deadline: runAfterTime, execute: {
            if !timer.cancelled {
                callback()
            }
        })

        return timer
    }

    static func runAfter(seconds timeSeconds: Int, queue: DispatchQueue, callback: @escaping () -> Void ) -> CancellableTimer {
        return runAfter(ms: timeSeconds * 1000, queue: queue, callback: callback)
    }

    private var cancelled = false

    func cancel() {
        cancelled = true
    }
}
