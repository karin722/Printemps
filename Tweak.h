#import <UIKit/UIKit.h>

@interface UIView (Printemps)
- (NSString *)recursiveDescription;
@end

// MediaControls.framework (private).
//
// The lock screen player changed shape in iOS 16:
//   * `context` was removed from the leaf views, they only keep `layout`
//   * `MRUNowPlayingControlsView` disappeared, its subviews moved to `MRUNowPlayingView`
//   * the scrubber's hand made `knobView` was replaced by an `MRUSlider`
// Both shapes are declared here, so only call the accessors that exist on the
// firmware you are running on (see the %group split in Tweak.xm).

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
@property (nonatomic, retain) UIView *iconView;
@property (nonatomic, retain) UIView *iconShadowView;
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
@property (nonatomic, retain) UIView *knobView;  // iOS 14/15 only
@property (nonatomic, retain) UIView *slider;    // iOS 16
@end

// iOS 16. Hosts every part of the player and decides what is visible.
@interface MRUNowPlayingView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic, assign) NSInteger layout;
@property (nonatomic, assign) BOOL showArtworkView;
@property (nonatomic, assign) BOOL showTimeControlsView;
@property (nonatomic, assign) BOOL showTransportControlsView;
@property (nonatomic, assign) BOOL showVolumeControlsView;
@property (nonatomic, assign) BOOL useArtworkOverrideSize;
@property (nonatomic, assign) CGSize artworkOverrideSize;
@property (nonatomic, assign) UIEdgeInsets contentEdgeInsets;
@property (nonatomic, readonly) MRUArtworkView *artworkView;
@property (nonatomic, readonly) MRUNowPlayingHeaderView *headerView;
@property (nonatomic, readonly) MRUNowPlayingTimeControlsView *timeControlsView;
@property (nonatomic, readonly) MRUNowPlayingTransportControlsView *transportControlsView;
@property (nonatomic, readonly) UIView *volumeControlsView;
@end
