//
//  LEANIcons.swift
//  GonativeIO
//
//  Created by Anuj Sevak on 2021-04-21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

import Foundation
import GonativeIcons

@objc class LEANIcons: NSObject {    
    @objc public static let sharedIcons = LEANIcons()
    
    @objc public class func imageForIconIdentifier(_ name: String, size: CGFloat, color: UIColor) -> UIImage? {
        return UIImage.init(iconName: name, size: size, color: color)
    }
}
