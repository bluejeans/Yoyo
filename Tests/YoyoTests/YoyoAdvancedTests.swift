// Copyright © 2020 Blue Jeans Network, Inc.

import XCTest
import Yoyo

class YoyoAdvancedTests: XCTestCase { // swiftlint:disable:this type_body_length

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testTenativePropertyGetsParentValue() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 3000)
        XCTAssertEqual(tentativeProperty.value, 3)
        property.value = 42
        XCTAssertEqual(tentativeProperty.value, 42)
    }

    func testTenativePropertyObservable() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 3000)
        var changeFired = false
        tentativeProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testTenativePropertyUnsubscribable() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 3000)
        var changeFired = false
        let callbackId = tentativeProperty.onChange({changeFired = true})
        property.value = 42
        changeFired = false
        tentativeProperty.unsubscribeFromChanges(callbackId)
        XCTAssertFalse(changeFired)
    }

    func testTenativePropertyAcceptsTentativeValue() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 3000)
        tentativeProperty.value = 76
        XCTAssertEqual(tentativeProperty.value, 76)
    }

    func testTenativePropertyIgnoresParentWithTentativeValue() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 3000)
        tentativeProperty.value = 76
        var changeFired = false
        tentativeProperty.onChange({changeFired = true})
        property.value = 42
        XCTAssertEqual(tentativeProperty.value, 76)
        XCTAssert(!changeFired)
    }

    func testTenativePropertyReverts() {
        let property = StoredProperty(3)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 200)
        tentativeProperty.value = 76
        property.value = 42
        wait(ms: 300)
        XCTAssertEqual(tentativeProperty.value, 42)
    }

    func testTenativePropertyOptimized() {
        let property = StoredProperty(3, changePredicate: ChangePredicates.alwaysChangePredicate)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 200)
        var parentChangeFired = false
        var changeFired = false
        property.onChange({parentChangeFired = true})
        tentativeProperty.onChange({changeFired = true})
        property.value = 3
        XCTAssert(parentChangeFired)
        XCTAssert(!changeFired)
    }

    func testTenativePropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 200)
        var changeFired = false
        tentativeProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(!changeFired)
    }

    func testTenativePropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let tentativeProperty = TentativeProperty(parentProperty: property, tenativeValueValidForMS: 200)
        var changeFired = false
        tentativeProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(changeFired)
    }

    func testConnectablePropertyGetsUnconnectedValue() {
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        XCTAssertEqual(connectableProperty.value, 76)
    }

    func testConnectedPropertyGetsConnectedValue() {
        let property = StoredProperty(3)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(property)
        XCTAssertEqual(connectableProperty.value, 3)
    }

    func testConnectedPropertyObservableOnConnect() {
        let property = StoredProperty(3)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        var changeFired = false
        connectableProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        connectableProperty.connect(property)
        XCTAssert(changeFired)
    }

    func testConnectedPropertyGetsConnectedValueChanges() {
        let property = StoredProperty(3)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(property)
        property.value = 42
        XCTAssertEqual(connectableProperty.value, 42)
    }

    func testConnectedPropertyObservableOnConnectedChange() {
        let property = StoredProperty(3)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(property)
        var changeFired = false
        connectableProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testConnectedPropertyGetsConnectedConstant() {
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(constant: 3)
        XCTAssertEqual(connectableProperty.value, 3)
    }

    func testConnectedPropertyObservableOnConnectConstant() {
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        var changeFired = false
        connectableProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        connectableProperty.connect(constant: 3)
        XCTAssert(changeFired)
    }

    func testConnectedPropertyUnsubscribable() {
        let property = StoredProperty(3)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(property)
        var changeFired = false
        let callbackId = connectableProperty.onChange({changeFired = true})
        property.value = 42
        changeFired = false
        connectableProperty.unsubscribeFromChanges(callbackId)
        XCTAssertFalse(changeFired)
    }

    func testConnectedPropertyOptimized() {
        let property = StoredProperty(3, changePredicate: ChangePredicates.alwaysChangePredicate)
        let connectableProperty = ConnectableProperty(unconnectedValue: 76)
        connectableProperty.connect(property)
        var parentChangeFired = false
        var changeFired = false
        property.onChange({parentChangeFired = true})
        connectableProperty.onChange({changeFired = true})
        property.value = 3
        XCTAssert(parentChangeFired)
        XCTAssert(!changeFired)
    }

    func testConnectedPropertyOptimizedForNonEquatableObjects() {
        let object  = NonEquatableObject()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let connectableProperty = ConnectableProperty(unconnectedValue: object)
        connectableProperty.connect(property)
        var changeFired = false
        connectableProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(!changeFired)
    }

    func testConnectedPropertyNotOptimizedForNonEquatableStruct() {
        let object  = NonEquatableStruct()
        let property = StoredProperty(object, changePredicate: ChangePredicates.alwaysChangePredicate)
        let connectableProperty = ConnectableProperty(unconnectedValue: object)
        connectableProperty.connect(property)
        var changeFired = false
        connectableProperty.onChange({changeFired = true})
        property.value = object
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyOneLevelInitialValue() {
        let property = StoredProperty(Object2())
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        XCTAssertEqual(multilevelProperty.value, "aaa")
    }

    func testMultilevelPropertyOneLevelChangeChild() {
        let property = StoredProperty(Object2())
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        property.value.bar.value = "bbb"
        XCTAssertEqual(multilevelProperty.value, "bbb")
    }

    func testMultilevelPropertyOneLevelChangeChildObservable() {
        let property = StoredProperty(Object2())
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value.bar.value = "bbb"
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyOneLevelChangeParent() {
        let property = StoredProperty(Object2())
        let object2b = Object2()
        object2b.bar.value = "ccc"
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        property.value = object2b
        XCTAssertEqual(multilevelProperty.value, "ccc")
    }

    func testMultilevelPropertyOneLevelChangeParentObservable() {
        let property = StoredProperty(Object2())
        let object2b = Object2()
        object2b.bar.value = "ccc"
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = object2b
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyTwoLevelsInitialValue() {
        let property = StoredProperty(Object1())
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        XCTAssertEqual(multilevelProperty2.value, "aaa")
    }

    func testMultilevelPropertyTwoLevelsChangeChild() {
        let property = StoredProperty(Object1())
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        property.value.foo.value.bar.value = "bbb"
        XCTAssertEqual(multilevelProperty2.value, "bbb")
    }

    func testMultilevelPropertyTwoLevelsChangeChildObservable() {
        let property = StoredProperty(Object1())
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty2.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value.foo.value.bar.value = "bbb"
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyTwoLevelsChangeMiddle() {
        let property = StoredProperty(Object1())
        let object2b = Object2()
        object2b.bar.value = "ccc"
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        property.value.foo.value = object2b
        XCTAssertEqual(multilevelProperty2.value, "ccc")
    }

    func testMultilevelPropertyTwoLevelsChangeMiddleObservable() {
        let property = StoredProperty(Object1())
        let object2b = Object2()
        object2b.bar.value = "ccc"
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty2.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value.foo.value = object2b
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyTwoLevelsChangeParent() {
        let property = StoredProperty(Object1())
        let object1b = Object1()
        object1b.foo.value.bar.value = "ddd"
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        property.value = object1b
        XCTAssertEqual(multilevelProperty2.value, "ddd")
    }

    func testMultilevelPropertyTwoLevelsChangeParentObservable() {
        let property = StoredProperty(Object1())
        let object1b = Object1()
        object1b.foo.value.bar.value = "ddd"
        let multilevelProperty1 = MultilevelProperty(parentProperty: property, childSelector: { $0.foo })
        let multilevelProperty2 = MultilevelProperty(parentProperty: multilevelProperty1, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty2.onChange({changeFired = true})
        XCTAssert(!changeFired)
        property.value = object1b
        XCTAssertEqual(multilevelProperty2.value, "ddd")
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyOptimized() {
        let property = StoredProperty(UnoptimizedObject1(), changePredicate: ChangePredicates.alwaysChangePredicate)
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        property.value.bar.value = "aaa"
        XCTAssert(!changeFired)
        property.value = UnoptimizedObject1()
        XCTAssert(!changeFired)
    }

    func testMultilevelPropertyOptimizedForNonEquatableObjects() {
        let innerObject = NonEquatableObject()
        let property = StoredProperty(UnoptimizedObject2(), changePredicate: ChangePredicates.alwaysChangePredicate)
        property.value.bar.value = innerObject
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        property.value.bar.value = innerObject
        XCTAssert(!changeFired)
        let newOuterObject = UnoptimizedObject2()
        newOuterObject.bar.value = innerObject
        property.value = newOuterObject
        XCTAssert(!changeFired)
    }

    func testMultilevelPropertyNotOptimizedForNonEquatableStruct() {
        let innerObject = NonEquatableStruct()
        let property = StoredProperty(UnoptimizedObject3(), changePredicate: ChangePredicates.alwaysChangePredicate)
        property.value.bar.value = innerObject
        let multilevelProperty = MultilevelProperty(parentProperty: property, childSelector: { $0.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        property.value.bar.value = innerObject
        XCTAssert(changeFired)
        let newOuterObject = UnoptimizedObject3()
        newOuterObject.bar.value = innerObject
        property.value = newOuterObject
        XCTAssert(changeFired)
    }

    func testMultilevelPropertyWithKeypathOneLevelInitialValue() {
        let property = StoredProperty(Object2())
        let multilevelProperty = MultilevelProperty(parentProperty: property, childKeyPath: \.bar )
        XCTAssertEqual(multilevelProperty.value, "aaa")
    }

    func testMultilevelPropertyWithKeypathOneLevelChangeChild() {
        let property = StoredProperty(Object2())
        let multilevelProperty = MultilevelProperty(parentProperty: property, childKeyPath: \.bar)
        property.value.bar.value = "bbb"
        XCTAssertEqual(multilevelProperty.value, "bbb")
    }
    func testMultilevelPropertyWithKeypathOneLevelChangeParent() {
        let property = StoredProperty(Object2())
        let object2b = Object2()
        object2b.bar.value = "ccc"
        let multilevelProperty = MultilevelProperty(parentProperty: property, childKeyPath: \.bar)
        property.value = object2b
        XCTAssertEqual(multilevelProperty.value, "ccc")
    }

    func testMultilevelOptionalPropertyInitialValue() {
        let property = StoredProperty<Object2?>(Object2())
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childSelector: { $0?.bar })
        XCTAssertEqual(multilevelProperty.value, "aaa")
    }

    func testMultilevelPropertyChangeParentToNull() {
        let property = StoredProperty<Object2?>(Object2())
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childSelector: { $0?.bar })
        property.value = nil
        XCTAssertNil(multilevelProperty.value)
    }

    func testMultilevelOptionalPropertyOptimized() {
        let property = StoredProperty<UnoptimizedObject1?>(UnoptimizedObject1())
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childSelector: { $0?.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        property.value?.bar.value = "aaa"
        XCTAssert(!changeFired)
        property.value = UnoptimizedObject1()
        XCTAssert(!changeFired)
    }

    func testMultilevelOptionalPropertyOptimizedForNil() {
        let property = StoredProperty<UnoptimizedObject1?>(nil)
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childSelector: { $0?.bar })
        var changeFired = false
        multilevelProperty.onChange({changeFired = true})
        property.value = nil
        XCTAssert(!changeFired)
    }

    func testMultilevelOptionalPropertyWithKeypathInitialValue() {
        let property = StoredProperty<Object2?>(Object2())
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childKeyPath: \.bar)
        XCTAssertEqual(multilevelProperty.value, "aaa")
    }

    func testMultilevelOptionalPropertyChangeWithKeypathParentToNull() {
        let property = StoredProperty<Object2?>(Object2())
        let multilevelProperty = MultilevelOptionalProperty(parentProperty: property, childKeyPath: \.bar)
        property.value = nil
        XCTAssertNil(multilevelProperty.value)
    }

    func testMultilevelCollectionPropertyAddElement() {
        let element1 = Object3()
        let element2 = Object3()
        let element3 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        property.value = [element1, element2, element3]
        XCTAssert(changeFired)
    }

    func testMultilevelCollectionPropertyRemoveElement() {
        let element1 = Object3()
        let element2 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        property.value = [element1]
        XCTAssert(changeFired)
    }

    func testMultilevelCollectionPropertyChangeSelectedElementProperty() {
        let element1 = Object3()
        let element2 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        element1.foo.value = 3
        XCTAssert(changeFired)
    }

    func testMultilevelCollectionPropertyChangeUnselectedElementProperty() {
        let element1 = Object3()
        let element2 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        element1.bar.value = "bbb"
        XCTAssert(!changeFired)
    }

    func testMultilevelCollectionPropertyChangeSelectedElementPropertyAfterAdd() {
        let element1 = Object3()
        let element2 = Object3()
        let element3 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        property.value = [element1, element2, element3]

        changeFired = false
        element3.foo.value = 3
        XCTAssert(changeFired)
    }

    func testMultilevelCollectionPropertyChangeSelectedElementPropertyAfterRemove() {
        let element1 = Object3()
        let element2 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        property.value = [element1]

        changeFired = false
        element2.foo.value = 3
        XCTAssert(!changeFired)
    }

    func testMultilevelCollectionPropertyWithKeypathsChangeSelectedElementProperty() {
        let element1 = Object3()
        let element2 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childKeyPath: \Object3.foo)

        var changeFired = false
        multilevelProperty.onChange { changeFired = true }

        element1.foo.value = 3
        XCTAssert(changeFired)
    }

    func testMultilevelCollectionPropertyCommonUseCase() {
        let element1 = Object3()
        let element2 = Object3()
        let element3 = Object3()

        let property = StoredProperty([element1, element2])

        let multilevelProperty = MultilevelCollectionProperty<[Object3], Object3>(parentProperty: property, childSelector: { [$0.foo] })

        let sum = DerivedProperty(multilevelProperty) { (list: [Object3]) in
            return list.map({ $0.foo.value }).reduce(0, +)
        }

        XCTAssertEqual(sum.value, 14)

        property.value = [element1, element2, element3]
        XCTAssertEqual(sum.value, 21)

        element3.foo.value = 3
        XCTAssertEqual(sum.value, 17)

        element1.foo.value = 12
        XCTAssertEqual(sum.value, 22)
    }

    func testMultilevelCollectionPropertyDictionaryUseCase() {
        let element1 = Object3()
        let element2 = Object3()
        let element3 = Object3()

        let property = StoredProperty(["larry": element1, "moe": element2])

        let multilevelProperty = MultilevelCollectionProperty(parentProperty: property, childSelector: { [$0.value.foo] })

        let sum = DerivedProperty(multilevelProperty) { (dictionary: [String: YoyoAdvancedTests.Object3]) in
            return dictionary.values.map({ $0.foo.value }).reduce(0, +)
        }

        XCTAssertEqual(sum.value, 14)

        property.value = ["larry": element1, "moe": element2, "curly": element3]
        XCTAssertEqual(sum.value, 21)

        element3.foo.value = 3
        XCTAssertEqual(sum.value, 17)

        element1.foo.value = 12
        XCTAssertEqual(sum.value, 22)
    }

    struct Object1 {
        let foo = StoredProperty<Object2>(Object2())
    }

    struct Object2 {
        let bar = StoredProperty<String>("aaa")
    }

    struct Object3 {
        let foo = StoredProperty<Int>(7)
        let bar = StoredProperty<String>("bbb")
    }

    struct UnoptimizedObject1 {
        let bar = StoredProperty<String>("aaa", changePredicate: ChangePredicates.alwaysChangePredicate)
    }

    struct UnoptimizedObject2 {
        let bar = StoredProperty<NonEquatableObject>(NonEquatableObject(), changePredicate: ChangePredicates.alwaysChangePredicate)
    }

    struct UnoptimizedObject3 {
        let bar = StoredProperty<NonEquatableStruct>(NonEquatableStruct(), changePredicate: ChangePredicates.alwaysChangePredicate)
    }

    func wait(ms time: CFTimeInterval) {
        let waitExpectation = expectation(description: "Wait for some time")
        wait(ms: time) { waitExpectation.fulfill() }
        waitForExpectations(timeout: time) { (error) in
            XCTAssertNil(error)
        }
    }

    func wait(ms time: CFTimeInterval, thenExecute: @escaping () -> Void) {
        let nSecDelay = UInt64(time) * NSEC_PER_MSEC
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(nSecDelay)) / Double(NSEC_PER_SEC), execute: {
            thenExecute()
        })
    }
}
