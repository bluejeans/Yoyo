// Copyright © 2020 Blue Jeans Network, Inc.

import XCTest
@testable import Yoyo

class YoyoAdvancedMemoryTests: XCTestCase {

    // MARK: - TentativeProperty

    func testTentativePropertyDeallocated() {
        let propertyHolder1 = StoredPropertyObject()
        var propertyHolder2: TentativePropertyObject? = TentativePropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testTentativePropertyAllowsParentToDeallocate() {
        var propertyHolder1: StoredPropertyObject? = StoredPropertyObject()
        var propertyHolder2: TentativePropertyObject? = TentativePropertyObject(parentPropertyObject: propertyHolder1!)

        weak var checker1 = propertyHolder1
        weak var checker2 = propertyHolder1!.property
        weak var checker3 = propertyHolder2
        weak var checker4 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder1 = nil
        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
        XCTAssertNil(checker3)
        XCTAssertNil(checker4)
    }

    func testTentativePropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1: StoredPropertyObject = StoredPropertyObject()
        var propertyHolder2: TentativePropertyObject? = TentativePropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
    }

    // MARK: - ConnectableProperty

    func testConnectablePropertyDeallocated() {
        let propertyHolder1 = StoredPropertyObject()
        var propertyHolder2: ConnectedPropertyObject? = ConnectedPropertyObject()

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        propertyHolder2?.property.connect(propertyHolder1.property)

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testConnectablePropertyAllowsParentToDeallocate() {
        var propertyHolder1: StoredPropertyObject? = StoredPropertyObject()
        var propertyHolder2: ConnectedPropertyObject? = ConnectedPropertyObject()

        weak var checker1 = propertyHolder1
        weak var checker2 = propertyHolder1!.property
        weak var checker3 = propertyHolder2
        weak var checker4 = propertyHolder2!.property

        propertyHolder2?.property.connect(propertyHolder1!.property)

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder1 = nil
        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
        XCTAssertNil(checker3)
        XCTAssertNil(checker4)
    }

    func testConnectablePropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1: StoredPropertyObject = StoredPropertyObject()
        var propertyHolder2: ConnectedPropertyObject? = ConnectedPropertyObject()

        propertyHolder2?.property.connect(propertyHolder1.property)

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
    }

    // MARK: - MultilevelProperty

    func testMultilevelPropertyDeallocated() {
        let propertyHolder1 = NestedStoredPropertyObject()
        var propertyHolder2: MultilevelPropertyObject? = MultilevelPropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testMultilevelPropertyRetainsParentPropertyAndChildSelector() {
        var propertyHolder1: NestedStoredPropertyObject? = NestedStoredPropertyObject()
        let propertyHolder2 = MultilevelPropertyObject(parentPropertyObject: propertyHolder1!)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        weak var weakDependency1 = propertyHolder1!.property
        weak var weakDependency2 = propertyHolder1!.property.value.property

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)

        propertyHolder1 = nil

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)
    }

    func testMultilevelPropertyAllowsParentToDeallocate() {
        var parentPropertyHolder: NestedStoredPropertyObject? = NestedStoredPropertyObject()
        var multilevelPropertyHolder: MultilevelPropertyObject? = MultilevelPropertyObject(parentPropertyObject: parentPropertyHolder!)

        weak var checkParentPropertyHolder = parentPropertyHolder
        weak var checkParentProperty = parentPropertyHolder!.property
        weak var checkInnerParentPropertyHolder = parentPropertyHolder!.property.value
        weak var checkInnerParentProperty = parentPropertyHolder!.property.value.property
        weak var checkMultilevelPropertyHolder = multilevelPropertyHolder
        weak var checkMultilevelProperty = multilevelPropertyHolder!.property

        XCTAssertNotNil(checkParentPropertyHolder)
        XCTAssertNotNil(checkParentProperty)
        XCTAssertNotNil(checkInnerParentPropertyHolder)
        XCTAssertNotNil(checkInnerParentProperty)
        XCTAssertNotNil(checkMultilevelPropertyHolder)
        XCTAssertNotNil(checkMultilevelProperty)

        parentPropertyHolder = nil
        multilevelPropertyHolder = nil

        XCTAssertNil(checkParentPropertyHolder)
        XCTAssertNil(checkParentProperty)
        XCTAssertNil(checkInnerParentPropertyHolder)
        XCTAssertNil(checkInnerParentProperty)
        XCTAssertNil(checkMultilevelPropertyHolder)
        XCTAssertNil(checkMultilevelProperty)
    }

    func testMultilevelPropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1 = NestedStoredPropertyObject()
        var propertyHolder2: MultilevelPropertyObject? = MultilevelPropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)
        XCTAssertEqual(propertyHolder1.property.value.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
        XCTAssertEqual(propertyHolder1.property.value.property._testOnly_numberOfOnChangeCallbacks, 0)
    }

    // MARK: - MultilevelOptionalProperty

    func testMultilevelOptionalPropertyDeallocated() {
        let propertyHolder1 = OptionalNestedStoredPropertyObject()
        var propertyHolder2: MultilevelOptionalPropertyObject? = MultilevelOptionalPropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testMultilevelOptionalPropertyRetainsParentPropertyAndChildSelector() {
        var propertyHolder1: OptionalNestedStoredPropertyObject? = OptionalNestedStoredPropertyObject()
        let propertyHolder2 = MultilevelOptionalPropertyObject(parentPropertyObject: propertyHolder1!)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        weak var weakDependency1 = propertyHolder1!.property
        weak var weakDependency2 = propertyHolder1!.property.value!.property

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)

        propertyHolder1 = nil

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)
    }

    func testMultilevelOptionalPropertyAllowsParentToDeallocate() {
        var parentPropertyHolder: OptionalNestedStoredPropertyObject? = OptionalNestedStoredPropertyObject()
        var multilevelPropertyHolder: MultilevelOptionalPropertyObject? = MultilevelOptionalPropertyObject(parentPropertyObject: parentPropertyHolder!)

        weak var checkParentPropertyHolder = parentPropertyHolder
        weak var checkParentProperty = parentPropertyHolder!.property
        weak var checkInnerParentPropertyHolder = parentPropertyHolder!.property.value
        weak var checkInnerParentProperty = parentPropertyHolder!.property.value!.property
        weak var checkMultilevelPropertyHolder = multilevelPropertyHolder
        weak var checkMultilevelProperty = multilevelPropertyHolder!.property

        XCTAssertNotNil(checkParentPropertyHolder)
        XCTAssertNotNil(checkParentProperty)
        XCTAssertNotNil(checkInnerParentPropertyHolder)
        XCTAssertNotNil(checkInnerParentProperty)
        XCTAssertNotNil(checkMultilevelPropertyHolder)
        XCTAssertNotNil(checkMultilevelProperty)

        parentPropertyHolder = nil
        multilevelPropertyHolder = nil

        XCTAssertNil(checkParentPropertyHolder)
        XCTAssertNil(checkParentProperty)
        XCTAssertNil(checkInnerParentPropertyHolder)
        XCTAssertNil(checkInnerParentProperty)
        XCTAssertNil(checkMultilevelPropertyHolder)
        XCTAssertNil(checkMultilevelProperty)
    }

    func testMultilevelOptionalPropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1 = OptionalNestedStoredPropertyObject()
        var propertyHolder2: MultilevelOptionalPropertyObject? = MultilevelOptionalPropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)
        XCTAssertEqual(propertyHolder1.property.value?.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
        XCTAssertEqual(propertyHolder1.property.value?.property._testOnly_numberOfOnChangeCallbacks, 0)
    }

    // MARK: - MultilevelCollectionProperty

    func testMultilevelCollectionPropertyDeallocated() {
        let propertyHolder1 = CollectionPropertyObject()
        var propertyHolder2: MultilevelCollectionPropertyObject? = MultilevelCollectionPropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testMultilevelCollectionPropertyRetainsParentPropertyAndChildSelector() {
        var propertyHolder1: CollectionPropertyObject? = CollectionPropertyObject()
        let propertyHolder2 = MultilevelCollectionPropertyObject(parentPropertyObject: propertyHolder1!)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        weak var weakDependency1 = propertyHolder1!.property
        weak var weakDependency2 = propertyHolder1!.property.value.first!.property

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)

        propertyHolder1 = nil

        XCTAssertNotNil(weakDependency1)
        XCTAssertNotNil(weakDependency2)
    }

    func testMultilevelCollectionPropertyAllowsParentToDeallocate() {
        var parentPropertyHolder: CollectionPropertyObject? = CollectionPropertyObject()
        var multilevelPropertyHolder: MultilevelCollectionPropertyObject? = MultilevelCollectionPropertyObject(parentPropertyObject: parentPropertyHolder!)

        weak var checkParentPropertyHolder = parentPropertyHolder
        weak var checkParentProperty = parentPropertyHolder!.property
        weak var checkInnerParentPropertyHolder = parentPropertyHolder!.property.value.first!
        weak var checkInnerParentProperty = parentPropertyHolder!.property.value.first!.property
        weak var checkMultilevelPropertyHolder = multilevelPropertyHolder
        weak var checkMultilevelProperty = multilevelPropertyHolder!.property

        XCTAssertNotNil(checkParentPropertyHolder)
        XCTAssertNotNil(checkParentProperty)
        XCTAssertNotNil(checkInnerParentPropertyHolder)
        XCTAssertNotNil(checkInnerParentProperty)
        XCTAssertNotNil(checkMultilevelPropertyHolder)
        XCTAssertNotNil(checkMultilevelProperty)

        parentPropertyHolder = nil
        multilevelPropertyHolder = nil

        XCTAssertNil(checkParentPropertyHolder)
        XCTAssertNil(checkParentProperty)
        XCTAssertNil(checkInnerParentPropertyHolder)
        XCTAssertNil(checkInnerParentProperty)
        XCTAssertNil(checkMultilevelPropertyHolder)
        XCTAssertNil(checkMultilevelProperty)
    }

    func testMultilevelCollectionPropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1 = CollectionPropertyObject()
        var propertyHolder2: MultilevelCollectionPropertyObject? = MultilevelCollectionPropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2) // Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)
        XCTAssertEqual(propertyHolder1.property.value.first?.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
        XCTAssertEqual(propertyHolder1.property.value.first?.property._testOnly_numberOfOnChangeCallbacks, 0)
    }
}

class ConnectedPropertyObject {
    var property: ConnectableProperty<Int>!

    init() {
        property = ConnectableProperty(unconnectedValue: 0)
    }
}

class TentativePropertyObject {
    var property: TentativeProperty<Int>!

    init(parentPropertyObject: StoredPropertyObject) {
        let parentProperty = parentPropertyObject.property
        property = TentativeProperty(parentProperty: parentProperty, tenativeValueValidForMS: 10)
    }
}

class NestedStoredPropertyObject {
    let property: StoredProperty<StoredPropertyObject> = StoredProperty(StoredPropertyObject())
}

class MultilevelPropertyObject {
    var property: MultilevelProperty<StoredPropertyObject, Int>

    init(parentPropertyObject: NestedStoredPropertyObject) {
        property = MultilevelProperty(parentProperty: parentPropertyObject.property, childSelector: { $0.property })
    }
}

class OptionalNestedStoredPropertyObject {
    let property: StoredProperty<StoredPropertyObject?> = StoredProperty(StoredPropertyObject())
}

class MultilevelOptionalPropertyObject {
    var property: MultilevelOptionalProperty<StoredPropertyObject?, Int>

    init(parentPropertyObject: OptionalNestedStoredPropertyObject) {
        property = MultilevelOptionalProperty(parentProperty: parentPropertyObject.property, childSelector: { $0?.property })
    }
}

class CollectionPropertyObject {
    let property: StoredProperty<[StoredPropertyObject]> = StoredProperty([StoredPropertyObject()])
}

class MultilevelCollectionPropertyObject {
    var property: MultilevelCollectionProperty<[StoredPropertyObject], StoredPropertyObject>

    init(parentPropertyObject: CollectionPropertyObject) {
        property = MultilevelCollectionProperty(parentProperty: parentPropertyObject.property, childSelector: { [$0.property] })
    }
}
