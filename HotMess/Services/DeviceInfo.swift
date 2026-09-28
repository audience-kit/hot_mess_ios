//
//  DeviceInfo.swift
//  HotMess
//

import Foundation
import UIKit

/// Facts about the device that the API wants attached to a session.
@MainActor
enum DeviceInfo {
    static var vendorIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    /// The hardware identifier, e.g. `iPhone17,1`.
    static var model: String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            let bytes = buffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    static func description(for configuration: AppConfiguration) -> DeviceDescription {
        DeviceDescription(
            identifier: vendorIdentifier,
            version: configuration.version,
            build: String(configuration.build),
            model: model
        )
    }
}
