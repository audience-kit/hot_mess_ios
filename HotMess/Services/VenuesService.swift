//
//  VenuesService.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class VenuesService {
    private static let _sharedInstance = VenuesService()
    
    static var shared: VenuesService {
        return _sharedInstance
    }
    
    func index(_ callback: @escaping (Venues) -> Void) {
        var path = "/v1/venues"
        
        if let locale = LocaleService.closest {
            path = "/v1/locales/\(locale.id)/venues?\(LocaleService.shared.coordinates.queryParameters)"
        }

        RequestService.shared.request(relativeUrl: path) { (result) in
            callback(Venues(result))
        }
    }
    
    func closest(_ callback: @escaping (Venue) -> Void) {
        let path = "/v1/venues/closest?\(LocaleService.shared.coordinates.queryParameters)"
        
        RequestService.shared.request(relativeUrl: path) { (result) in
            if let venue = result["venue"] as? [ String : Any ] {
                callback(Venue(venue))
            }
        }
    }
}
