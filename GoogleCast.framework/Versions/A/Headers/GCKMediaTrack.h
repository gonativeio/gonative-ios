// Copyright 2014 Google Inc.

/**
 * Media track types.
 *
 * @ingroup MediaControl
 */
typedef NS_ENUM(NSInteger, GCKMediaTrackType) {
  /** Unknown track type. */
  GCKMediaTrackTypeUnknown = 0,
  /** Text. */
  GCKMediaTrackTypeText = 1,
  /** Audio. */
  GCKMediaTrackTypeAudio = 2,
  /** Video. */
  GCKMediaTrackTypeVideo = 3,
};

/**
 * Media text track subtypes.
 *
 * @ingroup MediaControl
 */
typedef NS_ENUM(NSInteger, GCKMediaTextTrackSubtype) {
  /** Unknown text track subtype. */
  GCKMediaTextTrackSubtypeUnknown = 0,
  /** Subtitles. */
  GCKMediaTextTrackSubtypeSubtitles = 1,
  /** Captions. */
  GCKMediaTextTrackSubtypeCaptions = 3,
  /** Descriptions. */
  GCKMediaTextTrackSubtypeDescriptions = 4,
  /** Chapters. */
  GCKMediaTextTrackSubtypeChapters = 5,
  /** Metadata. */
  GCKMediaTextTrackSubtypeMetadata = 6,
};

/**
 * A class representing a media track. Instances of this object are immutable.
 *
 * @ingroup MediaControl
 */
@interface GCKMediaTrack : NSObject<NSCopying>

/**
 * Designated initializer. Constructs a new GCKMediaTrack with the given property values.
 */
- (id)initWithIdentifier:(NSInteger)identifier
       contentIdentifier:(NSString *)contentIdentifier
             contentType:(NSString *)contentType
                    type:(GCKMediaTrackType)type
             textSubtype:(GCKMediaTextTrackSubtype)textSubtype
                    name:(NSString *)name
            languageCode:(NSString *)languageCode
              customData:(id)customData;

/** @cond INTERNAL */

- (id)initWithJSONObject:(id)JSONObject;

/**
 * Create a JSON object which can serialized with NSJSONSerialization to pass to the receiver.
 */
- (id)JSONObject;

/** @endcond */

/** The track's unique numeric identifier. */
@property(nonatomic, readonly) NSInteger identifier;

/** The track's content identifier, which may be <code>nil</code>. */
@property(nonatomic, copy, readonly) NSString *contentIdentifier;

/** The track's content (MIME) type. */
@property(nonatomic, copy, readonly) NSString *contentType;

/** The track's type. */
@property(nonatomic, readonly) GCKMediaTrackType type;

/** The text track's subtype; applies only to text tracks. */
@property(nonatomic, readonly) GCKMediaTextTrackSubtype textSubtype;

/** The track's name, which may be <code>nil</code>. */
@property(nonatomic, copy, readonly) NSString *name;

/** The track's RFC 1766 language code, which may be <code>nil</code>. */
@property(nonatomic, copy, readonly) NSString *languageCode;

/** The custom data, if any. */
@property(nonatomic, strong, readonly) id customData;

@end
