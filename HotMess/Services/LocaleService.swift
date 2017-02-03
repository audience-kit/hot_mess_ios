//
//  LocaleService.swift
//  HotMess
//
//  Created by Rick Mark on 2/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class LocaleService : NSObject, CLLocationManagerDelegate {
    static let kHMLocaleUpdated = Notification.Name(rawValue: "kHMLocaleUpdated")
    
    private static let _shared = LocaleService()
    
    private var _closest : Locale? = nil
    private let _locationManager = CLLocationManager()
    
    static var shared : LocaleService {
        return _shared
    }
    
    static var closest : Locale? {
        return _shared._closest
    }
    
    override init() {
        super.init()
        
        _locationManager.delegate = self
        _locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func start() {
        _locationManager.startMonitoringSignificantLocationChanges()
        
        closest { (locale) in
            
        }
    }
    
    var coordinates: [ String : Any ] {
        guard _locationManager.location != nil else { return [ String: Any]() }
    
        return [ "longitude" : _locationManager.location!.coordinate.longitude, "latitude" : _locationManager.location!.coordinate.latitude ]
    }
    
    func closest(callback: @escaping (Locale) -> Void) {
        let params = self.coordinates
        
        let path = "/locales/closest?\(params.queryParameters)"
        
        RequestService.shared.request(relativeUrl: path) { result in
            let locale = Locale(result)
            self._closest = locale
            
            callback(locale)
            
            NotificationCenter.default.post(name: LocaleService.kHMLocaleUpdated, object: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        UserService.shared.location(locations.first!)
        
        closest { locale in
        
        }
    }
}
