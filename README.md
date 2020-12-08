# Yoyo ![platform: iOS | macOS | tvOS | watchOS](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE) [![carthage: compatible](https://img.shields.io/badge/carthage-compatible-brightgreen.svg)](https://github.com/Carthage/Carthage)

Reactive state management for Swift

<!-- MarkdownTOC autolink="true" autoanchor="true" levels="1,2" -->

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Credits](#credits)
- [License](#license)

<!-- /MarkdownTOC -->

<a id="introduction"></a>
## Introduction

<a id="what-is-yoyo"></a>
### What is Yoyo?

Yoyo is a framework for *reactive state management*. It enables the following:
* Storing state in objects
* Deriving (computing) state from other objects
* Running *reactions* (such as updating the UI) when either stored or derived state changes

This may seem familiar to you if you’ve used *observables* before. Observables are similar in that they allow you to react to state changes, but they generally do not support deriving values.

This may also seem familiar to you if you’ve use popular reactive programming libraries such as the Rx family of libraries (e.g. RxSwift or RxJS). However, these libraries focus on *event streams* rather than state. This focus allows them to be very powerful but also very complex. For many use cases, event streams are overkill and focusing on state is really what you want.

In more formal terms, Yoyo is an implementation of *transparent functional reactive programming* (TFRP), a term that means "under the hood, Yoyo is using event streams too, but we hide them from you so you don’t have to worry about them."

<a id="why-reactive-state-management"></a>
### Why reactive state management?

Yoyo is based on the following principles:
* Storing mutable state in objects is an intuitive thing to do.
* While storing state is intuitive, state is also a major source of bugs. Notably, many bugs stem from having state that is "out of sync" with other state. Consequently, the amount of actual stored state should be minimized. If a value can be computed from some other piece of state, it should not be stored as state but calculated as a derivation. This ensures that it is never out of date.
* The user interface should always be a function of the state of the application (no state should be stored in the UI itself). The UI should simply re-render itself if the application state changes.

Reactive state management allows you to continue to structure your data the way you normally do, via mutable state in objects, but it virtually eliminates "out of date" bugs. This avoids out of date state (by using derived values) as well as out of date UI (by using reactions). 

<a id="requirements"></a>
## Requirements
* iOS 10.0+
* macOS 10.10+
* tvOS 10.0+
* watchOS 3.0+
* Swift 5

<a id="installation"></a>
## Installation

<a id="carthage"></a>
### Carthage
```
github "bluejeans/Yoyo" == 1.0.0
```

<a id="usage"></a>
## Usage

<a id="storing-state"></a>
### Storing state

Use `StoredProperty` to store state. To change the value of the property, assign a new value to the `value` property.

```swift
class LoginManager {
    let isLoggedIn = StoredProperty(false)

    func logIn() {
        isLoggedIn.value = true
    }

    func logOut() {
        isLoggedIn.value = false
    }
}
```

<a id="deriving-state"></a>
### Deriving state

Use `DerivedProperty` to compute state from other properties. When initializing a `DerivedProperty`, pass all of the properties you want to use in the derivation computation. The last argument should be a "calculator" function that takes as many arguments as you previously passed into the initializer. This function will be invoked with parameters representing the current values of each of the input properties. In almost all cases, the calculator function should be a "pure" function that does not affect or reference any outside state.

```swift
let showLoginButton = DerivedProperty(loginManager.isLoggedIn) { isLoggedIn in
    return !isLoggedIn
}
```

<a id="reacting-to-state-changes"></a>
### Reacting to state changes

Use `YoyoUpdater` to react to state changes.
* `keepUpToDate()` runs a function every time the value of one or more `Property` objects changes. This should be used for idempotent updates, such as updating UI elements to reflect application state.
```swift
updater.keepUpToDate(dependencies: [showLoginButton]) { [unowned self] in
    self.loginButton.isHidden = !self.showLoginButton.value
}
```
* `onTransition()` runs a function when a single property changes, passing in the previous and current values of the property. This should be used for non-idempotent updates. It is useful for performing an action when a property transitions from one value to another, especially if you want to perform an action when a property goes from value A to value C, but not when it goes from B to C.
```swift
updater.onTransition(showLoginButton) { [unowned self] wasShowingLoginButton, showLoginButton in
    if wasShowingLoginButton != nil && showLoginButton {
        self.animateLoginButtonAppearing()
    }
}
```
* `bind()` is a convenience method that automatically updates a non-Yoyo object's property to stay equal to any `Property` object.
```swift
let isLoginButtonEnabled: Property<Bool>
updater.bind(object: loginButton, keyPath: \UIButton.isEnabled, toProperty: isLoginButtonEnabled)
```

**⚠️ Important:** The object creating the `YoyoUpdater` must retain it. If the updater object is deallocated, all associated subscriptions will be cancelled and updater functions will no longer be called. Each object wishing to perform side effects should create its own updater and should not share it with other objects.

<a id="other-properties"></a>
### Other properties

Additional properties are available for working with tentative state, nested properties, collections, and other less common situations.
* `ManuallyRecalculatedDerivedProperty`: A property whose value will only be updated when `recalculate()` is called. This is useful for adapting from non-Yoyo properties while making it clear that the property is derived.
* `PassThroughProperty`: A special case of `DerivedProperty` where the value of the property is always the same as the supplied parent property. This is useful for exposing another class’s property while encapsulating access to that class itself.
* `TentativeProperty`: A property whose value is backed by a parent property. Usually, the value of this property is the same as the parent property’s value. However, this property’s value can be temporarily changed to another value. This is useful for optimistically reflecting asynchronous updates.
* `ConnectableProperty`: A variant of `PassThroughProperty` whose parent property can be changed. The main reason to use this property is to set up an observable property whose value depends on another property that it doesn’t know about.
* `MultilevelProperty`: Represents a sub-property of another property. For example, if you have a `Property<Person>` and `Person` has a property `name`, which is a `Property<String>`, `MultilevelProperty` can be used to construct a `personName` property that will update if the outer property changes which `Person` it points to or if the `Person`'s `name` changes.
* `MultilevelOptionalProperty`: Same as `MultilevelProperty` but allows nil, usually in cases where the outer property is optional.
* `MultilevelCollectionProperty`: A property whose value is the same as its parent property but which is updated any time the parent property or any of the specified child selector properties is updated. This is useful when you want to do
 deep observation of a collection.
* `KVOCompatibleProperty`: Adapts an existing `Property` to support key-value observing and Cocoa bindings.
* `TwoWayKVOCompatibleProperty`:  A writable version of `KVOCompatibleProperty` that can be used with two-way data binding.

<a id="example"></a>
### Example

Imagine you have a UI where you want to show a tip for first-time users in the header of your application. The tip must only be shown to users who are logged in and must permanently disappear once the user clicks on it.

To properly separate concerns, you probably want several objects to be involved here. (In a simple case, this might be overkill, but assume this is part of a larger application.) The responsibilities of these objects might be: 
1. Keep track of whether the user is logged in or not 
2. Keep track of whether the user has ever clicked on the tip or not 
3. Determine based on the first two objects whether to show the tip 
4. The actual UI component that displays the tip 

Using Yoyo, we can easily model this as follows: 
* Objects 1 and 2 above each store mutable state. 
* Object 3 stores no state. Instead, it derives state from Objects 1 and 2. 
* Object 4 reacts to the derived state from Object 3. 

Implementing the above with Yoyo results in the following nice effects: 
* When either Object 1 or 2’s relevant state changes, Object 3’s derived state is recalculated and then Object 4 reacts, all immediately. As a result, any time the user logs in or out, or any time the user clicks on the tip, the tip will show or hide automatically. 
* The order of state changes in Objects 1 and 2 doesn’t matter. Every permutation of changes is handled because the derived value is a function of state, not a reaction to a sequence of events. 
* Even cases that are currently impossible are handled. While this version of the application may not support "un-clicking" the tip, if the "clicked" state were somehow reset to false, the tip would properly re-show again. This could be valuable if, for example, you later add a button in your app’s settings to allow the user to reset all tips.

```swift
class LoginManager {
    let isLoggedIn = StoredProperty(false)

    func logIn() {
        isLoggedIn.value = true
    }

    func logOut() {
        isLoggedIn.value = false
    }
}

class FirstTimeTipManager {
    let hasClickedOnTip = StoredProperty(false)

    func clickOnTip() {
        hasClickedOnTip.value = true
        // This can also be saved to UserDefaults or otherwise persisted across application launches
    }
}

class HeaderViewModel {
    private let loginManager: LoginManager
    private let firstTimeTipManager: FirstTimeTipManager

    let isTipHidden: Property<Bool>

    init(loginManager: LoginManager, firstTimeTipManager: FirstTimeTipManager) {
        self.loginManager = loginManager
        self.firstTimeTipManager = firstTimeTipManager

        isTipHidden = DerivedProperty(loginManager.isLoggedIn, firstTimeTipManager.hasClickedOnTip) { isLoggedIn, hasClickedOnTip in
            return !isLoggedIn || hasClickedOnTip
        }
    }
}

class HeaderView {
    private let updater = YoyoUpdater()

    private let firstTimeTipManager: FirstTimeTipManager

    var tipView: UIView!

    private let viewModel: HeaderViewModel

    init(loginManager: LoginManager, firstTimeTipManager: FirstTimeTipManager) {
        self.firstTimeTipManager = firstTimeTipManager

        viewModel = HeaderViewModel(loginManager: loginManager, firstTimeTipManager: firstTimeTipManager)

        updater.keepUpToDate(dependencies: [viewModel.isTipHidden]) { [unowned self] in
            self.tipView.isHidden = self.viewModel.isTipHidden.value
        }
    }

    func clickOnTip() {
        firstTimeTipManager.clickOnTip()
    }
}
``` 

<a id="credits"></a>
## Credits

* [@abrindam](https://github.com/abrindam)

<a id="license"></a>
## License

See [LICENSE](./LICENSE)