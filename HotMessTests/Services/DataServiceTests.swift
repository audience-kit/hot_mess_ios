//
//  DataServiceTests.swift
//  HotMess
//
//  Created by Rick Mark on 4/27/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import XCTest
@testable import HotMess

class DataServiceTests: XCTestCase {
    let appAccessToken = "EAANAlai5rHABAGFLMDZBpiQORZBZARtyVwBqzGegyRrMZAuOiivivxysjTqZA2J16RLkciz19DQjDZAci3ea3AOColJjXbFxtnDFmOHEJmFC8ZCcKSGcXknEz2WWIi4eYhM2JY3Lu6V5ZAZC5PkZBLuE7uCPiIJyZBmloi1ge7JyEOQ4nZBoZBgmeektL"
    
    override func setUp() {
        super.setUp()
        
        let expectation = self.expectation(description: "Data Session Callback")
        
        SessionService.getToken(token: appAccessToken) {
            XCTAssert(SessionService.token != nil)
            expectation.fulfill()
        }
        
        XCTWaiter.wait(for: [expectation], timeout: 10)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetVenues() {
        let expectation = self.expectation(description: "Venues Callback")
        DataService.shared.venues { (venues) in
            expectation.fulfill()
        }
        XCTWaiter.wait(for: [expectation], timeout: 10)
    }
    
    func testGetVenue() {
        let expectation = self.expectation(description: "Venue Callback")
        DataService.shared.venues { (venues) in
            DataService.shared.venue(venues.venues.first!) { (venue) in
                expectation.fulfill()
            }
        }
        XCTWaiter.wait(for: [expectation], timeout: 10)
    }
    
    func testGetEvents() {
        let expectation = self.expectation(description: "Events Callback")
        DataService.shared.events { (venues) in
            expectation.fulfill()
        }
        
        XCTWaiter.wait(for: [expectation], timeout: 10)
    }
    
    func testGetVenueEvents() {
        let expectation = self.expectation(description: "Venue Events Callback")
        DataService.shared.venues { (venues) in
            DataService.shared.events(venue: venues.venues.first!) { (venues) in
                expectation.fulfill()
            }
        }
        XCTWaiter.wait(for: [expectation], timeout: 10)
    }
}
