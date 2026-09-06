#import "Tweak.h"
#import "PrintempsPlayerView.h"
#import <objc/runtime.h>

#pragma mark - Preferences

static NSString * const kPreferencesDomain = @"com.tako3s.PrintempsPrefs";
static NSString * const kPreferencesChangedNotification = @"com.tako3s.printemps/preferencesChanged";

// Cached so that the layout hooks, which run on every pass, never touch cfprefs.
static BOOL sHideKnob;      // stored under the historical "showKnob" key
static BOOL sHidePrevious;
static BOOL sHideAppIcon;
static BOOL sDebugLogging;

static void PrintempsLoadPreferences(void)
{
	NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesDomain];
	sHideKnob = [preferences boolForKey:@"showKnob"];
	sHidePrevious = [preferences boolForKey:@"hidePrevious"];
	sHideAppIcon = [preferences boolForKey:@"hideAppIcon"];
	sDebugLogging = [preferences boolForKey:@"debugLogging"];
}

static void PrintempsPreferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	PrintempsLoadPreferences();
}

#define PrintempsLog(fmt, ...) \
	do { if (sDebugLogging) PrintempsLogMessage([NSString stringWithFormat:fmt, ##__VA_ARGS__]); } while (0)

// The unified logging tools are hit and miss on a jailbroken device, so debug
// lines are also appended to a file that can just be read with cat.
static NSString * const kLogFilePath = @"/var/mobile/Library/Logs/Printemps.log";
static const unsigned long long kLogFileSizeLimit = 256 * 1024;

static void PrintempsAppendToLogFile(NSString *message)
{
	static NSDateFormatter *formatter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [NSDateFormatter new];
		formatter.dateFormat = @"HH:mm:ss.SSS";
	});

	NSFileManager *fileManager = NSFileManager.defaultManager;
	if ([fileManager attributesOfItemAtPath:kLogFilePath error:NULL].fileSize > kLogFileSizeLimit) {
		[fileManager removeItemAtPath:kLogFilePath error:NULL];
	}

	NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:NSDate.date], message];
	NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogFilePath];
	if (handle == nil) {
		[data writeToFile:kLogFilePath atomically:YES];
		return;
	}

	[handle seekToEndOfFile];
	[handle writeData:data];
	[handle closeFile];
}

static void PrintempsLogMessage(NSString *message)
{
	NSLog(@"[Printemps] %@", message);
	if (sDebugLogging) PrintempsAppendToLogFile(message);
}

#pragma mark - Metrics

// The player is laid out as
//
//   +--------------------------------------------------+
//   | [artwork] title / artist            [<] [>] [>>] |
//   |           ------------------------------------   |
//   +--------------------------------------------------+
//
static const CGFloat kPlayerHeight = 118.0;
static const CGFloat kPlayerHeightWithoutKnob = 117.0;

static const CGFloat kArtworkSize = 70.0;
static const CGFloat kArtworkTrailingInsetRTL = 102.0;

static const CGFloat kControlsOriginY = 21.0;
static const CGFloat kControlsHeight = 25.0;
static const CGFloat kControlsWidth = 100.0;
static const CGFloat kControlsTrailingInset = 125.5;
static const CGFloat kControlsOriginXRTL = -6.5;
static const CGFloat kControlsOriginXRTLWithoutPrevious = -42.0;

static const CGFloat kLabelOriginY = kControlsOriginY - 13.0;
static const CGFloat kLabelOriginX = 80.0;

// The label has to clear the artwork on one side and the transport controls on
// the other, and the controls did not sit in the same place on every firmware.
static const CGFloat kLabelWidthInset14 = 200.0;
static const CGFloat kLabelWidthInset14WithoutPrevious = 170.0;
static const CGFloat kLabelOriginXRTL14 = 90.0;
static const CGFloat kLabelOriginXRTL14WithoutPrevious = 58.0;

static const CGFloat kLabelWidthInset15 = 210.0;
static const CGFloat kLabelWidthInset15WithoutPrevious = 180.0;
static const CGFloat kLabelOriginXRTL15 = 95.0;
static const CGFloat kLabelOriginXRTL15WithoutPrevious = 63.0;

static const CGFloat kTimeControlsOriginY = 60.0;

#pragma mark - Shared state

// Width of the media controls area, published by the CoverSheet hooks and read
// back by the iOS 14/15 layout hooks, which only ever see their own subview.
static CGFloat sPlayerWidth;

static CGFloat PrintempsPlayerHeight(void)
{
	return sHideKnob ? kPlayerHeightWithoutKnob : kPlayerHeight;
}

static BOOL PrintempsIsRightToLeft(UIView *view)
{
	return view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

#pragma mark - iOS 14 / 15

%group Legacy

//Media Controls
%hook MRUNowPlayingTransportControlsView

	- (void)setFrame: (CGRect)frame
	{
		// 4 -> LS
		// 0 -> CC
		if(self.layout == 4)
		{
			self.leftButton.hidden = sHidePrevious;

			//Remove all the constraints our object holds
			self.translatesAutoresizingMaskIntoConstraints = NO;

			if (PrintempsIsRightToLeft(self)) {
				frame.origin.x = sHidePrevious ? kControlsOriginXRTLWithoutPrevious : kControlsOriginXRTL;
			} else {
				frame.origin.x = sPlayerWidth - kControlsTrailingInset;
			}
			frame.origin.y = kControlsOriginY;
			frame.size.width = kControlsWidth;
			frame.size.height = kControlsHeight;
		}
		%orig;
	}

%end

//Artwork
%hook MRUArtworkView

	- (void)setFrame: (CGRect)frame
	{
		// 0 -> CC
		// 1 -> LS
		if(self.style == 1){
			frame.size.width = kArtworkSize;
			frame.size.height = kArtworkSize;
			if (PrintempsIsRightToLeft(self)) {
				frame.origin.x = sPlayerWidth - kArtworkTrailingInsetRTL;
			}
			// hide app icon
			self.iconView.hidden = sHideAppIcon;
			self.iconShadowView.hidden = sHideAppIcon;
		}
		%orig;
	}

%end

//Volume Slider
%hook MRUNowPlayingControlsView

	- (void)setNeedsLayout
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2)
			self.volumeControlsView.hidden = true;
		%orig;
	}
%end

//Airplay Icon
%hook MRUNowPlayingHeaderView

	-(void)setShowRoutingButton:(BOOL)arg1{
		if(self.context == 2){
			return %orig(NO);
		}
		return %orig;
	}
%end

//Time Bar
%hook MRUNowPlayingTimeControlsView

	- (void)setFrame: (CGRect)frame
	{
		if(self.context == 2){
			frame.origin.y = kTimeControlsOriginY;
		}
		%orig;
	}

	-(void)setNeedsLayout
	{
		if(self.context == 2){
			// Hidden rather than removed from the hierarchy, so that turning the
			// tweak's options back off restores the stock player.
			self.elapsedTimeLabel.hidden = true;
			self.remainingTimeLabel.hidden = true;
			self.knobView.hidden = sHideKnob;
		}
		%orig;
	}
%end

%end // Legacy

//Player Height
// ios 14
%group LegacyHeight14
%hook CSMediaControlsViewController

	- (CGRect)_suggestedFrameForMediaControls
	{
		CGRect frame = %orig;
		frame.size.height = PrintempsPlayerHeight();
		sPlayerWidth = frame.size.width;

		return frame;
	}
%end
%end

// ios 15
%group LegacyHeight15
%hook CSMediaControlsViewController

	- (CGRect)_suggestedFrameForMediaControls
	{
		CGRect frame = %orig;
		frame.size.height = PrintempsPlayerHeight();
		sPlayerWidth = frame.size.width;

		return frame;
	}

	- (double)_preferredMediaRemoteHeight
	{
		return PrintempsPlayerHeight();
	}
%end
%end

//Header Labels
// ios 14.0 - 14.4
%group LegacyLabel14
%hook MRUNowPlayingLabelView

	- (void)setFrame: (CGRect)frame
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2) {
			frame.origin.y = kLabelOriginY;
			if (sHidePrevious) {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL14WithoutPrevious : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset14WithoutPrevious;
			} else {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL14 : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset14;
			}
		}
		%orig;
	}

%end
%end

// ios 14.5 - 15
%group LegacyLabel15
%hook MRUNowPlayingLabelView

	- (void)setFrame: (CGRect)frame
	{
		if(self.context == 2) {
			frame.origin.y = kLabelOriginY;
			if (sHidePrevious) {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL15WithoutPrevious : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset15WithoutPrevious;
			} else {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL15 : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset15;
			}
		}
		%orig;
	}

%end
%end

#pragma mark - iOS 16

// iOS 16 renders the collapsed lock screen player out of process. The cover
// sheet holds a live activity item whose content arrives as a hosted scene
// layer, so there are no MediaControls views in SpringBoard left to restyle.
//
// Printemps takes that item over instead: its own player goes inside it and the
// hosted content is hidden. Sitting in the item means the lock screen keeps
// deciding where the player goes and how big it is.

static const void *kPrintempsPlayerKey = &kPrintempsPlayerKey;

// The lock screen groups its live activities, and the now playing one is the
// only member of this group.
static NSString * const kNowPlayingActivityIdentifier = @"com.apple.MediaRemoteUI";

// The same inset all the way round, so the card hugs the player evenly.
static const CGFloat kPlayerInset = 16.0;

// Reads an ivar without KVC, which would throw on a firmware that renamed it.
static id PrintempsIvarValue(id object, const char *name)
{
	if (object == nil) return nil;

	Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
	return ivar == NULL ? nil : object_getIvar(object, ivar);
}

// Which activity the item belongs to is only known to the notification list
// cell holding it, as the configuration it was built from.
static BOOL PrintempsIsNowPlayingActivity(UIView *view)
{
	for (UIView *ancestor = view; ancestor != nil; ancestor = ancestor.superview) {
		if (![ancestor isKindOfClass:%c(NCNotificationListCell)]) continue;

		id controller = PrintempsIvarValue(ancestor, "_contentViewController");
		id configuration = PrintempsIvarValue(controller, "_configuration");
		id identifier = PrintempsIvarValue(configuration, "_groupingIdentifier");

		PrintempsLog(@"activity group %@", identifier);
		return [identifier isKindOfClass:NSString.class]
			&& [(NSString *)identifier isEqualToString:kNowPlayingActivityIdentifier];
	}

	return NO;
}

%group Modern

%hook CSActivityItemContentView

	- (void)layoutSubviews
	{
		%orig;

		PrintempsPlayerView *player = objc_getAssociatedObject(self, kPrintempsPlayerKey);
		if (player == nil) {
			player = [[PrintempsPlayerView alloc] initWithFrame:CGRectZero];
			objc_setAssociatedObject(self, kPrintempsPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self addSubview:player];
		}

		player.hidesPreviousButton = sHidePrevious;

		BOOL takeOver = player.hasContent && PrintempsIsNowPlayingActivity(self);
		for (UIView *subview in self.subviews) {
			if (subview != player) subview.hidden = takeOver;
		}

		player.hidden = !takeOver;
		if (!takeOver) return;

		CGRect bounds = self.bounds;
		CGFloat height = PrintempsPlayerView.preferredHeight;
		player.frame = CGRectMake(kPlayerInset, (CGRectGetHeight(bounds) - height) / 2.0,
			CGRectGetWidth(bounds) - 2.0 * kPlayerInset, height);
		[self bringSubviewToFront:player];

		// The card is as tall as the stock widget asked for, which leaves the
		// player floating in it. The item takes its size from the controller
		// behind `_sizeProvider`, and setting it there is what tells the
		// notification list to lay the card out again.
		id provider = PrintempsIvarValue(self, "_sizeProvider");
		if ([provider isKindOfClass:UIViewController.class]) {
			UIViewController *controller = (UIViewController *)provider;
			CGSize wanted = CGSizeMake(CGRectGetWidth(bounds), height + 2.0 * kPlayerInset);
			if (!CGSizeEqualToSize(controller.preferredContentSize, wanted)) {
				controller.preferredContentSize = wanted;
			}
		}

		PrintempsLog(@"took over %@ with %@", NSStringFromCGRect(bounds), NSStringFromCGRect(player.frame));
	}

%end

%end // Modern

#pragma mark - Entry point

%ctor {
	PrintempsLoadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
		PrintempsPreferencesChanged, (__bridge CFStringRef)kPreferencesChangedNotification,
		NULL, CFNotificationSuspensionBehaviorCoalesce);

	if (@available(iOS 16.0, *)) {
		PrintempsLogMessage([NSString stringWithFormat:@"loaded on iOS %@, using the iOS 16 hooks, built " __DATE__ " " __TIME__, UIDevice.currentDevice.systemVersion]);
		%init(Modern);
	} else {
		PrintempsLogMessage([NSString stringWithFormat:@"loaded on iOS %@, using the iOS 14/15 hooks, built " __DATE__ " " __TIME__, UIDevice.currentDevice.systemVersion]);
		%init(Legacy);

		if (@available(iOS 15.0, *)) {
			%init(LegacyHeight15);
		} else {
			%init(LegacyHeight14);
		}

		if (@available(iOS 14.5, *)) {
			%init(LegacyLabel15);
		} else {
			%init(LegacyLabel14);
		}
	}
}

