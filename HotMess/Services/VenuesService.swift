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
    
    func index(_ callback: @escaping ([ Venue ]) -> Void) {
        var path = "/venues"
        
        if let locale = LocaleService.closest {
            path = "/locales/\(locale.id)/venues?\(LocaleService.shared.coordinates.queryParameters)"
        }

        RequestService.sharedInstance.request(relativeUrl: path) { (result) in
            let venues = result["venues"] as! [ [ String : Any ] ]
            var parsed: [ Venue ] = []
            
            for venue in venues {
                parsed.append(Venue(with: venue))
            }
            
            callback(parsed)
        }
    }
}
