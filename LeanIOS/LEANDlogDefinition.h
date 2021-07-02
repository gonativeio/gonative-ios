//
//  LEANDlogDefinition.h
//  GoNativeIOS
//
//  Created by Anuj Sevak on 2021-06-23.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

#define DLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
