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
    private static let sharedInstance = RequestService()
    
    private var _isAuthenticating = false
    
    var baseUrl: URL {
        return AppDelegate.baseUrl
    }

    public static var shared: RequestService {
        return RequestService.sharedInstance
    }
    
    func request(relativeUrl: String, _ callback : @escaping ([String: Any]) -> Void) {
        return self.request(relativeUrl: relativeUrl, with: nil, callback)
    }
    
    func request(relativeUrl: String, with: [String: Any]?, _ callback : @escaping ([String: Any]) -> Void) {
        let url = URL(string: relativeUrl, relativeTo: AppDelegate.baseUrl)
        
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
            
            NSLog("\(request.httpMethod!): \(request.url!)")
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                if let error = error {
                    NSLog(error.localizedDescription)
                }
                
                let httpResponse = response as? HTTPURLResponse
                
                if httpResponse == nil {
                    let alert = UIAlertController(title: "Error", message: "Unable to reach server. Check network connection.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
                    
                    DispatchQueue.main.async {
                        alert.show(UIApplication.shared.keyWindow!.rootViewController!, sender: self)
                    }
                    
                    return
                }
                
                if (httpResponse!.statusCode == 401)
                {
                    if (self._isAuthenticating == false) {
                        self._isAuthenticating = true
                        NotificationCenter.default.post(name: SessionService.loginRequired, object: self)
                    }
                    
                    return
                }
                
                self._isAuthenticating = false
                
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
