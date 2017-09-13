//
//  GoNativeAuthUrl.swift
//  GoNativeIOS
//
//  Created by Weiyin He on 7/11/16.
//  Copyright © 2016 GoNative.io LLC. All rights reserved.
//

import Foundation

open class GoNativeAuthUrl : NSObject {
    @objc var currentUrl: URL?
    var allowedUrlRegexes: [NSPredicate]
    
    override init() {
        let appConfig = GoNativeAppConfig.shared()
        self.allowedUrlRegexes = LEANUtilities.createRegexArray(fromStrings: appConfig?.authAllowedUrls);
    }
    
    func isUrlAllowed(_ url: String?) -> Bool {
        if (url == nil) {
            return true
        }
        
        for regex in self.allowedUrlRegexes {
            if regex.evaluate(with: url) {
                return true
            }
        }
        
        return false
    }
    
    @objc
    func handleUrl(_ url: URL, callback: @escaping (_ postUrl: String?, _ postData: [String:Any]?, _ callbackFunc: String?)->Void) -> Void {
        if url.scheme != "gonative" || url.host != "auth" {
            return
        }
        
        if self.currentUrl != nil {
            // check current url against allowed
            let currentUrlString = self.currentUrl!.absoluteString
            if (!self.isUrlAllowed(currentUrlString)) {
                print("URL not allowed to access auth: ", currentUrlString)
                return
            }
        }
        
        var queryDict = [String:String]()
        let query = url.query
        if query != nil {
            let queryComponents = query!.components(separatedBy: "&")
            for keyValue in queryComponents {
                let pairComponents = keyValue.components(separatedBy: "=")
                if pairComponents.count != 2 {
                    continue
                }
                
                let key = pairComponents.first?.removingPercentEncoding
                let value = pairComponents.last?.removingPercentEncoding
                
                queryDict.updateValue(value!, forKey: key!)
            }
        }
        
        let callbackUrl = queryDict["callback"]
        // check callback url
        if callbackUrl != nil {
            let callbackAbsoluteUrl = URL.init(string: callbackUrl!, relativeTo: self.currentUrl)
            
            if callbackAbsoluteUrl != nil && !self.isUrlAllowed(callbackAbsoluteUrl?.absoluteString) {
                print("Callback URL not allowed to access auth: ", callbackAbsoluteUrl!.absoluteString)
                return
            }
        }
        
        let callbackFunction = queryDict["callbackFunction"];
        
        func doCallback(_ data: [String:Any]?) {
            callback(callbackUrl, data, callbackFunction)
        }
        
        let path = url.path
        if path == "/status" {
            if (callbackUrl == nil && callbackFunction == nil) {
                return
            }
            
            GoNativeKeychain().getStatusAsync({ (statusData:[String : AnyObject]) -> (Void) in
                doCallback(statusData)
                return
            })
        }
        else if path == "/save" {
            let secret = queryDict["secret"]
            if secret == nil {
                return
            }
            
            GoNativeKeychain().saveSecretAsync(secret!, callback: { (result) -> (Void) in
                if result == KeychainOperationResult.Success {
                    doCallback(["success": true])
                } else {
                    doCallback([
                        "success": false,
                        "error": result.rawValue
                        ])
                }
            })
        }
        else if path == "/get" {
            if (callbackUrl == nil && callbackFunction == nil) {
                return
            }
            
            let prompt = queryDict["prompt"]
            let callbackOnCancel = queryDict["callbackOnCancel"]
            var doCallbackOnCancel = false
            if callbackOnCancel != nil {
                let lower = callbackOnCancel?.lowercased()
                if lower != "0" && lower != "false" &&
                    lower != "no" {
                    doCallbackOnCancel = true
                }
            }
            
            GoNativeKeychain().getSecretAsync(prompt) { (result, secret) -> (Void) in
                if result == .Success {
                    doCallback([
                        "success": true,
                        "secret": secret == nil ? "" : secret!
                    ])
                } else if !(result == KeychainOperationResult.UserCanceled && !doCallbackOnCancel) {
                    doCallback([
                        "success": false,
                        "error": result.rawValue
                    ])
                }
            }
        }
        else if path == "/delete" {
            GoNativeKeychain().deleteSecretAsync({ (result) -> (Void) in
                if result == .Success {
                    doCallback(["success": true])
                } else {
                    doCallback([
                        "success": false,
                        "error": result.rawValue
                        ])
                }
            })
        }
    }
}
