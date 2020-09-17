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

open class GoNativeKeychain: NSObject {
    var authContext = LAContext()
    
    func getStatusAsync(_ callback: @escaping ([String:AnyObject]) -> (Void)) -> Void {
        getSecretExistsAsync { (exists) -> (Void) in
            let result: [String: AnyObject] = [
                "hasTouchId": self.hasTouchIdD() as AnyObject,
                "biometryType": self.getBiometryType() as AnyObject,
                "hasSecret": exists as AnyObject
            ]
            
            callback(result)
        }
    }
    
    fileprivate func hasTouchIdD() -> Bool {
        if #available(iOS 9.0, *) {
            return authContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
        } else {
            return false
        }
    }
    
    fileprivate func getBiometryType() -> String {
        if #available(iOS 11.0, *) {
            if !hasTouchIdD() {
                return "none";
            }
            
            let type = authContext.biometryType;
            if type.rawValue == 1 {
                return "touchId";
            } else if type.rawValue == 2 {
                return "faceId";
            } else {
                return "none";
            }
        } else {
            return "none";
        }
    }
    
    func getSecretAsync(_ prompt: String?, callback: @escaping (_ result: KeychainOperationResult, _ secret: String?)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let operationPrompt = prompt == nil ? "Authenticate to retrieve saved credentials" : prompt
            
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecReturnData as String: true,
                kSecUseOperationPrompt as String: operationPrompt!
            ]
            
            var dataTypeRef: AnyObject?
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let status: OSStatus = withUnsafeMutablePointer(to: &dataTypeRef) {
                    SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
                }
                
                if status == errSecSuccess {
                    let data = dataTypeRef as! Data
                    let secret = String(data: data, encoding: String.Encoding.utf8)
                    
                    DispatchQueue.main.async(execute: {
                        callback(.Success, secret)
                    })
                } else {
                    DispatchQueue.main.async(execute: {
                        callback(self.statusToEnum(status), nil)
                    })
                }
            }
        } else {
            DispatchQueue.main.async(execute: {
                callback(.Unimplemented, nil)
            })
        }
    }
    
    func getSecretExistsAsync(_ callback: @escaping (_ exists: Bool)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
            ]
            
            var dataTypeRef: AnyObject?
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let status: OSStatus = withUnsafeMutablePointer(to: &dataTypeRef) {
                    SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
                }
                
                if status == errSecInteractionNotAllowed || status == errSecSuccess {
                    callback(true)
                } else {
                    callback(false)
                }
            }
        } else {
            DispatchQueue.main.async(execute: {
                callback(false)
            })
        }
    }
    
    func saveSecretAsync(_ secret: String, callback:@escaping (_ result: KeychainOperationResult)->(Void)) -> Void {
        deleteSecretAsync { (deleteResult) -> (Void) in
            // ignore delete result
            self._saveSecretAsync(secret, callback: callback)
        }
    }
    
    fileprivate func _saveSecretAsync(_ secret: String, callback:@escaping (_ result:KeychainOperationResult)->(Void)) -> Void {
        if #available(iOS 9.0, *) {
            let secretData = secret.data(using: String.Encoding.utf8)
            
            let accessControlError:UnsafeMutablePointer<Unmanaged<CFError>?>? = nil
            let accessControlRef = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, SecAccessControlCreateFlags.biometryAny, accessControlError)
            
            if accessControlRef == nil || accessControlError != nil {
                DispatchQueue.main.async(execute: {
                    callback(.GenericError)
                })
                return
            }
            
            let query: NSDictionary = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: kGoNativeKeychainService,
                kSecValueData as String: secretData!,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
                kSecAttrAccessControl as String: accessControlRef!
            ]
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let status = SecItemAdd(query, nil)
                DispatchQueue.main.async(execute: {
                    callback(self.statusToEnum(status))
                })
            }
        } else {
            DispatchQueue.main.async(execute: {
                callback(.Unimplemented)
            })
        }
    }
    
    func deleteSecretAsync(_ callback: @escaping (_ result: KeychainOperationResult)->(Void)) -> Void {
        let query: NSDictionary = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kGoNativeKeychainService,
        ]
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let status = SecItemDelete(query)
            DispatchQueue.main.async(execute: {
                callback(self.statusToEnum(status))
            })
        }
    }
    
    @objc
    func deleteSecret() {
        let query: NSDictionary = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kGoNativeKeychainService,
            ]
        SecItemDelete(query);
    }
    
    func statusToEnum(_ status: OSStatus) -> KeychainOperationResult {
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
