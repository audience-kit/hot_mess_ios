//
//  DataRequest.swift
//  HotMess
//
//  Created by Rick Mark on 3/17/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class DataRequest {
    let path: String
    let parameters: [ String : Any ]?
    let callback: (([ String : Any ]) -> Void)?
    var skipAuthentication = false
    
    init(_ path: String, parameters: [ String : Any ]?, callback: @escaping ([ String : Any ]) -> Void) {
        self.path = path
        self.parameters = parameters
        self.callback = callback
    }
    
    init(_ path: String, parameters: [ String : Any ]?) {
        self.path = path
        self.parameters = parameters
        self.callback = nil
    }
}

protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}

extension Dictionary : URLQueryParameterStringConvertible {
    /**
     This computed property returns a query parameters string from the given NSDictionary. For
     example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
     string will be @"day=Tuesday&month=January".
     @return The computed parameters string.
     */
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                              String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                              String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
    
}

extension URL {
    /**
     Creates a new URL by adding the given query parameters.
     @param parametersDictionary The query parameter dictionary to add.
     @return A new URL.
     */
    func appendingQueryParameters(_ parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : String = String(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }
}
