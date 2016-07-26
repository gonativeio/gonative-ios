//
//  GoNativeKeychain.swift
//  GoNativeIOS
//
//  Created by Weiyin He on 7/1/16.
//  Copyright © 2016 GoNative.io LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

let kGoNativeKeychainService:String = "GoNative Keychain Service"

enum KeychainOperationResult: String {
    case Success = "success"
    case DuplicateItem = "duplicateItem"
    case ItemNotFound = "itemNotFound"
    case AuthenticationFailed = "authenticationFailed"
    case GenericError = "genericError"
    case UserCanceled = "userCanceled"
    case Unimplemented = "unimplemented"
}

public class GoNativeKeychain: NSObject {
    func getStatusAsync(callback: ([String:AnyObject]) -> (Void)) -> Void {
        getSecretExistsAsync { (exists) -> (Void) in
            let result: [String: AnyObject] = [
                "hasTouchId": self.hasTouchIdD(),
                "hasSecret": exists
            ]
            
            callback(result)
        }
    }
    
    private func hasTouchIdD() -> Bool {
        if #available(iOS 9.0, *) {
            return LAContext().canEvaluatePolicy(LAPolicy.DeviceOwnerAuthenticationWithBiometrics, error: nil)
        } else {
            return false
        }
    }
    
    func getSecretAsync(prompt: String?, callback: (result: KeychainOperationResult, secret: String?)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let operationPrompt = prompt == nil ? "Authenticate to retrieve saved credentials" : prompt
            
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecReturnData as String: true,
                kSecUseOperationPrompt as String: operationPrompt!
            ]
            
            var dataTypeRef: AnyObject?
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let status: OSStatus = withUnsafeMutablePointer(&dataTypeRef) {
                    SecItemCopyMatching(query as CFDictionaryRef, UnsafeMutablePointer($0))
                }
                
                if status == errSecSuccess {
                    let data = dataTypeRef as! NSData
                    let secret = String(data: data, encoding: NSUTF8StringEncoding)
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        callback(result: .Success, secret: secret)
                    })
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        callback(result: self.statusToEnum(status), secret: nil)
                    })
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                callback(result: .Unimplemented, secret: nil)
            })
        }
    }
    
    func getSecretExistsAsync(callback: (exists: Bool)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecUseNoAuthenticationUI as String: true
            ]
            
            var dataTypeRef: AnyObject?
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let status: OSStatus = withUnsafeMutablePointer(&dataTypeRef) {
                    SecItemCopyMatching(query as CFDictionaryRef, UnsafeMutablePointer($0))
                }
                
                if status == errSecInteractionNotAllowed || status == errSecSuccess {
                    callback(exists: true)
                } else {
                    callback(exists: false)
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                callback(exists: false)
            })
        }
    }
    
    func saveSecretAsync(secret: String, callback:(result: KeychainOperationResult)->(Void)) -> Void {
        deleteSecretAsync { (deleteResult) -> (Void) in
            // ignore delete result
            self._saveSecretAsync(secret, callback: callback)
        }
    }
    
    private func _saveSecretAsync(secret: String, callback:(result:KeychainOperationResult)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let secretData = secret.dataUsingEncoding(NSUTF8StringEncoding)
            
            let accessControlError:UnsafeMutablePointer<Unmanaged<CFError>?> = nil
            let accessControlRef = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, SecAccessControlCreateFlags.TouchIDAny, accessControlError)
            
            if accessControlRef == nil || accessControlError != nil {
                dispatch_async(dispatch_get_main_queue(), {
                    callback(result: .GenericError)
                })
                return
            }
            
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecValueData as String: secretData!,
                kSecUseNoAuthenticationUI as String: true,
                kSecAttrAccessControl as String: accessControlRef!
            ]
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let status = SecItemAdd(query, nil)
                dispatch_async(dispatch_get_main_queue(), {
                    callback(result: self.statusToEnum(status))
                })
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                callback(result: .Unimplemented)
            })
        }
    }
    
    func deleteSecretAsync(callback: (result: KeychainOperationResult)->(Void)) -> Void {
        let query: NSDictionary = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kGoNativeKeychainService,
        ]
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let status = SecItemDelete(query)
            dispatch_async(dispatch_get_main_queue(), {
                callback(result: self.statusToEnum(status))
            })
        }
    }
    
    func statusToEnum(status: OSStatus) -> KeychainOperationResult {
        switch status {
        case errSecSuccess:
            return .Success
        case errSecDuplicateItem:
            return .DuplicateItem
        case errSecItemNotFound:
            return .ItemNotFound
        case errSecAuthFailed:
            return .AuthenticationFailed
        case errSecUserCanceled:
            return .UserCanceled
        case errSecUnimplemented:
            return .Unimplemented
        default:
            return .GenericError
        }
    }
}