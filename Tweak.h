#import <UIKit/UIKit.h>

@interface UIView ()
- (id)_viewControllerForAncestor;
@end

@interface MRUCoverSheetViewController : UIViewController
@end

@interface MRUNowPlayingLabelView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic, assign) NSInteger tp_userInterfaceLayoutDirection;
@end

@interface MRUNowPlayingVolumeControlsView : UIView
@end

@interface MRUTransportButton : UIView
@end

@interface MRUNowPlayingTransportControlsView : UIView
@property (nonatomic, assign) NSInteger layout;
@property (nonatomic, assign) NSInteger tp_userInterfaceLayoutDirection;
@property (nonatomic,retain) MRUTransportButton * leftButton;
@end

@interface MRUNowPlayingControlsView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic, retain) MRUNowPlayingVolumeControlsView *volumeControlsView;
@end

@interface MRUArtworkView : UIView
@property (nonatomic, assign) NSInteger style;
@property (nonatomic, assign) NSInteger tp_userInterfaceLayoutDirection;
@end

@interface MRUNowPlayingHeaderView : UIView
@property (nonatomic, assign) NSInteger context;
@end

@interface MRUNowPlayingTimeControlsView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic,retain) UILabel * elapsedTimeLabel;
@property (nonatomic,retain) UILabel * remainingTimeLabel;
@property (nonatomic,retain) UIView * knobView;
@end
