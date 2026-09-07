#import <UIKit/UIKit.h>

// MediaControls.framework (private), as it looks on iOS 14 and 15.
//
// iOS 16 reshaped all of it: `context` was dropped from the leaf views in
// favour of `layout`, `MRUNowPlayingControlsView` was folded into
// `MRUNowPlayingView`, and the scrubber's hand made `knobView` became an
// `MRUSlider`. None of that matters for the lock screen any more, because iOS
// 16 draws the lock screen player out of process and leaves SpringBoard with
// nothing but a hosted layer, so Printemps draws its own there. These
// declarations are only used by the iOS 14/15 hooks.

@interface MRUNowPlayingLabelView : UIView
@property (nonatomic, assign) NSInteger context; // iOS 14/15 only
@property (nonatomic, assign) NSInteger layout;
@end

@interface MRUNowPlayingTransportControlsView : UIView
@property (nonatomic, assign) NSInteger layout;
@property (nonatomic, retain) UIView *leftButton;
@property (nonatomic, retain) UIView *rightButton;
@property (nonatomic, retain) UIView *centerButton;
@end

// iOS 14/15 only, merged into MRUNowPlayingView in iOS 16.
@interface MRUNowPlayingControlsView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic, retain) UIView *volumeControlsView;
@end

@interface MRUArtworkView : UIView
@property (nonatomic, assign) NSInteger style;
@end

@interface MRUNowPlayingHeaderView : UIView
@property (nonatomic, assign) NSInteger context; // iOS 14/15 only
@property (nonatomic, assign) NSInteger layout;
@property (nonatomic, assign) BOOL showRoutingButton;
@property (nonatomic, assign) BOOL showWaveform;    // iOS 16
@property (nonatomic, readonly) MRUNowPlayingLabelView *labelView; // iOS 16
@end

@interface MRUNowPlayingTimeControlsView : UIView
@property (nonatomic, assign) NSInteger context; // iOS 14/15 only
@property (nonatomic, assign) NSInteger layout;  // iOS 16
@property (nonatomic, retain) UIView *elapsedTimeLabel;
@property (nonatomic, retain) UIView *remainingTimeLabel;
@property (nonatomic, retain) UIView *slider;    // iOS 16
@end

// The lock screen's live activity item. Its content is drawn out of process.
@interface CSActivityItemContentView : UIView
@end

// The list the item is laid out in. It caches what it measured, so resizing an
// item means telling it to measure again.
@interface NCNotificationListView : UIScrollView
- (void)invalidateData;
@end
