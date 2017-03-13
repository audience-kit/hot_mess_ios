//
//  PersonDetail.swift
//  HotMess
//
//  Created by Rick Mark on 3/13/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class PersonDetail: Person {
    let events: [ Event ]
    let socialLinks: [ SocialLink ]
    let tracks: [ Track ]
    
    override init(_ data: [ String : Any ]) {
        var events = [ Event ]()
        if let eventsData = data["events"] as? [ [ String : Any ] ] {
            for eventData in eventsData {
                events.append(Event(eventData))
            }
        }
        self.events = events
        
        var socialLinks = [ SocialLink ]()
        if let socialLinksData = data["social_links"] as? [ [ String : Any ] ] {
            for socialLinkData in socialLinksData {
                socialLinks.append(SocialLink(socialLinkData))
            }
        }
        self.socialLinks = socialLinks
        
        var tracks = [ Track ]()
        if let tracksData = data["tracks"] as? [ [ String : Any ] ] {
            for trackData in tracksData {
                tracks.append(Track(trackData))
            }
        }
        self.tracks = tracks
        
        super.init(data)
    }
}
