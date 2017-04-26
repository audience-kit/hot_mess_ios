//
//  LocaleModelTests.swift
//  HotMess
//
//  Created by Rick Mark on 4/26/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import XCTest
@testable import HotMess

class LocaleModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitialize() {
        let locale = Locale([ "id" : "48B36A89-FABB-458A-82E5-108737AA756A", "name" : "Seattle" ])
        
        XCTAssert(locale.name == "Seattle")
        XCTAssert(locale.id == UUID(uuidString: "48B36A89-FABB-458A-82E5-108737AA756A"))
    }
}
