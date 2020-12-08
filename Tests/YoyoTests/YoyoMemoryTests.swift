// Copyright © 2020 Blue Jeans Network, Inc.

import XCTest
@testable import Yoyo

class YoyoMemoryTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testStoredPropertyDeallocated() {
        var propertyHolder: StoredPropertyObject? = StoredPropertyObject()
        weak var checker = propertyHolder!.property
        XCTAssertNotNil(checker)
        propertyHolder = nil
        XCTAssertNil(checker)
    }

    func testDerivedPropertyDeallocated() {
        let propertyHolder1 = StoredPropertyObject()
        var propertyHolder2: DerivedPropertyObject? = DerivedPropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testDerivedPropertyRetainsDependency() {
        var propertyHolder1: StoredPropertyObject? = StoredPropertyObject()
        let propertyHolder2 = DerivedPropertyObject(parentPropertyObject: propertyHolder1!)
        XCTAssertNotNil(propertyHolder2)// Access property to silence property was never used warning from compiler; property is used to retain

        weak var weakDependency = propertyHolder1!.property

        XCTAssertNotNil(weakDependency)

        propertyHolder1 = nil

        XCTAssertNotNil(weakDependency)
    }

    func testDerivedPropertyAllowsParentToDeallocate() {
        var propertyHolder1: StoredPropertyObject? = StoredPropertyObject()
        var propertyHolder2: DerivedPropertyObject? = DerivedPropertyObject(parentPropertyObject: propertyHolder1!)

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

    func testDerivedPropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1: StoredPropertyObject = StoredPropertyObject()
        var propertyHolder2: DerivedPropertyObject? = DerivedPropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2)// Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
    }

    func testPassThroughPropertyDeallocated() {
        let propertyHolder1 = StoredPropertyObject()
        var propertyHolder2: PassThroughPropertyObject? = PassThroughPropertyObject(parentPropertyObject: propertyHolder1)

        weak var checker1 = propertyHolder2
        weak var checker2 = propertyHolder2!.property

        XCTAssertNotNil(checker1)
        XCTAssertNotNil(checker2)

        propertyHolder2 = nil

        XCTAssertNil(checker1)
        XCTAssertNil(checker2)
    }

    func testPassThroughPropertyRetainsDependency() {
        var propertyHolder1: StoredPropertyObject? =  StoredPropertyObject()
        let propertyHolder2 = PassThroughPropertyObject(parentPropertyObject: propertyHolder1!)
        XCTAssertNotNil(propertyHolder2)// Access property to silence property was never used warning from compiler; property is used to retain

        weak var weakDependency = propertyHolder1!.property

        XCTAssertNotNil(weakDependency)

        propertyHolder1 = nil

        XCTAssertNotNil(weakDependency)
    }

    func testPassThroughPropertyAllowsParentToDeallocate() {
        var propertyHolder1: StoredPropertyObject? = StoredPropertyObject()
        var propertyHolder2: PassThroughPropertyObject? = PassThroughPropertyObject(parentPropertyObject: propertyHolder1!)

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

    func testPassThroughPropertyDoesNotLeakOnChangeCallbacks() {
        let propertyHolder1: StoredPropertyObject = StoredPropertyObject()
        var propertyHolder2: PassThroughPropertyObject? = PassThroughPropertyObject(parentPropertyObject: propertyHolder1)
        XCTAssertNotNil(propertyHolder2)// Access property to silence property was never used warning from compiler; property is used to retain

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 1)

        propertyHolder2 = nil

        XCTAssertEqual(propertyHolder1.property._testOnly_numberOfOnChangeCallbacks, 0)
    }
}

class StoredPropertyObject {
    let property: StoredProperty<Int> = StoredProperty(3)
}

class DerivedPropertyObject {

    var property: DerivedProperty<Int>!

    init(parentPropertyObject: StoredPropertyObject) {
        let parentProperty = parentPropertyObject.property
        property = DerivedProperty(parentProperty) {
            return $0 * 2
        }
    }
}

class PassThroughPropertyObject {
    var property: PassThroughProperty<Int>!

    init(parentPropertyObject: StoredPropertyObject) {
        let parentProperty = parentPropertyObject.property
        property = PassThroughProperty(parentProperty: parentProperty)
    }
}
