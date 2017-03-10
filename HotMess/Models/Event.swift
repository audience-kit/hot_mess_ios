//
//  Event.swift
//  HotMess
//
//  Created by Rick Mark on 1/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Event : Model {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date?
    let facebookId: IntMax
    let venue: Venue?
    let person: Person?
    
    init(with: [ String : Any ]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        self.id = UUID(uuidString: with["id"] as! String)!
        self.name = with["name"] as! String
        let startAt = with["start_at"] as! String
        self.startDate = formatter.date(from: startAt)!
        self.facebookId = with["facebook_id"] as! IntMax
        
        if let venue_data = with["venue"] as? [ String : Any ] {
            self.venue = Venue(with: venue_data)
        }
        else {
            self.venue = nil
        }
        
        if let person_data = with["person"] as? [ String : Any ] {
            self.person = Person(person_data)
        }
        else {
            self.person = nil
        }
        
        if let endDateString = with["end_at"] as? String {
            self.endDate = formatter.date(from: endDateString)
        }
        else {
            self.endDate = nil
        }
    }
    
    var facebookUrl : URL {
        return URL(string: "https://facebook.com/events/\(self.facebookId)")!
    }
    
    static func ==(rhs: Event, lhs: Event) -> Bool {
        return rhs.id == lhs.id
    }
}
