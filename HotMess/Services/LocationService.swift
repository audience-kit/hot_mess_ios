//
//  LocaleService.swift
//  HotMess
//
//  Created by Rick Mark on 2/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import CoreLocation

class LocationService : NSObject, CLLocationManagerDelegate {
    static let beaconIdentifier = "social.hotmess.beacon"
    
    static let LocaleUpdated = Notification.Name(rawValue: "LocaleUpdated")
    static let LocationChanged = Notification.Name(rawValue: "LocationChanged")
    
    private static let _shared = LocationService()
    
    private var _closest : Locale? = nil
    private let _locationManager = CLLocationManager()
    private var beaconMajor = 0
    private var beaconMinor = 0
    private var beaconRegion: CLBeaconRegion
    private var lastLocation: CLLocation?
    
    private let tolerance = 0.0001

    
    static var shared : LocationService {
        return _shared
    }
    
    static var closest : Locale? {
        return _shared._closest
    }
    
    override init() {
        
        let beaconId = UUID(uuidString: Bundle.main.infoDictionary!["HotMessBeaconID"] as! String)!
        self.beaconRegion = CLBeaconRegion(proximityUUID: beaconId, identifier: LocationService.beaconIdentifier)
        
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
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: nil, queue: OperationQueue.main) { (notification) in
            self._locationManager.requestAlwaysAuthorization()
            self._locationManager.startMonitoringSignificantLocationChanges()
            //_locationManager.startMonitoring(for: beaconRegion)
            self.update()
        }
    }
    
    func stop() {
        _locationManager.stopMonitoringSignificantLocationChanges()
        
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
    
    func update() {
        let params = self.coordinates
        
        let path = "/v1/locales/closest?\(params.queryParameters)"
        
        RequestService.shared.request(relativeUrl: path) { result in
            let locale = Locale(result.data)
            
            UserDefaults.standard.set(locale.name, forKey: "localeName")
            UserDefaults.standard.set(locale.id.uuidString, forKey: "localeId")
            UserDefaults.standard.synchronize()
            
            if self._closest == nil || self._closest!.id != locale.id {
                self._closest = locale
                NotificationCenter.default.post(name: LocationService.LocaleUpdated, object: nil)
                NotificationCenter.default.post(name: LocationService.LocationChanged, object: nil)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        update()

        LocationService.shared.location(locations.first!)
        
        NotificationCenter.default.post(name: LocationService.LocationChanged, object: self)
    }
    
    func location(_ location: CLLocation, beaconMajor: Int = 0, beaconMinor: Int = 0) {
        let location = [ "coordinates": [ "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude], "beacon": [ "major": beaconMajor, "minor": beaconMinor] ] as [String : Any]
        
        RequestService.shared.request(relativeUrl: "/v1/me/location", with: location) { result in
            
        }
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
        
        LocationService.shared.location(_locationManager.location!, beaconMajor: self.beaconMajor, beaconMinor: self.beaconMinor)
    }
}
