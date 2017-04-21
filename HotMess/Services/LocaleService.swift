//
//  LocaleService.swift
//  HotMess
//
//  Created by Rick Mark on 2/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import CoreLocation

class LocaleService : NSObject, CLLocationManagerDelegate {
    static let LocaleUpdated = Notification.Name(rawValue: "LocaleUpdated")
    static let LocationChanged = Notification.Name(rawValue: "LocationChanged")
    
    private static let _shared = LocaleService()
    
    private var _closest : Locale? = nil
    private let _locationManager = CLLocationManager()
    private var beaconMajor = 0
    private var beaconMinor = 0
    private var beaconRegion: CLBeaconRegion
    private var lastLocation: CLLocation?
    
    private let tolerance = 0.0001

    
    static var shared : LocaleService {
        return _shared
    }
    
    static var closest : Locale? {
        return _shared._closest
    }
    
    override init() {
        
        let beaconId = UUID(uuidString: Bundle.main.infoDictionary!["HotMessBeaconID"] as! String)!
        self.beaconRegion = CLBeaconRegion(proximityUUID: beaconId, identifier: AppDelegate.beaconIdentifier)
        
        super.init()
        
        
        _locationManager.delegate = self
        _locationManager.pausesLocationUpdatesAutomatically = true
        
        if let localeIdString = UserDefaults.standard.string(forKey: "localeId") {
            let localeName = UserDefaults.standard.string(forKey: "localeName")
            let localeId = UUID(uuidString: localeIdString)
            
            self._closest = Locale(id: localeId!, name: localeName!)
        }
        
    }
    
    func start() {
        _locationManager.requestAlwaysAuthorization()
        _locationManager.startMonitoringSignificantLocationChanges()
        _locationManager.startMonitoring(for: beaconRegion)

        closest { (locale) in
            
        }
    }
    
    var coordinates: [ String : Any ] {
        var parameters = [ String : Any ]()
        
        if let location = _locationManager.location {
            parameters["longitude"] = location.coordinate.longitude
            parameters["latitude"] = location.coordinate.latitude
        }
        
        if beaconMajor != 0 && beaconMinor != 0 {
            parameters["major"] = self.beaconMajor
            parameters["minor"] = self.beaconMinor
        }
        
        return parameters
    }
    
    func closest(callback: @escaping (Locale) -> Void) {
        let params = self.coordinates
        
        let path = "/v1/locales/closest?\(params.queryParameters)"
        
        RequestService.shared.request(relativeUrl: path) { result in
            let locale = Locale(result)
            self._closest = locale
            
            UserDefaults.standard.set(locale.name, forKey: "localeName")
            UserDefaults.standard.set(locale.id.uuidString, forKey: "localeId")
            UserDefaults.standard.synchronize()
            
            callback(locale)
            
            NotificationCenter.default.post(name: LocaleService.LocaleUpdated, object: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        closest { locale in
        
        }
        
        //if let location = lastLocation {
        //    let currentLocation = locations.first
            
        //    let deltaX = abs((currentLocation?.coordinate.latitude)! - location.coordinate.latitude)
        //    let deltaY = abs((currentLocation?.coordinate.longitude)! - location.coordinate.longitude)
            
        //     if deltaX > tolerance || deltaY > tolerance {
                UserService.shared.location(locations.first!)
                
                NotificationCenter.default.post(name: LocaleService.LocationChanged, object: self)
        //    }
        //}
        
        //self.lastLocation = locations.first
    }
    
    

    //func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLBeaconRegion) {
    //    manager.startRangingBeacons(in: region)
    //}
    

    
    //func locationManager(_ manager: CLLocationManager, didExitRegion region: CLBeaconRegion) {
    //    manager.stopRangingBeacons(in: region)
    //}
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        guard beacons.count > 0 else { return }
        
        self.beaconMajor = beacons.first?.major as! Int
        self.beaconMajor = beacons.first?.minor as! Int
        
        UserService.shared.location(_locationManager.location!, beaconMajor: self.beaconMajor, beaconMinor: self.beaconMinor)
    }
}
