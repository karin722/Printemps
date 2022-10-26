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

@interface MRUNowPlayingTransportControlsView : UIView
@property (nonatomic, assign) NSInteger layout;
@property (nonatomic, assign) NSInteger tp_userInterfaceLayoutDirection;
@property (nonatomic,retain) UIView * leftButton;
@end

@interface MRUNowPlayingControlsView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic, retain) UIView *volumeControlsView;
@end

@interface MRUArtworkView : UIView
@property (nonatomic, assign) NSInteger style;
@property (nonatomic, assign) NSInteger tp_userInterfaceLayoutDirection;
@property (nonatomic,retain) UIView * iconView;
@property (nonatomic,retain) UIView * iconShadowView;
@end

@interface MRUNowPlayingHeaderView : UIView
@property (nonatomic, assign) NSInteger context;
@end

@interface MRUNowPlayingTimeControlsView : UIView
@property (nonatomic, assign) NSInteger context;
@property (nonatomic,retain) UIView * elapsedTimeLabel;
@property (nonatomic,retain) UIView * remainingTimeLabel;
@property (nonatomic,retain) UIView * knobView;
@end
