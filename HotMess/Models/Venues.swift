//
//  Venues.swift
//  HotMess
//
//  Created by Rick Mark on 3/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import GeoJSON

class Venues {
    let venues: [ Venue ]
    let envelope: GeoJSONPolygon?
    
    init() {
        self.venues = [ Venue ]()
        self.envelope = nil
    }
    
    init(_ data: [ String : Any ]) {
        let venues = data["venues"] as! [ [ String : Any ] ]
        var parsed: [ Venue ] = []
        
        for venue in venues {
            parsed.append(Venue(with: venue))
        }
        
        self.venues = parsed
        
        if let envelopeData = data["envelope"] as? [ String : Any ] {
            self.envelope = GeoJSONPolygon(dictionary: envelopeData)
        }
        else {
            self.envelope = nil
        }
    }
}
