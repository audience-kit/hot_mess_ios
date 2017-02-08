//
//  DistanceFormatter.swift
//  HotMess
//
//  Created by Rick Mark on 2/7/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class DistanceFormatter {
    let feetInMeter = 3.28084
    let feetInMile = 5280.0
    
    static let shared = DistanceFormatter()
    
    func string(forMeters: Double) -> String {
        // TODO detect meters localization
        
        let feet = forMeters * feetInMeter
        
        if feet < 1000 {
            return "\(Int(feet)) ft"
        }
        else {
            let miles = feet / feetInMile
            
            return "\(String(format: "%.01f", miles)) m"
        }
    }
}
