#import <UIKit/UIKit.h>

// The lock screen player Printemps draws itself.
//
// iOS 16 renders the stock one out of process and hands SpringBoard nothing but
// a hosted layer, so there is no view hierarchy left to restyle. This one is
// built from MediaRemote instead, which keeps the layout under our control.
@interface PrintempsPlayerView : UIView

// Height the player wants. Its width is whatever it is given.
@property (class, nonatomic, readonly) CGFloat preferredHeight;

@property (nonatomic, assign) BOOL hidesPreviousButton;

// Holding the artwork opens the share sheet.
@property (nonatomic, assign) BOOL sharingEnabled;

// NO while nothing is playing, so the host can leave the lock screen alone.
@property (nonatomic, readonly) BOOL hasContent;

@end
