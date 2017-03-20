    //
//  User.swift
//  HotMess
//
//  Created by Rick Mark on 1/6/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Atlas
import Kingfisher

class User : Model, ATLAvatarItem {

    public let name: String
    
    public var avatarImageURL: URL? {
        return RequestService.shared.baseUrl.appendingPathComponent("/users/\(id)/picture")
    }
    
    public var avatarImage: UIImage? {
        guard avatarImageURL != nil else { return nil }
        
        if let memoryImage = ImageCache.default.retrieveImageInMemoryCache(forKey: avatarImageURL!.absoluteString) {
            return memoryImage
        }
        
        if let diskIamge = ImageCache.default.retrieveImageInDiskCache(forKey: avatarImageURL!.absoluteString) {
            return diskIamge
        }
        
        return nil
    }
    
    public var avatarInitials: String? {
        return name.components(separatedBy: " ").reduce("") { "\($0)\($1.characters.first)" }
    }
    
    public var firstName: String? {
        return name.components(separatedBy: " ").first
    }

    override init(_ data: [ String : Any ]) {
        // TODO: HORIBLE series of assertions
        name = data["name"] as! String
        
        super.init(data)
    }
}
