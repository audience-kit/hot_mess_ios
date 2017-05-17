//
//  Event.swift
//  HotMess
//
//  Created by Rick Mark on 1/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Event : Model, ListingItem {
    let name: String
    let startDate: Date
    let endDate: Date?
    let facebookId: IntMax
    let venue: Venue?
    let person: Person?
    let coverUrl: URL?
    let featured: Bool
    let linkUrl: URL?
    var rsvp: String = "unsure"
    
    var cellType: String { get { return featured ? "featuredEventCell" : "eventCell" } }
    
    override init(_ data: [ String : Any ]) {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        self.name = data["name"] as! String
        let startAt = data["start_at"] as! String
        self.startDate = formatter.date(from: startAt)!
        self.facebookId = data["facebook_id"] as! IntMax
        
        if let link = data["link"] as? String {
            self.linkUrl = URL(string: link)!
        }
        else {
            self.linkUrl = nil
        }
        
        if let venue_data = data["venue"] as? [ String : Any ] {
            self.venue = Venue(venue_data)
        }
        else {
            self.venue = nil
        }
        
        if let person_data = data["person"] as? [ String : Any ] {
            self.person = Person(person_data)
        }
        else {
            self.person = nil
        }
        
        if let coverPhotoUrl = data["cover_photo_url"] as? String {
            self.coverUrl = URL(string: coverPhotoUrl)!
        }
        else {
            self.coverUrl = nil
        }
        
        if let isFeatured = data["is_featured"] as? Bool {
            self.featured = isFeatured
        }
        else {
            self.featured = false
        }
        
        if let endDateString = data["end_at"] as? String {
            self.endDate = formatter.date(from: endDateString)
        }
        else {
            self.endDate = nil
        }
        
        if let rsvpString = data["rsvp"] as? String {
            self.rsvp = rsvpString
        }
        
        super.init(data)
    }
    
    var facebookUrl : URL {
        return URL(string: "https://facebook.com/events/\(self.facebookId)")!
    }
    
    static func ==(rhs: Event, lhs: Event) -> Bool {
        return rhs.id == lhs.id
    }
}
