// Copyright 2013 Google Inc.
// Author: sdykeman@google.com (Sean Dykeman)

@protocol GCKDeviceFilterListener;
@class GCKDevice;
@class GCKDeviceScanner;
@class GCKFilterCriteria;

/**
 * Filters device scanner results to return only those devices which support or are running
 * applications which meet some given critera.
 */
@interface GCKDeviceFilter : NSObject

@property(nonatomic, readonly, copy) NSArray *devices;

- (id)initWithDeviceScanner:(GCKDeviceScanner *)scanner criteria:(GCKFilterCriteria *)criteria;

- (void)addDeviceFilterListener:(id<GCKDeviceFilterListener>)listener;
- (void)removeDeviceFilterListener:(id<GCKDeviceFilterListener>)listener;

@end

@protocol GCKDeviceFilterListener <NSObject>

/**
 * Called when a supported device has come online.
 *
 * @param device The device.
 */
- (void)deviceDidComeOnline:(GCKDevice *)device
            forDeviceFilter:(GCKDeviceFilter *)deviceFilter;

/**
 * Called when a supported device has gone offline.
 *
 * @param device The device.
 */
- (void)deviceDidGoOffline:(GCKDevice *)device
           forDeviceFilter:(GCKDeviceFilter *)deviceFilter;

@end
