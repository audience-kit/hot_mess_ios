//
//  DeviceService.swift
//  HotMess
//
//  Created by Rick Mark on 4/27/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class DeviceService {

    static var deviceToken : String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    static var applicationVersion : String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    static var applicationBuild : String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }
    
    static var deviceModel : String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
