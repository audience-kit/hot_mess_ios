//
//  RequestService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class RequestService
{
    public static let sharedInstance = RequestService()
    
    public static let baseUrl = URL(string: Bundle.main.infoDictionary?["HotMessServerBase"] as! String)
    
    func request(relativeUrl: String, with: [String: Any], _ block : ([String: Any]) -> Void) {
        let url = URL(string: relativeUrl, relativeTo: RequestService.baseUrl)
        
        var request = URLRequest(url: url!)
        
        do {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: with, options: .prettyPrinted)
            
            
            let result = URLSession.shared.downloadTask(with: request)
            
            result.resume()

            
        }
        catch {
            block([:])
        }
        
    }
}
