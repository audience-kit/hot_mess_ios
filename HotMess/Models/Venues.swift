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
        
        if let envelopeData = data["envelope"] as? [ String : Any ],
           let json = try? JSONSerialization.data(withJSONObject: envelopeData, options: []) {
            self.envelope = try? JSONDecoder().decode(Polygon.self, from: json)
        }
        else {
            self.envelope = nil
        }
    }
    
    var mapKitEnvelope : MKMapRect? {
        guard let points = envelope?.exterior.points, !points.isEmpty else { return nil }
        
        // GeoJSON positions are [longitude, latitude]
        return points.reduce(MKMapRect.null) { rect, point in
            let mapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: point.y, longitude: point.x))
            return rect.union(MKMapRect(origin: mapPoint, size: MKMapSize(width: 0, height: 0)))
        }
    }
}
