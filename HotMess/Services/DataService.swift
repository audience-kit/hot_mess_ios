//
//  DataService.swift
//  HotMess
//
//  Created by Rick Mark on 4/27/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class DataService {
    static var _shared = DataService()
    
    static var shared : DataService{
        return _shared
    }
    
    func now(callback: @escaping (Now) -> Void) -> Void {
        RequestService.shared.request(relativeUrl: "/v1/now?\(LocationService.shared.coordinates.queryParameters)") { (result) in
            if result.success {
                callback(Now(result.data))
            }
        }
    }
    
    func people(callback: @escaping ([ Person ]) -> Void) {
        guard LocationService.closest != nil else { return }
        
        RequestService.shared.request(relativeUrl: "/v1/locales/\(LocationService.closest!.id)/people") { (result) in
            let people = result.data["people"] as! [ [ String : Any ] ]
            var results: [ Person ] = []
            
            for person in people {
                results.append(Person(person))
            }
            
            callback(results)
        }
    }
    
    func person(_ personId: UUID, callback: @escaping (PersonDetail) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/people/\(personId)") { (result) in
            let person = result.data["person"] as! [ String : Any ]
            
            callback(PersonDetail(person))
        }
    }
    
    func venues(_ callback: @escaping (Venues) -> Void) {
        var path = "/v1/venues"
        
        if let locale = LocationService.closest {
            path = "/v1/locales/\(locale.id)/venues?\(LocationService.shared.coordinates.queryParameters)"
        }
        
        RequestService.shared.request(relativeUrl: path) { (result) in
            callback(Venues(result.data))
        }
    }
    
    func venue(_ id: UUID, callback: @escaping (VenueDetail) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/venues/\(id)") { (result) in
            callback(VenueDetail(result.data["venue"] as! [String : Any]))
        }
    }
    
    func venueFriends(_ id: UUID, callback: @escaping ([ Friend ]) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/venues/\(id)/friends") { (result) in
            let friends = result.data["friends"] as! [ [ String : Any ] ]
            var parsed: [ Friend ] = []
            
            for friend in friends {
                parsed.append(Friend(friend))
            }
            
            callback(parsed)
        }
    }
    
    func events(callback: @escaping (EventListing) -> Void) {
        guard LocationService.closest != nil else { return }
        
        RequestService.shared.request(relativeUrl: "/v1/locales/\(LocationService.closest!.id)/events") { (result) in
            callback(EventListing(result.data))
        }
    }
    
    func events(venue: Venue, callback: @escaping ([ Event ]) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/venues/\(venue.id)/events") { (result) in
            let events = result.data["events"] as! [ [ String : Any ] ]
            var results: [ Event ] = []
            
            for event in events {
                results.append(Event(event))
            }
            callback(results)
        }
    }
    
    func event(_ event: Event, callback: @escaping (EventDetail) -> Void) {
        self.event(event.id, callback: callback)
    }
    
    func event(_ id: UUID, callback: @escaping (EventDetail) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/events/\(id)") { (result) in
            let event = result.data["event"] as! [ String : Any ]
            
            callback(EventDetail(event))
        }
    }
    
    func rsvp(_ event: Event) {
        RequestService.shared.request(relativeUrl: "/v1/events/\(event.id)/rsvp", with: [ "state": event.rsvp ]) { (result) in
            
        }
    }
}
