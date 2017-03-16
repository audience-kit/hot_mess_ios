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
        guard LocaleService.closest != nil else { return }
        
        RequestService.shared.request(relativeUrl: "/locales/\(LocaleService.closest!.id)/events") { (result) in
            let events = result["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []
            
            for event in events {
                results.append(Event(event))
            }
            
            callback(results)
        }
    }
    
    func index(venue: Venue, callback: @escaping ([ Event ]) -> Void) {
        RequestService.shared.request(relativeUrl: "/venues/\(venue.id)/events") { (result) in
            let events = result["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []

            for event in events {
                results.append(Event(event))
            }

            callback(results)
        }
    }
    
    func get(_ event: Event, callback: @escaping (EventDetail) -> Void) {
        RequestService.shared.request(relativeUrl: "/events/\(event.id)") { (result) in
            let event = result["event"] as! [ String : Any ]
            
            callback(EventDetail(event))
        }
    }
}
