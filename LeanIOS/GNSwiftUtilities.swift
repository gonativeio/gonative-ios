//
//  GNSwiftUtilities.swift
//  GonativeIO
//
//  Created by Hunaid Hassan on 26.05.23.
//  Copyright © 2023 GoNative.io LLC. All rights reserved.
//

import UIKit

@objc
public class GNSwiftUtilities: NSObject {
    @objc class func deviceToken(data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
