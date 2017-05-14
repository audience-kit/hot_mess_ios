//
//  RequestService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Locksmith
import FacebookLogin
import SystemConfiguration

class RequestService
{
    private static let sharedInstance = RequestService()

    static let serverBaseIdentifier = "HotMessServerBase"
    
    private var _isAuthenticating = false
    
    var baseUrl: URL {
        let serverString = Bundle.main.infoDictionary![RequestService.serverBaseIdentifier] as! String
        return URL(string: serverString)!
    }

    public static var shared: RequestService {
        return RequestService.sharedInstance
    }
    
    func request(relativeUrl: String, _ callback : @escaping (DataResult) -> Void) {
        return self.request(DataRequest(relativeUrl, parameters: nil, callback: callback))
    }
    
    func request(relativeUrl: String, with: [String: Any]?, _ callback : @escaping (DataResult) -> Void) {
        return self.request(DataRequest(relativeUrl, parameters: with, callback: callback))
    }
    
    func request(_ dataRequest: DataRequest) {
        dataRequest.operationQueue?.async {
            let url = URL(string: dataRequest.path, relativeTo: self.baseUrl)
            
            var request = URLRequest(url: url!)
            
            do {
                if let account = SessionService.token {
                    request.addValue("JWT \(account)", forHTTPHeaderField: "Authorization")
                }
                
                if (dataRequest.parameters != nil) {
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: dataRequest.parameters!, options: .prettyPrinted)
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
                    
                    if (httpResponse!.statusCode != 200)
                    {
                        if let callback = dataRequest.callback {
                            callback(DataResult(dataRequest, error: nil))
                        }
                        
                        return
                    }
                    
                    let data = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [ String: Any]
                    
                    if data != nil {
                        dataRequest.callback!(DataResult(dataRequest, data: data!))
                    }
                })
                
                task.resume()
            }
            catch {
                dataRequest.callback!(DataResult(dataRequest, error: error))
            }
        }
    }
}


