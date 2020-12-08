// Copyright © 2020 Blue Jeans Network, Inc.

import XCTest
@testable import Yoyo

class YoyoKVOCompatibilityTests: XCTestCase {

    //Compile-time "test" - ensure these can be dynamic
    dynamic var foo: KVOCompatibleProperty!
    dynamic var bar: TwoWayKVOCompatibleProperty!

    private var observer: KVOObserver?

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        Crasher.crashMock = nil
    }

    func testKVOCompatibleProperty() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeKVOCompatible(property)
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 3)
        property.value = 42
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 42)
    }

    func testKVOCompatiblePropertyKVOable() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeKVOCompatible(property)
        var changeFired = false
        self.observer = KVOObserver(property: kvoCompatibleProperty, onChange: {
            changeFired = true
        })
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testKVOCompatiblePropertyInvalidType() {
        let property = StoredProperty(NotKVOable())
        assertCrash {
            _ = makeKVOCompatible(property)
        }
    }

    func testTwoWayKVOCompatibleProperty() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 3)
        property.value = 42
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 42)
    }

    func testTwoWayKVOCompatiblePropertyKVOable() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        var changeFired = false
        self.observer = KVOObserver(property: kvoCompatibleProperty, onChange: {
            changeFired = true
        })
        XCTAssert(!changeFired)
        property.value = 42
        XCTAssert(changeFired)
    }

    func testTwoWayKVOCompatiblePropertyInvalidType() {
        let property = StoredProperty(NotKVOable())
        assertCrash {
            _ = makeTwoWayKVOCompatible(property)
        }
    }

    func testTwoWayKVOCompatiblePropertyWritable() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        var changeFired = false
        property.onChange({changeFired = true})
        XCTAssert(!changeFired)
        kvoCompatibleProperty.value = 42
        XCTAssert(changeFired)
        XCTAssertEqual(property.value, 42)
    }

    func testTwoWayKVOCompatiblePropertyWriteInvalidValue() {
        let property = StoredProperty(3)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        var changeFired = false
        property.onChange({changeFired = true})
        XCTAssert(!changeFired)
        kvoCompatibleProperty.value = NSObject()
        // Should be ignored
        XCTAssert(!changeFired)
        XCTAssertEqual(property.value, 3)
    }

    private func assertCrash(_ test: @escaping () -> Void) {
        let expectation = self.expectation(description: "expectingFatalError")
        Crasher.crashMock = { message in
            expectation.fulfill()
        }
        if #available(OSX 10.10, *) {
            DispatchQueue.global().async(execute: test)
        } else {

        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testKVOCompatiblePropertyWithNilableParentInit() {
        let property = StoredProperty<Int?>(nil)
        let kvoCompatibleProperty = makeKVOCompatible(property)
        XCTAssertNil(kvoCompatibleProperty.value)
        property.value = 3
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 3)
    }

    func testKVOCompatiblePropertyWithNilableParentSet() {
        let property = StoredProperty<Int?>(3)
        let kvoCompatibleProperty = makeKVOCompatible(property)
        XCTAssertEqual(kvoCompatibleProperty.value as? Int, 3)
        property.value = nil
        XCTAssertNil(kvoCompatibleProperty.value)
    }

    func testTwoWayKVOCompatiblePropertyWithNilableParentInit() {
        let property = StoredProperty<Int?>(nil)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        kvoCompatibleProperty.value = 3
        XCTAssertEqual(property.value, 3)
    }

    func testTwoWayKVOCompatiblePropertyWithNilableParentSet() {
        let property = StoredProperty<Int?>(3)
        let kvoCompatibleProperty = makeTwoWayKVOCompatible(property)
        kvoCompatibleProperty.value = nil
        XCTAssertNil(property.value)
    }

    // MARK: - Memory management tests

    func testKVOCompatiblePropertyDeallocates() {
        class Test { // swiftlint:disable:this nesting
            let property = StoredProperty(false)
            var kvo: KVOCompatibleProperty! // Making this dynamic causes the test to fail; not sure if framework issue

            init() {
                kvo = makeKVOCompatible(property)
            }

            deinit {
                kvo = nil
            }
        }

        var test: Test? = Test()
        weak var weakTest = test
        weak var weakKVO = test?.kvo

        XCTAssertNotNil(weakTest)
        XCTAssertNotNil(weakKVO)

        test = nil
        XCTAssertNil(weakTest)
        XCTAssertNil(weakKVO)
    }

    func testTwoWayKVOCompatiblePropertyDeallocates() {
        class Test { // swiftlint:disable:this nesting
            let property = StoredProperty(false)
            var twoWayKVO: TwoWayKVOCompatibleProperty!  // Making this dynamic causes the test to fail; not sure if framework issue

            init() {
                twoWayKVO = makeTwoWayKVOCompatible(property)
            }
        }

        var test: Test? = Test()
        weak var weakTest = test
        weak var weakTwoWayKVO = test?.twoWayKVO

        XCTAssertNotNil(weakTest)
        XCTAssertNotNil(weakTwoWayKVO)

        test = nil
        XCTAssertNil(weakTest)
        XCTAssertNil(weakTwoWayKVO)
    }

    /**
     We have a base class that has a property and calls Yoyo.attachOwnerToProperties(referencedBy: self).
     We have another class that uses the base class to derive a passthrough property and a KVO-compatible property
     from the passthrough.
     We need to make sure that this scenario does not cause any retain cycles.
     */
    func testPassthroughKVOPropertyDealloc() {
        class Base { // swiftlint:disable:this nesting
            let property = StoredProperty(false)
        }

        class Test: NSObject { // swiftlint:disable:this nesting
            let base: Base
            var passthrough: PassThroughProperty<Bool>!
            var passthroughKVO: KVOCompatibleProperty!  // Making this dynamic causes the test to fail; not sure if framework issue

            init(base baseIn: Base) {
                self.base = baseIn
                passthrough =  PassThroughProperty(parentProperty: base.property)
                passthroughKVO = makeKVOCompatible(passthrough)

                super.init()
            }
        }

        var base: Base? = Base()
        weak var weakBase = base

        var test: Test? = Test(base: base!)
        weak var weakTest = test

        weak var weakKVOProperty = test?.passthroughKVO

        base = nil
        XCTAssertNotNil(weakTest)
        XCTAssertNotNil(weakBase)
        XCTAssertNotNil(weakKVOProperty)

        test = nil
        XCTAssertNil(weakTest)
        XCTAssertNil(weakBase)
        XCTAssertNil(weakKVOProperty)
    }

}

struct NotKVOable {}

class KVOObserver: NSObject {
    private let onChange: () -> Void
    private let property: NSObject

    private var kvoObservation: NSKeyValueObservation?

    init(property: NSObject, onChange: @escaping () -> Void) {
        self.onChange = onChange
        self.property = property

        super.init()

        if let kvoProperty = property as? KVOCompatibleProperty {
            kvoObservation = kvoProperty.observe(\.value, changeHandler: { [weak self] _, _ in
                self?.onChange()
            })
        } else if let twoWayKVOProperty = property as? TwoWayKVOCompatibleProperty {
            kvoObservation = twoWayKVOProperty.observe(\.value, changeHandler: { [weak self] _, _ in
                self?.onChange()
            })
        } else {
            fatalError("Cannot observe value of property: \(property)")
        }
    }
}
