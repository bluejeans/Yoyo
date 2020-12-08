// Copyright © 2020 Blue Jeans Network, Inc.

import Foundation

class Crasher {
    static var crashMock: ((String) -> Void)?

    static func crash(message: String) -> Never {
        if let crashMock = crashMock {
            crashMock(message)
            repeat {
                RunLoop.current.run()
            } while(true)
        } else {
            fatalError(message)
        }
    }
}
