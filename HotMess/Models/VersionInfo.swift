//
//  VersionInfo.swift
//  HotMess
//
//  Created by Rick Mark on 4/30/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class VersionInfo {

    let minimumBuild: Int
    let currentVersion: String
    let minimumVersion: String
    
    init(_ data: [ String : Any ]) {
        self.minimumBuild = data["minimum_build"] as! Int
        self.currentVersion = data["current_version"] as! String
        self.minimumVersion = data["minimum_version"] as! String
    }
    
    static var isTestFlight : Bool { get {
            return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        }
    }
}
