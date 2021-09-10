//
//  WindowsController.swift
//  GonativeIO
//
//  Created by Hunaid Hassan on 14.06.21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

import Foundation
import GoNativeCore

@objc class WindowsController: NSObject {
    @objc class public func windowCountChanged() {
        let appConfig = GoNativeAppConfig.shared()!
        guard LEANWebViewController.currentWindows > appConfig.maxWindows else {
            return
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController as? LEANRootViewController,
           let navigationController = rootViewController.contentViewController as? UINavigationController {
            var viewControllers = navigationController.viewControllers
            let removeTillIndex = LEANWebViewController.currentWindows - appConfig.maxWindows
            viewControllers.removeSubrange(1...removeTillIndex)
            navigationController.viewControllers = viewControllers
        }
    }
}
