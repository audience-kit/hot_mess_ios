//
//  EventsService.swift
//  HotMess
//
//  Created by Rick Mark on 1/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class EventsService {
    private static let _sharedInstance = EventsService()
    
    static var shared: EventsService {
        return _sharedInstance
    }
    
    func index(callback: @escaping ([ Event ]) -> Void) {
        RequestService.sharedInstance.request(relativeUrl: "/events") { (result) in
            let events = result["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []
            
            for event in events {
                results.append(Event(with: event))
            }
            
            callback(results)
        }
    }
    
    func index(venue: Venue, callback: @escaping ([ Event ]) -> Void) {
        RequestService.sharedInstance.request(relativeUrl: "/venues/\(venue.id)/events") { (result) in
            let events = result["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []

            for event in events {
                results.append(Event(with: event))
            }

            callback(results)
        }
    }
}
