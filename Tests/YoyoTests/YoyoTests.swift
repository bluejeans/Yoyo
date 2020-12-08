// Copyright © 2020 Blue Jeans Network, Inc.

import XCTest
@testable import Yoyo

enum EnumWithAssocType: Equatable {
    case type1(assoc: Int)
    case type2(assoc: Int)

    public static func == (lhs: EnumWithAssocType, rhs: EnumWithAssocType) -> Bool {
        switch (lhs, rhs) {
        case let (.type1(l), .type1(r)):
            return l == r
        case let (.type2(l), .type2(r)):
            return l == r
        case (.type1, _), (.type2, _):
            return false
        }
    }
}

class YoyoTests: XCTestCase { // swiftlint:disable:this type_body_length

    func testStoredProperty() {
        let property = StoredProperty(3)
        XCTAssertEqual(property.value, 3)
        property.value = 42
        XCTAssertEqual(property.value, 42)
    }

    func testStoredPropertyObservable() {
        let property = StoredProperty(3)
        var changeFired = false
        property.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testStoredPropertyUnsubscribable() {
        let property = StoredProperty(3)
        var changeFired = false
        let callbackId = property.onChange({changeFired = true})
        property.value = 42
        changeFired = false
        property.unsubscribeFromChanges(callbackId)
        property.value = 77
        XCTAssertFalse(changeFired)
    }

    func testStoredPropertyOptimized() {
        let property = StoredProperty(3)
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = 3
        XCTAssert(!changeFired)
    }

    func testStoredPropertyOptimizedForOptional() {
        let property = StoredProperty<Int?>(nil)
        property.value = 3
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = 3
        XCTAssert(!changeFired)
    }

    func testStoredPropertyOptimizedForEnumWithAssociatedType() {
        let property = StoredProperty(EnumWithAssocType.type1(assoc: 1))
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = .type1(assoc: 1)
        XCTAssert(!changeFired)
    }

    func knownCompilerIssue_testStoredPropertyOptimizedForOptionalEnumWithAssociatedType() {
        let property = StoredProperty<EnumWithAssocType?>(.type1(assoc: 1))
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = .type1(assoc: 1)
        XCTAssert(!changeFired)
    }

    func testStoredPropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let property = StoredProperty(object)
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = object
        XCTAssert(!changeFired)
    }

    func testStoredPropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let property = StoredProperty(object)
        var changeFired = false
        property.onChange({changeFired = true})
        property.value = object
        XCTAssert(changeFired)
    }

    func testDerivedProperty() {
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value * 2
        }
        XCTAssertEqual(derivedProperty.value, 6)
        property.value = 42
        XCTAssertEqual(derivedProperty.value, 84)
    }

    func testDerivedProperty1Dep() {
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(property) { property in
            return property * 2
        }
        XCTAssertEqual(derivedProperty.value, 6)
        property.value = 42
        XCTAssertEqual(derivedProperty.value, 84)
    }

    func testDerivedPropertyObservable() {
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value * 2
        }
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testDerivedPropertyUnsubscribable() {
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value * 2
        }
        var changeFired = false
        let callbackId = derivedProperty.onChange({changeFired = true})
        property.value = 42
        changeFired = false
        derivedProperty.unsubscribeFromChanges(callbackId)
        property.value = 77
        XCTAssertFalse(changeFired)
    }

    func testDerivedPropertyOptimized() {
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value > 100
        }
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        property.value = 76
        XCTAssert(!changeFired)
    }

    func testDerivedPropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let object2  = NonEquatableObject()
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value > 100 ? object: object2
        }
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        property.value = 76
        XCTAssert(!changeFired)
    }

    func testDerivedPropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let object2  = NonEquatableStruct()
        let property = StoredProperty(3)
        let derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value > 100 ? object: object2
        }
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        property.value = 76
        XCTAssert(changeFired)
    }

    func testDerivedPropertyDoesntCrashIfDeallocatedDuringOnChangeOfDependency() {
        let property = StoredProperty(3)
        var derivedProperty: DerivedProperty<Int>!
        property.onChange {
            derivedProperty = nil
        }

        derivedProperty = DerivedProperty(dependencies: [property]) {
            return property.value * 2
        }
        XCTAssertEqual(derivedProperty!.value, 6)

        property.value = 42
        // ensure no crash
    }

    func testManuallyRecalculatedDerivedProperty() {
        var property = 3
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return property * 2
        })
        XCTAssertEqual(derivedProperty.value, 6)
        property = 42
        XCTAssertEqual(derivedProperty.value, 6)
        derivedProperty.recalculate()
        XCTAssertEqual(derivedProperty.value, 84)
    }

    func testManuallyRecalculatedDerivedPropertyObservable() {
        var property = 3
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return property * 2
        })
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        XCTAssertFalse(changeFired)
        property = 42
        XCTAssertFalse(changeFired)
        derivedProperty.recalculate()
        XCTAssertTrue(changeFired)
    }

    func testManuallyRecalculatedDerivedPropertyUnsubscribable() {
        var property = 3
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return property * 2
        })
        var changeFired = false
        let callbackId = derivedProperty.onChange({changeFired = true})
        property = 42
        derivedProperty.recalculate()
        changeFired = false
        derivedProperty.unsubscribeFromChanges(callbackId)
        property = 77
        derivedProperty.recalculate()
        XCTAssertFalse(changeFired)
    }

    func testManuallyRecalculatedDerivedPropertyOptimized() {
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return 100
        })
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        derivedProperty.recalculate()
        XCTAssert(!changeFired)
    }

    func testManuallyRecalculatedDerivedPropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return object
        })
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        derivedProperty.recalculate()
        XCTAssert(!changeFired)
    }

    func testManuallyRecalculatedDerivedPropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let derivedProperty = ManuallyRecalculatedDerivedProperty(calculator: {
            return object
        })
        var changeFired = false
        derivedProperty.onChange({changeFired = true})
        derivedProperty.recalculate()
        XCTAssert(changeFired)
    }

    func testPassThroughProperty() {
        let property = StoredProperty(3)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        XCTAssertEqual(passThroughProperty.value, 3)
        property.value = 42
        XCTAssertEqual(passThroughProperty.value, 42)
    }

    func testPassThroughPropertyObservable() {
        let property = StoredProperty(3)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        var changeFired = false
        passThroughProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testPassThroughPropertyUnsubscribable() {
        let property = StoredProperty(3)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        var changeFired = false
        let callbackId = passThroughProperty.onChange({changeFired = true})
        property.value = 42
        changeFired = false
        passThroughProperty.unsubscribeFromChanges(callbackId)
        property.value = 77
        XCTAssertFalse(changeFired)
    }

    func testPassThroughPropertyOptimized() {
        let property = StoredProperty(3, changePredicate: ChangePredicates.alwaysChangePredicate)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        var parentChangeFired = false
        var changeFired = false
        property.onChange({parentChangeFired = true})
        passThroughProperty.onChange({changeFired = true})
        property.value = 3
        XCTAssert(parentChangeFired)
        XCTAssert(!changeFired)
    }

    func testPassThroughPropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        var changeFired = false
        passThroughProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(!changeFired)
    }

    func testPassThroughPropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let passThroughProperty = PassThroughProperty(parentProperty: property)
        var changeFired = false
        passThroughProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(changeFired)
    }

    func testUpdaterFiresInitially() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })
        XCTAssertEqual(updaterTimesFired, 1)
    }

    func testUpdaterFiresOnChange() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })
        property.value = 76
        XCTAssertEqual(updaterTimesFired, 2)
    }

    func testUpdaterStopsFiringOnDeallocation() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        var updater: YoyoUpdater? = YoyoUpdater()
        updater!.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })
        updater = nil
        property.value = 76
        XCTAssertEqual(updaterTimesFired, 1)
    }

    func testStaticInstanceMethodUpdaterFiresInitially() {
        let property = StoredProperty(3)
        let object = UpdaterTestObject()
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: object, UpdaterTestObject.update)
        XCTAssertEqual(object.updaterTimesFired, 1)
    }

    func tesStaticInstanceMethodtUpdaterFiresOnChange() {
        let property = StoredProperty(3)
        let object = UpdaterTestObject()
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: object, UpdaterTestObject.update)
        property.value = 76
        XCTAssertEqual(object.updaterTimesFired, 2)
    }

    func testStaticInstanceMethodUpdaterStopsFiringOnDeallocation() {
        let property = StoredProperty(3)
        let object = UpdaterTestObject()
        var updater: YoyoUpdater? = YoyoUpdater()
        updater!.keepUpToDate(dependencies: [property], updater: object, UpdaterTestObject.update)
        updater = nil
        property.value = 76
        XCTAssertEqual(object.updaterTimesFired, 1)
    }

    func testPropertyUnsubscribableInChangeNotification() {
        let property = StoredProperty(3)
        var callbackId: CallbackId!
        callbackId = property.onChange({property.unsubscribeFromChanges(callbackId)})

        // Need a 2nd change handler to trigger potential bug
        property.onChange({})

        property.value = 42
        // Ensure no crash
    }

    func testUpdaterOnTransitionFiresImmediately() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        XCTAssertEqual(observerTimesFired, 1)
        XCTAssertEqual(lastParams?.0, nil)
        XCTAssertEqual(lastParams?.1, 3)
    }

    func testUpdaterOnTransitionFiresOnChange() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        property.value = 76
        XCTAssertEqual(observerTimesFired, 2)
        XCTAssertEqual(lastParams?.0, 3)
        XCTAssertEqual(lastParams?.1, 76)
    }

    func testUpdaterOnTransitionStopsFiringOnDeallocation() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var updater: YoyoUpdater? = YoyoUpdater()

        updater!.onTransition(property, observer: { _, _ in
            observerTimesFired += 1
        })

        updater = nil
        property.value = 76
        XCTAssertEqual(observerTimesFired, 1)
    }

    func testUpdaterBindInitialValue() {
        let property = StoredProperty(3)
        let object = BindTestObject()
        let updater = YoyoUpdater()

        updater.bind(object: object, keyPath: \.value, toProperty: property)
        XCTAssertEqual(object.value, 3)
    }

    func testUpdaterBindFiresOnChange() {
        let property = StoredProperty(3)
        let object = BindTestObject()
        let updater = YoyoUpdater()

        updater.bind(object: object, keyPath: \.value, toProperty: property)

        property.value = 7
        XCTAssertEqual(object.value, 7)
    }

    func testUpdaterBindStopsFiringOnDeallocation() {
        let property = StoredProperty(3)
        let object = BindTestObject()
        var updater: YoyoUpdater? = YoyoUpdater()

        updater!.bind(object: object, keyPath: \.value, toProperty: property)

        updater = nil
        property.value = 7
        XCTAssertEqual(object.value, 3)
    }

    func testUpdaterPauseStopsUpdates() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })

        updater.pause()

        property.value = 7
        XCTAssertEqual(updaterTimesFired, 1)
    }

    func testUpdaterUnpauseFiresUpdate() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })

        updater.pause()

        property.value = 7

        updater.unpause()
        XCTAssertEqual(updaterTimesFired, 2)
    }

    func testUpdaterUnpauseAllowsUpdates() {
        let property = StoredProperty(3)
        var updaterTimesFired = 0
        let updater = YoyoUpdater()
        updater.keepUpToDate(dependencies: [property], updater: {
            updaterTimesFired += 1
        })

        updater.pause()

        property.value = 7

        updater.unpause()

        property.value = 42
        XCTAssertEqual(updaterTimesFired, 3)
    }

    func testUpdaterPauseStopsTransitions() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        updater.pause()

        property.value = 7
        XCTAssertEqual(observerTimesFired, 1)
        XCTAssertEqual(lastParams?.0, nil)
        XCTAssertEqual(lastParams?.1, 3)
    }

    func testUpdaterUnpauseFiresTransition() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        updater.pause()

        property.value = 7

        updater.unpause()

        XCTAssertEqual(observerTimesFired, 2)
        XCTAssertEqual(lastParams?.0, 3)
        XCTAssertEqual(lastParams?.1, 7)
    }

    func testUpdaterUnpauseFiresAggregateTransition() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        updater.pause()

        property.value = 7

        property.value = 42

        updater.unpause()

        XCTAssertEqual(observerTimesFired, 2)
        XCTAssertEqual(lastParams?.0, 3)
        XCTAssertEqual(lastParams?.1, 42)
    }

    func testUpdaterUnpauseDoesNotFireTransitionIfNoChange() {
        let property = StoredProperty(3)
        var observerTimesFired = 0
        var lastParams: (Int?, Int)?
        let updater = YoyoUpdater()

        updater.onTransition(property, observer: { old, new in
            observerTimesFired += 1
            lastParams = (old, new)
        })

        updater.pause()

        updater.unpause()

        XCTAssertEqual(observerTimesFired, 1)
        XCTAssertEqual(lastParams?.0, nil)
        XCTAssertEqual(lastParams?.1, 3)
    }

}

class NonEquatableObject {}

struct NonEquatableStruct {}

class UpdaterTestObject {
    var updaterTimesFired = 0

    func update() {
        updaterTimesFired += 1
    }
}

class BindTestObject {
    var value = 0
}
