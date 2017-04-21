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
    
    func index(callback: @escaping (EventListing) -> Void) {
        guard LocaleService.closest != nil else { return }
        
        RequestService.shared.request(relativeUrl: "/v1/locales/\(LocaleService.closest!.id)/events") { (result) in
            callback(EventListing(result))
        }
    }
    
    func index(venue: Venue, callback: @escaping ([ Event ]) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/venues/\(venue.id)/events") { (result) in
            let events = result["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []
            
            for event in events {
                results.append(Event(event))
            }
            callback(results)
        }
    }
        
    func get(_ event: Event, callback: @escaping (EventDetail) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/events/\(event.id)") { (result) in
            let event = result["event"] as! [ String : Any ]
            
            callback(EventDetail(event))
        }
    }
    
    func rsvp(_ event: Event) {
        RequestService.shared.request(relativeUrl: "/v1/events/\(event.id)/rsvp", with: [ "state": event.rsvp ]) { (result) in

        }
    }
}
