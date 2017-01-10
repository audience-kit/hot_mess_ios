//
//  RequestService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Locksmith

class RequestService
{
    public static let sharedInstance = RequestService()
    
    public static let baseUrl = URL(string: Bundle.main.infoDictionary?["HotMessServerBase"] as! String)
    
    func request(relativeUrl: String, _ callback : @escaping ([String: Any]) -> Void) {
        return self.request(relativeUrl: relativeUrl, with: nil, callback)
    }
    
    func request(relativeUrl: String, with: [String: Any]?, _ callback : @escaping ([String: Any]) -> Void) {
        let url = URL(string: relativeUrl, relativeTo: RequestService.baseUrl)
        
        var request = URLRequest(url: url!)
        
        do {
            if let account = SessionService.token {
                request.addValue("Bearer \(account)", forHTTPHeaderField: "Authorization")
            }
            
            if (with != nil) {
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: with!, options: .prettyPrinted)
            }
            else {
                request.httpMethod = "GET"
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                let httpResponse = response as! HTTPURLResponse
                
                if (httpResponse.statusCode == 401)
                {
                    NotificationCenter.default.post(name: SessionService.loginRequired, object: self)
                    return
                }
                
                let data = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [ String: Any]
                
                if data != nil {
                    callback(data!)
                }
            })
            
            task.resume()
        }
        catch {
            callback([:])
        }
        
    }
}
