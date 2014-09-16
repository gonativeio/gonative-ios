// Copyright 2013 Google Inc.

#if TARGET_OS_IPHONE
#include <UIKit/UIColor.h>
#else
#include <AppKit/NSColor.h>
#endif

/**
 * A class that represents an RGBA color.
 *
 * @ingroup MediaControl
 */
@interface GCKColor : NSObject <NSCopying, NSCoding>

@property(atomic, readonly) CGFloat red;
@property(atomic, readonly) CGFloat green;
@property(atomic, readonly) CGFloat blue;
@property(atomic, readonly) CGFloat alpha;

/**
 * Designated initializer. Constructs a GCKColor object with the given red, green, blue, and alpha
 * values.
 */
- (id)initWithRed:(CGFloat)red
            green:(CGFloat)green
             blue:(CGFloat)blue
            alpha:(CGFloat)alpha;


/**
 * Constructs a GCKColor object with the given red, green, blue values and an alpha value of 1.0
 * (full opacity).
 */
- (id)initWithRed:(CGFloat)red
            green:(CGFloat)green
             blue:(CGFloat)blue;

#if TARGET_OS_IPHONE

/**
 * Constructs a GCKColor object from a UIColor.
 */
- (id)initWithUIColor:(UIColor *)color;

#else

/**
 * Constructs a GCKColor object from an NSColor.
 */
- (id)initWithNSColor:(NSColor *)color;

#endif // TARGET_OS_IPHONE

/**
 * Constructs a GCKColor object from a CGColor.
 */
- (id)initWithCGColor:(CGColorRef)color;

/**
 * Constructs a GCKColor object from a CSS string representation in the form "#RRGGBBAA".
 */
- (id)initWithCSSString:(NSString *)CSSString;

/**
 * Returns a a CSS string representation of the color, in the form "#RRGGBBAA".
 */
- (NSString *)CSSString;

/** The color black. */
+ (GCKColor *)black;
/** The color red. */
+ (GCKColor *)red;
/** The color green. */
+ (GCKColor *)green;
/** The color blue. */
+ (GCKColor *)blue;
/** The color cyan. */
+ (GCKColor *)cyan;
/** The color magenta. */
+ (GCKColor *)magenta;
/** The color yellow. */
+ (GCKColor *)yellow;
/** The color white. */
+ (GCKColor *)white;

@end
