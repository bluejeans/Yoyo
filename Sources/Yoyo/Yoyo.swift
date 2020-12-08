// Copyright © 2020 Blue Jeans Network, Inc.

import Foundation

/**
 A generics-less representation of a generic property. Allow a reference to
 a property without caring about what type it is.
 
 See `Property` for more documentation.

 - Warning: DO NOT implement this yourself. If you want to make you own property, subclass
 `Property` instead. `Property` already conforms to this protocol.
*/
public protocol UntypedProperty: class {
    @discardableResult func onChange(_ callback: @escaping () -> Void) -> CallbackId
    func unsubscribeFromChanges(_ id: CallbackId)
}

internal protocol InternalUntypedProperty: UntypedProperty {
    func untypedSubscribe(_ callback: @escaping () -> Void) -> UntypedSubscription
    var unsafeValue: Any { get }
    var unsafeValueType: Any.Type { get }
    func unsafeSetValue(_ value: Any)
}

/**
 An opaque identifier that can be used to unsubscribe from change notifications.
 However, it is recommended for external users to react to changes using `YoyoUpdater`,
 which cancels its subscription whens it is deallocated, instead of using this.
 */
public typealias CallbackId = String

private struct OnChangeHolder {
    let id: CallbackId
    let callback: () -> Void
}

internal protocol UntypedSubscription {
    func unsubscribe()
}

/**
 An alternative to `CallbackId` for unsubscribing. When you
 `subscribe()` to a `Property` you will get one of these.
 To cancel this subscription, instead of explictly calling
 a function, you merely need to allow this object to be
 deallocated.

 This allows objects to easily ensure they do not retain
 subscriptions after deallocation. When the object is
 deallocated, all the subcriptions it holds are deallocated
 and are therefore cancelled.
*/
internal class Subscription<T>: UntypedSubscription {
    private let property: Property<T>
    private let callbackId: CallbackId

    internal var value: T {
        return property.value
    }

    internal init(property: Property<T>, callbackId: CallbackId) {
        self.property = property
        self.callbackId = callbackId
    }

    internal func unsubscribe() {
        property.unsubscribeFromChanges(callbackId)
    }

    deinit {
        unsubscribe()
    }
}

/**
 Convenience change predicates that can be used when initializing a property to specify when
 updates will be triggered in response to the property's value changing.
 Most properties have initializers with default change predicates, so you should rarely
 need to use these directly.
 */
public class ChangePredicates {
    public static func equatableChangePredicate<S: Equatable>(old: S, new: S) -> Bool {
        return old != new
    }

    public static func equatableChangePredicate<S: Equatable>(old: S?, new: S?) -> Bool {
        return old != new
    }

    public static func identityChangePredicate<T>(old: T, new: T) -> Bool {
        // DRAGONS: If T is a value type, in Swift 3 it will be boxed and
        // and the cast to AnyObject will succeed. But equality will always
        // be false for boxed types. Fortunately this is exactly what we
        // want - value types are always changes if using this predicate.
        return (old as AnyObject) !== (new as AnyObject)
    }

    public static func alwaysChangePredicate<T>(old: T, new: T) -> Bool {
        return true
    }
}

/**
 The basic functionality of an observable property.
 
 The property's value is accessible via the read-only `value`
 property. Clients can receive a notification when this value
 changes via the `onChange()` method; however, using `YoyoUpdater`
 is recommended over `onChange()`.
 
 If you want to observe this property using key-value observing,
 you need to jump through some hoops. See `KVOCompatibleProperty` for
 details.
 
 This class is the generic superclass of all properties and
 is therefore not instantiable. Use `StoredProperty`, `DerivedProperty`,
 etc. instead.
 */
open class Property<T>: NSObject, InternalUntypedProperty, UntypedProperty {
    private var onChangeCallbacks = ContiguousArray<OnChangeHolder>()
    private var triggering = false
    private var unsubscribedDuringTrigger: Set<CallbackId> = []
    let changePredicate: (T, T) -> Bool

    internal(set) public var value: T {
        didSet {
            if changePredicate(oldValue, value) {
                triggerOnChangeCallbacks()
            }
        }
    }

    init(initialValue: T, changePredicate: @escaping (T, T) -> Bool) {
        value = initialValue
        self.changePredicate = changePredicate

        super.init()
    }

    @discardableResult
    public final func onChange(_ callback: @escaping () -> Void) -> CallbackId {
        let id: CallbackId = UUID().uuidString
        onChangeCallbacks.append(OnChangeHolder(id: id, callback: callback))
        return id
    }

    internal final func subscribe(_ callback: @escaping () -> Void) -> Subscription<T> {
        let callbackId = onChange(callback)
        return Subscription(property: self, callbackId: callbackId)
    }

    internal final func untypedSubscribe(_ callback: @escaping () -> Void) -> UntypedSubscription {
        return subscribe(callback)
    }

    public final func unsubscribeFromChanges(_ id: CallbackId) {
        guard let index = onChangeCallbacks.firstIndex(where: { $0.id == id }) else { return }
        onChangeCallbacks.remove(at: index)
        if triggering {
            unsubscribedDuringTrigger.insert(id)
        }
    }

    final func triggerOnChangeCallbacks() {
        let onChangeCallbacks = self.onChangeCallbacks
        unsubscribedDuringTrigger = []
        triggering = true
        // apparently iterating this way is MUCH faster that foreach... sigh
        for i in 0..<onChangeCallbacks.count {
            if !unsubscribedDuringTrigger.contains(onChangeCallbacks[i].id) {
                onChangeCallbacks[i].callback()
            }
        }
        triggering = false

    }

    internal var _testOnly_numberOfOnChangeCallbacks: Int {
        return onChangeCallbacks.count
    }

    var unsafeValue: Any {
        return value
    }

    var unsafeValueType: Any.Type {
        return T.self
    }

    func unsafeSetValue(_ value: Any) {
        guard let safeValue = value as? T else {
            fatalError("Wrong type used in unsafeSetValue")
        }
        self.value = safeValue
    }
}

/**
 A writable observable property whose value
 can be set directly.
 
 To change the value of the property, assign a
 new value to the `value` property.
 
 You must specify an initial value for the property in
 the initializer.
*/
public final class StoredProperty<T>: Property<T> {
    override public var value: T {
        didSet {}
    }

    public init(_ initialValue: T, changePredicate: @escaping (T, T) -> Bool) {
        super.init(initialValue: initialValue, changePredicate: changePredicate)
    }
}

extension StoredProperty where T: Equatable {
    public convenience init(_ initialValue: T) {
        self.init(initialValue, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension StoredProperty {
    public convenience init(_ initialValue: T) {
        self.init(initialValue, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A read-only observable property whose value
 is derived from one or more other observable properties.
 
 The initializer for this property takes a variable number
 of arguments. Pass all of the properties you want to use
 as input to your derivation calculation.

 The last argument to the initializer should be a "calculator"
 function that takes as many arguments as you previously
 passed to the initalizer. This function will be invoked
 with parameters representing the current values of each of
 the input properties. Note the type of these parameters will
 be the type of the values themselves - there is no need
 to call `.value` on the parameters as they are not `Property`
 objects.

 The calculator function should perform some kind of computation
 on the inputs to produce a new value and return it. This
 value will become the new value of the `DerivedProperty`.

 - Important: In almost all cases, the calculator function should be a
 "pure" function that does not affect or reference any outside
 state and does. Be careful to always reference the values
 passed as parameters to the calculator function rather than
 retaining a reference to a value from an enclosing scope!

 # Example
 ````
 let width: Property<Int>
 let height: Property<Int>
 let area = DerivedProperty(width, height) { width, height in
     return width * height
 }
 ````
*/
public final class DerivedProperty<T>: Property<T> {
    private let calculate: () -> T
    private var dependencySubscriptions: [UntypedSubscription]!

    /// DO NOT use unless absolutely necessary. Use other initializers instead.
    public init(dependencies: [UntypedProperty], calculator: @escaping () -> T, changePredicate: @escaping (T, T) -> Bool) {
        self.calculate = calculator

        super.init(initialValue: calculator(), changePredicate: changePredicate)

        self.dependencySubscriptions = dependencies.map { dependency in
            return (dependency as! InternalUntypedProperty).untypedSubscribe { [unowned self] in
                self.update()
            }
        }
    }

    private func update() {
        value = calculate()
    }
}

// swiftlint:disable line_length
extension DerivedProperty where T: Equatable {
    public convenience init(dependencies: [UntypedProperty], calculator: @escaping () -> T) {
        self.init(dependencies: dependencies, calculator: calculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    // Yes, despite what the documentation says, dependencies aren't varargs. We actually need to create
    // a method for each possible number of dependencies. For this reason, we actually support only
    // 1-10 dependencies.

    public convenience init<A>(_ dep1: Property<A>, calculator: @escaping (A) -> T) {
        let innerCalculator = { calculator(dep1.value) }
        self.init(dependencies: [dep1], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B>(_ dep1: Property<A>, _ dep2: Property<B>, calculator: @escaping (A, B) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value) }
        self.init(dependencies: [dep1, dep2], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, calculator: @escaping (A, B, C) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value) }
        self.init(dependencies: [dep1, dep2, dep3], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, calculator: @escaping (A, B, C, D) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, calculator: @escaping (A, B, C, D, E) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E, F>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, calculator: @escaping (A, B, C, D, E, F) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, calculator: @escaping (A, B, C, D, E, F, G) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, calculator: @escaping (A, B, C, D, E, F, G, H) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H, I>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, _ dep9: Property<I>, calculator: @escaping (A, B, C, D, E, F, G, H, I) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value, dep9.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8, dep9], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H, I, J>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, _ dep9: Property<I>, _ dep10: Property<J>, calculator: @escaping (A, B, C, D, E, F, G, H, I, J) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value, dep9.value, dep10.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8, dep9, dep10], calculator: innerCalculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension DerivedProperty {
    public convenience init(dependencies: [UntypedProperty], calculator: @escaping () -> T) {
        self.init(dependencies: dependencies, calculator: calculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    // Yes, despite what the documentation says, dependencies aren't varargs. We actually need to create
    // a method for each possible number of dependencies. For this reason, we actually support only
    // 1-10 dependencies.

    public convenience init<A>(_ dep1: Property<A>, calculator: @escaping (A) -> T) {
        let innerCalculator = { calculator(dep1.value) }
        self.init(dependencies: [dep1], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B>(_ dep1: Property<A>, _ dep2: Property<B>, calculator: @escaping (A, B) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value) }
        self.init(dependencies: [dep1, dep2], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, calculator: @escaping (A, B, C) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value) }
        self.init(dependencies: [dep1, dep2, dep3], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, calculator: @escaping (A, B, C, D) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, calculator: @escaping (A, B, C, D, E) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E, F>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, calculator: @escaping (A, B, C, D, E, F) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, calculator: @escaping (A, B, C, D, E, F, G) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, calculator: @escaping (A, B, C, D, E, F, G, H) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H, I>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, _ dep9: Property<I>, calculator: @escaping (A, B, C, D, E, F, G, H, I) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value, dep9.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8, dep9], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }

    public convenience init<A, B, C, D, E, F, G, H, I, J>(_ dep1: Property<A>, _ dep2: Property<B>, _ dep3: Property<C>, _ dep4: Property<D>, _ dep5: Property<E>, _ dep6: Property<F>, _ dep7: Property<G>, _ dep8: Property<H>, _ dep9: Property<I>, _ dep10: Property<J>, calculator: @escaping (A, B, C, D, E, F, G, H, I, J) -> T) {
        let innerCalculator = { calculator(dep1.value, dep2.value, dep3.value, dep4.value, dep5.value, dep6.value, dep7.value, dep8.value, dep9.value, dep10.value) }
        self.init(dependencies: [dep1, dep2, dep3, dep4, dep5, dep6, dep7, dep8, dep9, dep10], calculator: innerCalculator, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

// swiftlint:enable line_length

/**
 A read-only observable property whose value
 is derived from a calculator. The value will only be updated
 when `recalculate()` is called.
 
 This property is useful for adapting from non-Yoyo properties
 while making it clear that the property is derived.
 */
public final class ManuallyRecalculatedDerivedProperty<T>: Property<T> {
    private let calculate: () -> T

    public init(calculator: @escaping () -> T, changePredicate: @escaping (T, T) -> Bool) {
        self.calculate = calculator

        super.init(initialValue: calculator(), changePredicate: changePredicate)
    }

    public final func recalculate() {
        value = calculate()
    }
}

extension ManuallyRecalculatedDerivedProperty where T: Equatable {
    public convenience init(calculator: @escaping () -> T) {
        self.init(calculator: calculator, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension ManuallyRecalculatedDerivedProperty {
    public convenience init(calculator: @escaping () -> T) {
        self.init(calculator: calculator, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 A special case of `DerivedProperty` where the value
 of the property is always the same as the supplied
 parent property.
 
 This is useful for exposing another class's property
 while encapsulating access to that class itself. It
 can also serve as a placeholder that may be replaced
 with a more complicated `DerivedProperty` later.
 */
public final class PassThroughProperty<T>: Property<T> {
    private var parentPropertySubscription: Subscription<T>!

    public init(parentProperty: Property<T>, changePredicate: @escaping (T, T) -> Bool) {

        super.init(initialValue: parentProperty.value, changePredicate: changePredicate)

        parentPropertySubscription = parentProperty.subscribe { [unowned self] in
            self.update() // dependency doesn't need to update us if we've been deallocated
        }

        self.update()
    }

    private func update() {
        value = parentPropertySubscription.value
    }
}

extension PassThroughProperty where T: Equatable {
    public convenience init(parentProperty: Property<T>) {
        self.init(parentProperty: parentProperty, changePredicate: ChangePredicates.equatableChangePredicate)
    }
}

extension PassThroughProperty {
    public convenience init(parentProperty: Property<T>) {
        self.init(parentProperty: parentProperty, changePredicate: ChangePredicates.identityChangePredicate)
    }
}

/**
 An object that handles performing updates in reaction to state changes. These are typically updates
 on an external source, such as UI updates.
 
 Every object that needs to perform these side effects should create
 one (or more) of these. If the updater is calculating the value of a `Property`,
 a `DerivedProperty` may be more appropriate.
 * `keepUpToDate()` runs a function
 every time the value of one or more `Property` objects changes. The
 function will be also run immediately upon subscription to ensure the
 initial state of the supplied properties is taken into account. In general,
 this should be used for idempotent updates of external
 properties, such as updating UI elements to reflect application state.
 ````
 updater.keepUpToDate(dependencies: [showLoginButton]) { [unowned self] in
     self.loginButton.isHidden = !self.showLoginButton.value
 }
 ````
 * `onTransition()` runs a function when a single property changes,
 passing in the previous and current values of the property. The function will
 also be run immediately with a previous value of `nil` to ensure the initial
 state of the supplied property is taken into account. This should be used for non-idempotent updates.
 It is useful for performing an action when a property transitions from one value to another,
 especially if you want to perform an action when a property goes from value A to value C, but not when it goes from B to C.
 ````
 updater.onTransition(showLoginButton) { [unowned self] wasShowingLoginButton, showLoginButton in
     if wasShowingLoginButton != nil && showLoginButton {
         self.animateLoginButtonAppearing()
     }
 }
 ````
 * `bind()` is a convenience method that automatically
 updates a non-Yoyo object's property to stay equal to any `Property` object.
 For example, you could use this to bind the `isHidden` property of a
 `UIView` to a `Property<Bool>`.
 ````
 let isLoginButtonEnabled: Property<Bool>
 updater.bind(object: loginButton, keyPath: \UIButton.isEnabled, toProperty: isLoginButtonEnabled)
 ````
 
 - Important: The object creating this updater object must retain it. If the updater object
 is deallocated, all associated subscriptions will be cancelled and updater
 functions will no longer be called. Each object wishing to perform side effects
 should create its own updater and should not share it with other objects.
 
 This object does not allow unsubscribing from individual events. If you need to
 unsubscribe, allow this object to be deallocated.

 In rare cases, it may be useful to temporarily stop updates and resume
 them later. You can do this via the `pause()` and `unpause()` methods. When called, `unpause()`
 will issue any outstanding updates so consumers bring themselves up to date.
 Note that these methods affect all updater functionality - `keepUpToDate()`, `onTransition()`,
 and `bind()` will all be affected.
*/
public final class YoyoUpdater {

    private var dependencySubscriptions: [UntypedSubscription] = []
    private var updaters: [() -> Void] = []
    private var paused = false

    public init() {}

    public func keepUpToDate(dependencies: [UntypedProperty], updater: @escaping () -> Void) {
        updaters.append(updater)

        updater()

        self.dependencySubscriptions.append(contentsOf: dependencies.map { dependency in
            return (dependency as! InternalUntypedProperty).untypedSubscribe { [weak self] in
                guard let stelf = self else { return }
                if !stelf.paused {
                    updater()
                }
            }
        })
    }

    public func keepUpToDate<O: AnyObject>(dependencies: [UntypedProperty], updater updaterTarget: O, _ updater: @escaping (O) -> () -> Void) {
        self.keepUpToDate(dependencies: dependencies, updater: { [weak updaterTarget] in
            guard let updaterTarget = updaterTarget else { return }
            updater(updaterTarget)()
        })
    }

    public func onTransition<T: Equatable>(_ property: Property<T>, observer: @escaping (T?, T) -> Void) {
        var previousValue: T?
        self.keepUpToDate(dependencies: [property], updater: {
            // Need to check equality again so unpausing doesn't fire if nothing changed
            guard previousValue != property.value else { return }

            observer(previousValue, property.value)
            previousValue = property.value
        })
    }

    @available(*, deprecated, message: "bind() arguments have been reordered for clarity")
    public func bind<T, O: AnyObject>(property: Property<T>, toKeyPath keyPath: ReferenceWritableKeyPath<O, T>, ofObject target: O) {
        self.bind(object: target, keyPath: keyPath, toProperty: property)
    }

    public func bind<T, O: AnyObject>(object target: O, keyPath: ReferenceWritableKeyPath<O, T>, toProperty property: Property<T>) {
        self.keepUpToDate(dependencies: [property], updater: { [weak target] in
            guard let target = target else { return }
            target[keyPath: keyPath] = property.value
        })
    }

    public func pause() {
        paused = true
    }

    public func unpause() {
        if paused {
            paused = false
            updaters.forEach({ $0() })
        }
    }
}

/**
 Utilities for doing reflection on properties
 */
public final class YoyoReflection {
    public static func valueOf(_ property: UntypedProperty) -> Any {
        return (property as! InternalUntypedProperty).unsafeValue
    }

    public static func valueTypeOf(_ property: UntypedProperty) -> Any.Type {
        return (property as! InternalUntypedProperty).unsafeValueType
    }

    public static func setValue(of property: UntypedProperty, to value: Any) {
        (property as! InternalUntypedProperty).unsafeSetValue(value)
    }
}
