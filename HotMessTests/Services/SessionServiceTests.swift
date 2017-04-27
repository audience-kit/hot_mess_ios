//
//  SessionServiceTests.swift
//  HotMess
//
//  Created by Rick Mark on 4/27/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import XCTest
@testable import HotMess

class SessionServiceTests: XCTestCase {
    
    let appAccessToken = "EAANAlai5rHABAGFLMDZBpiQORZBZARtyVwBqzGegyRrMZAuOiivivxysjTqZA2J16RLkciz19DQjDZAci3ea3AOColJjXbFxtnDFmOHEJmFC8ZCcKSGcXknEz2WWIi4eYhM2JY3Lu6V5ZAZC5PkZBLuE7uCPiIJyZBmloi1ge7JyEOQ4nZBoZBgmeektL"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetToken() {
        let expectation = XCTestExpectation(description: "Callback")
        
        SessionService.getToken(token: appAccessToken) {
            XCTAssert(SessionService.token != nil)
            expectation.fulfill()
        }
        
        XCTWaiter.wait(for: [expectation], timeout: 2)
    }
    
    func testLogOut() {
        let expectation = XCTestExpectation(description: "Callback")
        
        SessionService.getToken(token: appAccessToken) {
            XCTAssert(SessionService.token != nil)
            expectation.fulfill()
        }
        
        XCTWaiter.wait(for: [expectation], timeout: 2)
        SessionService.logOut()
        XCTAssert(SessionService.token == nil)
    }
}
