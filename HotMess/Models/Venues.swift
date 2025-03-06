//
//  Venues.swift
//  HotMess
//
//  Created by Rick Mark on 3/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import MapKit
import GEOSwift

class Venues {
    let venues: [ Venue ]
    let envelope: Polygon?
    
    init() {
        self.venues = [ Venue ]()
        self.envelope = nil
    }
    
    init(_ data: [ String : Any ]) {
        let venues = data["venues"] as! [ [ String : Any ] ]
        var parsed: [ Venue ] = []
        
        for venue in venues {
            parsed.append(Venue(venue))
        }
        
        self.venues = parsed
        
        if let envelopeData = data["envelope"] as? [ String : Any ] {
            let jsonData = try? JSONSerialization.data(withJSONObject: envelopeData, options: [])
                    let decoder = JSONDecoder()
            self.envelope = try? decoder.decode(Polygon.self, from: jsonData!)
        }
        else {
            self.envelope = nil
        }
    }
    
    var mapKitEnvelope : MKMapRect? {
        guard envelope != nil else { return nil }
        
        let origin = (try? MKMapPoint(x: self.envelope!.centroid().x, y: self.envelope!.centroid().y))!
        let size = try? MKMapSize(width: self.envelope!.minimumWidth().length(),
                                  height: self.envelope!.geometry.length())
        
        return MKMapRect(origin: origin, size: size!)
    }
}
