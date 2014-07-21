// Copyright 2013 Google Inc.

/** @cond INTERNAL */

@class GCKApplicationMetadata;

@protocol GCKReceiverControlChannelDelegate;

typedef NS_ENUM(NSInteger, GCKAppAvailability) {
  /**
   * The associated app ID cannot be launched on this device.
   */
  GCKAppAvailabilityUnavailable,

  /**
   * The associated app ID can be launched on this device.
   */
  GCKAppAvailabilityAvailable,
};

#import "GCKCastChannel.h"

/**
 * A GCKReceiverChannel controls the receiver on the device, including launching
 * and closing applications, getting the device status, and setting the volume.
 * This is created by GCKDeviceManager and so should not be created directly.
 *
 * @ingroup DeviceControl
 */
@interface GCKReceiverControlChannel : GCKCastChannel

@property(nonatomic, weak) id<GCKReceiverControlChannelDelegate> delegate;

/**
 * Designated initializer.
 * @param receiverDestinationID The destination ID for the receiver.
 */
- (id)initWithReceiverDestinationID:(NSString *)receiverDestinationID;

/**
 * True if currently launching an application.
 */
- (BOOL)isLaunchingApplication;

/**
 * Launches an application, with given command paraments, optionally relaunching it if it is
 * already running.
 *
 * @param applicationID The application ID.
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)launchApplication:(NSString *)applicationID;

/**
 * Stops any running application(s).
 *
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)stopApplication;

/**
 * Stops the application with the given session ID. Session ID must be non-negative.
 *
 * @param sessionId The session ID.
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)stopApplicationWithSessionID:(NSString *)sessionID;

/**
 * Requests the device's current status.
 *
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)requestDeviceStatus;

/**
 * Requests the availability for a list of app IDs.
 *
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)requestAvailabilityForAppIDs:(NSArray *)appIDs;

/**
 * Sets the system volume.
 *
 * @param volume The new volume, in the range [0.0, 1.0]. Out of range values will be silently
 * clipped.
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)setVolume:(float)volume;

/**
 * Turns muting on or off.
 *
 * @param muted Whether audio should be muted or unmuted.
 * @return The request ID, or kGCKInvalidRequestID if the message could not be sent.
 */
- (NSInteger)setMuted:(BOOL)muted;

@end

@protocol GCKReceiverControlChannelDelegate <NSObject>

/**
 * Called when an application has been launched.
 *
 * @param applicationMetadata Metadata about the application.
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
      didLaunchCastApplication:(GCKApplicationMetadata *)applicationMetadata;

/**
 * Called when an application launch fails.
 *
 * @param error The error that identifies the reason for the failure.
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
    didFailToLaunchCastApplicationWithError:(NSError *)error;

/**
 * Called when a request fails.
 *
 * @param requestID The request ID that failed.
 * @param error The error that identifies the reason for the failure.
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
          requestDidFailWithID:(NSInteger)requestID
                         error:(NSError *)error;

/**
 * Called whenever updated status information is received.
 *
 * @param applicationMetadata The application metadata.
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
    didReceiveStatusForApplication:(GCKApplicationMetadata *)applicationMetadata;

/**
 * Called whenever the volume changes.
 *
 * @param volumeLevel The current device volume level.
 * @param isMuted The current device mute state.
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
        volumeDidChangeToLevel:(float)volumeLevel
                       isMuted:(BOOL)isMuted;

/**
 * Called whenever app availability information is received.
 *
 * @param appAvailability A dictionary from app ID (as an NSString) to app availability (as an
 * NSNumber containing a GCKAppAvailability value).
 */
- (void)receiverControlChannel:(GCKReceiverControlChannel *)receiverControlChannel
     didReceiveAppAvailability:(NSDictionary *)appAvailability;

@end

/** @endcond */
